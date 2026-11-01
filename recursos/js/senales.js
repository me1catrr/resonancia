// =============================================================================
// senales.js: procesamiento de señales para los laboratorios interactivos
// (Observable JS) de M3. Módulo ES; reutiliza fft, ventana, rng y normal de
// matematicas.js.
//
// Convenciones (idénticas a Resonancia.jl):
//   - DFT X[k] = Σ x[n] e^{-2πi kn/N}; `dft` admite cualquier longitud (Bluestein).
//   - Espectros unilaterales con los bins 0…⌊nfft/2⌋: se duplican todos salvo DC y,
//     si nfft es par, Nyquist.
//   - PSD = c_k |X|² / (fs Σw²), en unidades²/Hz; amplitud = c_k |X| / Σw.
//   - Welch: ventana de Hann periódica, media restada en cada segmento.
//   - NPSD: bins de la banda divididos por su suma (fracción por bin, adimensional);
//     ANPSD: media de las NPSD de varios canales sobre la misma rejilla.
//   - Momentos con divisor N.
//   - Pruebas frente a Julia: senales.test.mjs, con los datos de
//     mse/m03-senales-i/referencia/senales.json (scripts/m03/generar_referencia.jl).
// =============================================================================
import { fft, ifft, ventana, rng, normal } from "./matematicas.js";

export { rng, normal, ventana };

const suma = (x) => x.reduce((s, v) => s + v, 0);

// ---------- descriptores, convertidor y aliasing ----------
/** Descriptores temporales (M3.2): media, varianza, RMS total y fluctuante, picos, cresta, asimetría y curtosis. */
export function descriptores(x) {
  const n = x.length;
  if (n === 0) throw new Error("la señal está vacía");
  const media = suma(x) / n;
  let s2 = 0, s3 = 0, s4 = 0, q = 0, pico = 0, picoF = 0, maximo = -Infinity, minimo = Infinity;
  for (const v of x) {
    const d = v - media;
    s2 += d * d; s3 += d ** 3; s4 += d ** 4; q += v * v;
    maximo = Math.max(maximo, v); minimo = Math.min(minimo, v);
    pico = Math.max(pico, Math.abs(v)); picoF = Math.max(picoF, Math.abs(d));
  }
  const varianza = s2 / n, rms = Math.sqrt(q / n), sigma = Math.sqrt(varianza);
  const curtosis = varianza > 0 ? s4 / n / varianza ** 2 : NaN;
  const asimetria = varianza > 0 ? s3 / n / sigma ** 3 : NaN;
  return {
    media, varianza, rms, rms_fluctuante: sigma, pico, pico_fluctuante: picoF, pico_pico: maximo - minimo,
    cresta: pico / rms, cresta_fluctuante: picoF / sigma, asimetria, curtosis, curtosis_exceso: curtosis - 3,
  };
}

/**
 * Convertidor ideal (M3.3): bits, entrada ±rango y offset sumado antes. Devuelve {y, saturada, q}.
 * `bits` debe ser un entero ≥ 1 (como en Resonancia.jl, donde es `Int`).
 */
export function cuantizar(x, { bits, rango, offset = 0 }) {
  if (!(Number.isInteger(bits) && bits >= 1)) throw new Error("bits debe ser un entero de al menos 1");
  if (!(rango > 0)) throw new Error("rango debe ser positivo");
  const q = (2 * rango) / 2 ** bits, cmin = -(2 ** (bits - 1)), cmax = 2 ** (bits - 1) - 1;
  const y = [], saturada = [];
  for (const v of x) {
    // redondeo al par más próximo en los empates, como round() de Julia
    const c = redondeo((v + offset) / q);
    saturada.push(c < cmin || c > cmax);
    y.push(Math.min(cmax, Math.max(cmin, c)) * q);
  }
  return { y, saturada, q };
}

/** Redondeo al entero más próximo con empates al par (convención de Julia y de NumPy). */
export function redondeo(v) {
  const r = Math.round(v);
  return Math.abs(v % 1) === 0.5 && r % 2 !== 0 ? r - 1 : r;
}

/** Frecuencia aparente (Hz) en [0, fs/2] de una sinusoide de f Hz muestreada a fs (M3.4). */
export const frecuenciaAparente = (f, fs) => Math.abs(f - fs * redondeo(f / fs));

// ---------- cadena de adquisición: tonos y filtro previo ----------
/**
 * Ganancia en módulo de un filtro paso bajo de Butterworth de orden `orden` y frecuencia de corte `fc`:
 * |H(f)| = 1/√(1 + (f/fc)^(2·orden)). En f = fc vale 1/√2 (−3 dB) y, lejos de fc, cae
 * 20·orden dB por década. Exige fc > 0 y `orden` entero ≥ 1.
 */
export function gananciaButterworth(f, fc, orden) {
  if (!(fc > 0)) throw new Error("fc debe ser positiva");
  if (!(Number.isInteger(orden) && orden >= 1)) throw new Error("el orden debe ser un entero de al menos 1");
  return 1 / Math.sqrt(1 + (Math.abs(f) / fc) ** (2 * orden));
}

/**
 * Suma de tonos Σ A_i·g(f_i)·sin(2π f_i t + φ_i) evaluada en el vector de tiempos `t` (s).
 * `tonos` es una lista de {f, A, fase}, con f en Hz, A en las unidades de la señal y `fase` en rad
 * (0 si se omite). `filtro` (opcional) es {fc, orden}: el filtro paso bajo de Butterworth previo
 * se aplica a cada tono con `gananciaButterworth`, g(f_i) = |H(f_i)|; si es null/undefined, g = 1.
 * Simplificación: régimen estacionario, solo ganancia y sin retardo de fase ni transitorio del filtro.
 * Devuelve un Float64Array con la misma longitud que `t`.
 */
export function sumaTonos(t, tonos, filtro = null) {
  const g = tonos.map(({ f }) => (filtro ? gananciaButterworth(f, filtro.fc, filtro.orden) : 1));
  const y = new Float64Array(t.length);
  for (let i = 0; i < t.length; i++) {
    let s = 0;
    for (let j = 0; j < tonos.length; j++) {
      const { f, A, fase = 0 } = tonos[j];
      s += A * g[j] * Math.sin(2 * Math.PI * f * t[i] + fase);
    }
    y[i] = s;
  }
  return y;
}

// ---------- DFT de cualquier longitud ----------
const esPotencia2 = (n) => n > 0 && (n & (n - 1)) === 0;

/** DFT de (re, im) de cualquier longitud: radix-2 si N es potencia de 2; si no, Bluestein. */
export function dft(re, im = null) {
  const N = re.length;
  if (N === 0) throw new Error("la señal está vacía");
  im = im ?? new Array(N).fill(0);
  if (esPotencia2(N)) return fft(re, im);
  // chirp w_n = e^{-iπ n²/N} (n² mod 2N para no perder precisión)
  const wr = new Array(N), wi = new Array(N);
  for (let n = 0; n < N; n++) {
    const ang = (-Math.PI * ((n * n) % (2 * N))) / N;
    wr[n] = Math.cos(ang); wi[n] = Math.sin(ang);
  }
  let M = 1;
  while (M < 2 * N - 1) M <<= 1;
  const ar = new Array(M).fill(0), ai = new Array(M).fill(0);
  const br = new Array(M).fill(0), bi = new Array(M).fill(0);
  for (let n = 0; n < N; n++) {
    ar[n] = re[n] * wr[n] - im[n] * wi[n];
    ai[n] = re[n] * wi[n] + im[n] * wr[n];
    br[n] = wr[n]; bi[n] = -wi[n];
    if (n > 0) { br[M - n] = wr[n]; bi[M - n] = -wi[n]; }
  }
  const A = fft(ar, ai), B = fft(br, bi);
  const cr = A.re.map((v, k) => v * B.re[k] - A.im[k] * B.im[k]);
  const ci = A.re.map((v, k) => v * B.im[k] + A.im[k] * B.re[k]);
  const c = ifft(cr, ci);
  const Xr = new Array(N), Xi = new Array(N);
  for (let k = 0; k < N; k++) {
    Xr[k] = wr[k] * c.re[k] - wi[k] * c.im[k];
    Xi[k] = wr[k] * c.im[k] + wi[k] * c.re[k];
  }
  return { re: Xr, im: Xi };
}

// ---------- espectros ----------
function preparar(x, nombre, nfft, quitarMedia) {
  const N = x.length;
  if (nfft < N) throw new Error(`nfft (${nfft}) no puede ser menor que la longitud de la señal (${N})`);
  const w = ventana(nombre, N), media = quitarMedia ? suma(x) / N : 0;
  const s = new Array(nfft).fill(0);
  for (let n = 0; n < N; n++) s[n] = (x[n] - media) * w[n];
  return { w, X: dft(s) };
}
function unilateral(nfft) {
  const nf = Math.floor(nfft / 2) + 1;
  const c = new Array(nf).fill(2);
  c[0] = 1;
  if (nfft % 2 === 0) c[nf - 1] = 1;
  return { nf, c };
}

/** PSD unilateral por periodograma: {f, P} en unidades²/Hz. */
export function periodograma(x, fs, { ventana: nombre = "rectangular", nfft = x.length, quitarMedia = true } = {}) {
  const { w, X } = preparar(x, nombre, nfft, quitarMedia);
  const { nf, c } = unilateral(nfft), ew = suma(w.map((v) => v * v));
  const f = [], P = [];
  for (let k = 0; k < nf; k++) {
    f.push((k * fs) / nfft);
    P.push((c[k] * (X.re[k] ** 2 + X.im[k] ** 2)) / (fs * ew));
  }
  return { f, P };
}

/** Espectro de amplitud unilateral (amplitud de pico) y fase (rad): {f, A, fase}. */
export function espectroAmplitud(x, fs, { ventana: nombre = "rectangular", nfft = x.length, quitarMedia = false } = {}) {
  const { w, X } = preparar(x, nombre, nfft, quitarMedia);
  const { nf, c } = unilateral(nfft), sw = suma(w);
  const f = [], A = [], fase = [];
  for (let k = 0; k < nf; k++) {
    f.push((k * fs) / nfft);
    A.push((c[k] * Math.hypot(X.re[k], X.im[k])) / sw);
    fase.push(Math.atan2(X.im[k], X.re[k]));
  }
  return { f, A, fase };
}

/**
 * PSD de Welch: Hann periódica, solape relativo `solape`, media restada por segmento.
 * El paso entre segmentos es round(nseg·(1−solape)) con empates al par (como Julia y Python).
 * Diferencia con Julia: `psd_welch` exige que `nseg` sea potencia de 2 (usa una FFT radix-2);
 * aquí `nseg` puede ser cualquiera porque `dft` recurre a Bluestein, y el resultado es el mismo
 * promedio de periodogramas. Python (NumPy) tampoco lo restringe.
 * Devuelve {f, P, segmentos, inicios, Pseg}: Pseg son los periodogramas de cada segmento
 * (ya escalados), para poder dibujarlos junto a su promedio.
 */
export function welch(x, fs, { nseg = 1024, solape = 0.5 } = {}) {
  if (x.length < nseg) throw new Error(`la señal (${x.length} muestras) es más corta que un segmento (${nseg})`);
  if (!(solape >= 0 && solape < 1)) throw new Error("el solape debe estar en [0, 1)");
  const paso = Math.max(1, redondeo(nseg * (1 - solape)));
  const inicios = [];
  for (let i = 0; i + nseg <= x.length; i += paso) inicios.push(i);
  const Pseg = inicios.map((i) => periodograma(x.slice(i, i + nseg), fs, { ventana: "hann" }).P);
  const nf = Pseg[0].length;
  const P = Array.from({ length: nf }, (_, k) => suma(Pseg.map((p) => p[k])) / Pseg.length);
  const f = Array.from({ length: nf }, (_, k) => (k * fs) / nseg);
  return { f, P, segmentos: inicios.length, inicios, Pseg };
}

/** Potencia Σ P Δf en cada banda [fa, fb) y su fracción de la potencia total: {potencia, fraccion}. */
export function potenciaBandas(f, P, bandas) {
  const df = f[1] - f[0], total = suma(P) * df;
  const potencia = bandas.map(([fa, fb]) => {
    let s = 0;
    f.forEach((v, k) => { if (v >= fa && v < fb) s += P[k]; });
    return s * df;
  });
  return { potencia, fraccion: potencia.map((p) => p / total) };
}

/** PSD normalizada (NPSD) en la banda [fa, fb] (cerrada): {f, Pn} con Σ Pn = 1. */
export function psdNormalizada(f, P, banda = [f[0], f[f.length - 1]]) {
  const idx = f.map((v, k) => (v >= banda[0] && v <= banda[1] ? k : -1)).filter((k) => k >= 0);
  if (idx.length === 0) throw new Error("ningún bin dentro de la banda");
  const s = suma(idx.map((k) => P[k]));
  if (!(s > 0)) throw new Error("la PSD es nula en la banda");
  return { f: idx.map((k) => f[k]), Pn: idx.map((k) => P[k] / s) };
}

/** ANPSD: media de las NPSD de varios canales (array de PSD sobre la misma rejilla f). */
export function anpsd(f, Ps, banda = [f[0], f[f.length - 1]]) {
  const cols = Ps.map((P) => psdNormalizada(f, P, banda));
  const n = cols[0].Pn.length;
  return { f: cols[0].f, A: Array.from({ length: n }, (_, k) => suma(cols.map((c) => c.Pn[k])) / cols.length) };
}

/** Ruido de color (M3.1): PSD ∝ 1/f^α a partir del ruido blanco r; media 0 y desviación típica 1. */
export function colorear(r, alfa) {
  const N = r.length;
  if (N < 2) throw new Error("hacen falta al menos 2 muestras");
  const X = dft(r);
  X.re[0] = 0; X.im[0] = 0;
  for (let k = 1; k < N; k++) { const g = Math.min(k, N - k) ** (-alfa / 2); X.re[k] *= g; X.im[k] *= g; }
  const Y = dft(X.re, X.im.map((v) => -v));            // DFT inversa: conj(DFT(conj(X)))/N
  const y = Y.re.map((v) => v / N), m = suma(y) / N;
  const s = Math.sqrt(y.reduce((a, v) => a + (v - m) ** 2, 0) / N);
  return y.map((v) => (v - m) / s);
}

// ---------- utilidades para los laboratorios ----------
/** dB con referencia explícita: 10·log10(P/ref) para potencias (u²) o PSD (u²/Hz). */
export const dB = (P, ref = 1) => 10 * Math.log10(Math.max(P, 1e-300) / ref);

/** Formato con coma decimal y d decimales. Un valor que se redondea a cero sale «0,00», nunca «-0,00». */
export const coma = (v, d = 2) => {
  if (!Number.isFinite(v)) return "—";
  const t = v.toFixed(d);
  return (/^-0(\.0+)?$/.test(t) ? t.slice(1) : t).replace(".", ",");
};

/**
 * Histograma de x en nb clases entre lo y hi: [{x0, x1, n}].
 * Las clases son [x0, x1) y el intervalo es semiabierto [lo, hi): el valor exactamente igual a `hi`
 * (y los que quedan fuera de [lo, hi)) no se cuentan. No se cambia para no alterar las simulaciones.
 */
export function histograma(x, nb, lo, hi) {
  const h = Array.from({ length: nb }, (_, i) => ({ x0: lo + ((hi - lo) * i) / nb, x1: lo + ((hi - lo) * (i + 1)) / nb, n: 0 }));
  for (const v of x) {
    const i = Math.floor(((v - lo) / (hi - lo)) * nb);
    if (i >= 0 && i < nb) h[i].n++;
  }
  return h;
}
