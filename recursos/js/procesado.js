// =============================================================================
// procesado.js: procesamiento de señales para los laboratorios interactivos
// (Observable JS) de M4. Módulo ES; reutiliza dft, ventana, rng y normal de
// senales.js y minimosCuadrados de matematicas.js.
//
// Convenciones (idénticas a Resonancia.jl y a mse/m04-senales-ii/python/procesado.py):
//   - Espectros unilaterales con los bins 0…⌊nseg/2⌋: se duplican todos salvo DC y,
//     si nseg es par, Nyquist. PSD = c_k |X|² / (fs Σw²); media restada en cada segmento.
//   - Espectro cruzado Gxy = promedio(conj(X)·Y) con la misma escala: H1 = Gxy/Gxx y
//     H2 = Gyy/conj(Gxy), de modo que H1/H2 = γ².
//   - Números complejos como {re, im} (cada uno, un vector).
//   - Filtro FIR: {b}. Filtro IIR: {sos}, con filas [b0, b1, b2, 1, a1, a2].
//   - Pruebas frente a Julia: procesado.test.mjs, con los datos de
//     mse/m04-senales-ii/referencia/procesado.json (scripts/m04/generar_referencia.jl).
// =============================================================================
import { dft, ventana, rng, normal } from "./senales.js";
import { anchoBandaRuido, minimosCuadrados } from "./matematicas.js";

export { rng, normal, ventana, anchoBandaRuido };

const suma = (x) => x.reduce((s, v) => s + v, 0);
const lineal = (a, b, n) => Array.from({ length: n }, (_, i) => (n === 1 ? a : a + ((b - a) * i) / (n - 1)));

// ---------- números complejos [re, im] (solo para el diseño de filtros) ----------
const cmul = ([a, b], [c, d]) => [a * c - b * d, a * d + b * c];
const cdiv = ([a, b], [c, d]) => { const m = c * c + d * d; return [(a * c + b * d) / m, (b * c - a * d) / m]; };
const cabs2 = ([a, b]) => a * a + b * b;
function csqrt([a, b]) {
  const r = Math.hypot(a, b);
  const re = Math.sqrt((r + a) / 2), im = Math.sqrt(Math.max(0, (r - a) / 2));
  return [re, b < 0 || Object.is(b, -0) ? -im : im];
}

// ---------- ventanas (M4.1) ----------
/** Ventana simétrica de L puntos (la que se usa para diseñar filtros). */
export function ventanaSimetrica(nombre, L) {
  if (L === 1) return [1];
  const w = ventana(nombre, L - 1);
  return [...w, w[0]];
}
export const gananciaCoherente = (w) => suma(w) / w.length;

function moduloVentana(w, nu) {
  const N = w.length;
  let re = 0, im = 0;
  for (let n = 0; n < N; n++) {
    const a = (-2 * Math.PI * nu * n) / N;
    re += w[n] * Math.cos(a); im += w[n] * Math.sin(a);
  }
  return Math.hypot(re, im);
}
function primerCruce(w, nivel, paso = 0.01) {
  const W0 = moduloVentana(w, 0), nmax = w.length / 2;
  let a = 0;
  while (a + paso <= nmax) {
    if (moduloVentana(w, a + paso) / W0 <= nivel) {
      let b = a + paso;
      for (let i = 0; i < 50; i++) {
        const m = (a + b) / 2;
        if (moduloVentana(w, m) / W0 > nivel) a = m; else b = m;
      }
      return (a + b) / 2;
    }
    a += paso;
  }
  throw new Error(`la respuesta de la ventana no baja de ${nivel} antes de ${nmax} bins`);
}
/** Pérdida por escalonamiento (dB): amplitud de un tono a medio bin. */
export const perdidaEscalonamiento = (w) => -20 * Math.log10(moduloVentana(w, 0.5) / moduloVentana(w, 0));
/** Ancho del lóbulo principal a −3 dB, en bins. */
export const anchoBanda3dB = (w) => 2 * primerCruce(w, 1 / Math.SQRT2);
/** Nivel (dB) del mayor lóbulo lateral respecto del principal. */
export function nivelLobuloLateral(w, paso = 0.02) {
  const W0 = moduloVentana(w, 0), nmax = Math.min(w.length / 2, 64);
  const m = Array.from({ length: Math.floor(nmax / paso + 1e-9) + 1 }, (_, i) => moduloVentana(w, i * paso));
  let i = m.findIndex((v) => v <= W0 / Math.SQRT2);
  if (i < 0) throw new Error("la respuesta de la ventana no baja de −3 dB");
  while (i < m.length - 1 && m[i + 1] <= m[i]) i++;
  return 20 * Math.log10(Math.max(...m.slice(i)) / W0);
}
/** Correlación entre segmentos de Welch desplazados s muestras: Σ w[n]·w[n+s] / Σ w². */
export function correlacionSolape(w, s) {
  const N = w.length;
  if (s < 0) throw new Error("el desplazamiento no puede ser negativo");
  if (s >= N) return 0;
  let num = 0, den = 0;
  for (let n = 0; n < N; n++) { den += w[n] * w[n]; if (n + s < N) num += w[n] * w[n + s]; }
  return num / den;
}
/** {K, varianza} de la PSD de Welch frente a la de un solo periodograma (M4.1). */
export function varianzaWelch(w, solape, longitud) {
  const N = w.length;
  if (!(solape >= 0 && solape < 1)) throw new Error("el solape debe estar en [0, 1)");
  if (longitud < N) throw new Error("el registro es más corto que un segmento");
  const D = Math.max(1, Math.round(N * (1 - solape)));   // Math.round redondea los empates hacia arriba (no hay empates aquí)
  const K = Math.floor((longitud - N) / D) + 1;
  let s = 0;
  for (let j = 1; j < K; j++) s += (1 - j / K) * correlacionSolape(w, j * D) ** 2;
  return { K, varianza: (1 + 2 * s) / K };
}

// ---------- preprocesado (M4.3) ----------
/** Resta el polinomio de grado `grado` ajustado por mínimos cuadrados: {y, tendencia}. */
export function quitarTendencia(x, grado = 1) {
  const N = x.length;
  if (grado < 0) throw new Error("el grado no puede ser negativo");
  if (N <= grado) throw new Error(`hacen falta más de ${grado} muestras para ajustar un polinomio de grado ${grado}`);
  const s = lineal(-1, 1, N);
  const A = s.map((v) => Array.from({ length: grado + 1 }, (_, j) => v ** j));
  const c = minimosCuadrados(A, x);
  const tendencia = A.map((fila) => fila.reduce((a, v, j) => a + v * c[j], 0));
  return { y: x.map((v, i) => v - tendencia[i]), tendencia };
}
/** Remuestrea a una rejilla uniforme de fs Hz por interpolación lineal: {t, x, hueco}. */
export function interpolarUniforme(t, x, fs, tolerancia = 1.5) {
  if (t.length !== x.length) throw new Error("t y x deben tener la misma longitud");
  if (!(fs > 0)) throw new Error("fs debe ser positiva");
  const tt = [], xx = [];
  t.forEach((v, i) => { if (Number.isFinite(v) && Number.isFinite(x[i])) { tt.push(v); xx.push(x[i]); } });
  if (tt.length < 2) throw new Error("hacen falta al menos 2 muestras válidas");
  for (let i = 1; i < tt.length; i++) if (!(tt[i] > tt[i - 1])) throw new Error("los instantes deben ser estrictamente crecientes");
  const n = Math.floor((tt[tt.length - 1] - tt[0]) * fs + 1e-9) + 1;
  const tu = Array.from({ length: n }, (_, k) => tt[0] + k / fs), xu = new Array(n), hueco = new Array(n);
  let j = 0;
  tu.forEach((tau, k) => {
    while (j < tt.length - 2 && tt[j + 1] < tau) j++;
    const a = tt[j], b = tt[j + 1];
    xu[k] = xx[j] + ((xx[j + 1] - xx[j]) * (tau - a)) / (b - a);
    hueco[k] = b - a > tolerancia / fs;
  });
  return { t: tu, x: xu, hueco };
}

// ---------- integración y ruido (M4.4, M4.5) ----------
/** Integral acumulada por la regla del trapecio (valor inicial 0). */
export function integrarTrapecio(x, fs) {
  if (!(fs > 0)) throw new Error("fs debe ser positiva");
  const v = new Array(x.length).fill(0);
  for (let k = 1; k < x.length; k++) v[k] = v[k - 1] + (x[k - 1] + x[k]) / (2 * fs);
  return v;
}
/** Integra `orden` veces en frecuencia, anulando la continua y lo que queda por debajo de `fcorte`. */
export function integrarFrecuencia(x, fs, { fcorte, orden = 1 }) {
  const N = x.length;
  if (N < 2) throw new Error("hacen falta al menos 2 muestras");
  if (!(fs > 0)) throw new Error("fs debe ser positiva");
  if (!(fcorte >= 0)) throw new Error("fcorte no puede ser negativa");
  if (orden !== 1 && orden !== 2) throw new Error("orden debe ser 1 o 2");
  const X = dft(x), re = new Array(N), im = new Array(N);
  for (let k = 0; k < N; k++) {
    const kk = k <= N / 2 ? k : k - N, f = (Math.abs(kk) * fs) / N;
    if (k === 0 || f < fcorte) { re[k] = 0; im[k] = 0; continue; }
    // 1/(iω)^orden: orden 1 → −i/ω; orden 2 → −1/ω²
    const w = (2 * Math.PI * kk * fs) / N;
    const [a, b] = orden === 1 ? [0, -1 / w] : [-1 / (w * w), 0];
    re[k] = X.re[k] * a - X.im[k] * b; im[k] = X.re[k] * b + X.im[k] * a;
  }
  const y = dft(re, im.map((v) => -v));   // DFT inversa: conj(dft(conj(Y)))/N
  return y.re.map((v) => v / N);
}
const potencia = (v) => { const m = suma(v) / v.length; return suma(v.map((a) => (a - m) ** 2)) / v.length; };
/** SNR en dB con la potencia igual a la varianza de cada registro. */
export function snrDb(x, ruido) {
  const pn = potencia(ruido);
  if (!(pn > 0)) throw new Error("el ruido tiene potencia nula");
  return 10 * Math.log10(potencia(x) / pn);
}
function potenciaBanda(f, P, [fa, fb]) {
  let s = 0;
  f.forEach((v, k) => { if (v >= fa && v < fb) s += P[k]; });
  return s * (f[1] - f[0]);
}
/** SNR en dB dentro de una banda [fa, fb). */
export function snrBanda(f, P, Pruido, banda) {
  const pn = potenciaBanda(f, Pruido, banda);
  if (!(pn > 0)) throw new Error("el ruido tiene potencia nula en la banda");
  return 10 * Math.log10(potenciaBanda(f, P, banda) / pn);
}
/** Valor eficaz del ruido de un sensor de densidad plana: densidad·√(fb − fa). */
export function rmsRuidoBanda(densidad, fa, fb) {
  if (densidad < 0) throw new Error("la densidad de ruido no puede ser negativa");
  if (!(fb > fa && fa >= 0)) throw new Error("la banda debe cumplir 0 ≤ fa < fb");
  return densidad * Math.sqrt(fb - fa);
}

// ---------- espectros cruzados y espectrograma (M4.6, M4.7) ----------
function inicios(N, nseg, solape) {
  if (N < nseg) throw new Error(`la señal (${N} muestras) es más corta que un segmento (${nseg})`);
  if (!(solape >= 0 && solape < 1)) throw new Error("el solape debe estar en [0, 1)");
  if (nseg < 2) throw new Error("nseg debe ser al menos 2");
  const paso = Math.max(1, Math.round(nseg * (1 - solape)));
  const r = [];
  for (let i = 0; i + nseg <= N; i += paso) r.push(i);
  return r;
}
function unilateral(nseg) {
  const nf = Math.floor(nseg / 2) + 1, c = new Array(nf).fill(2);
  c[0] = 1;
  if (nseg % 2 === 0) c[nf - 1] = 1;
  return { nf, c };
}
function segmentoDFT(x, ini, nseg, w) {
  const s = x.slice(ini, ini + nseg), m = suma(s) / nseg;
  return dft(s.map((v, i) => (v - m) * w[i]));
}
/** Autoespectros Gxx, Gyy y espectro cruzado Gxy = {re, im} (Welch): {f, Gxx, Gyy, Gxy}. */
export function espectrosCruzados(x, y, fs, { nseg = 1024, solape = 0.5, ventana: nombre = "hann" } = {}) {
  if (x.length !== y.length) throw new Error("x e y deben tener la misma longitud");
  const ini = inicios(x.length, nseg, solape), w = ventana(nombre, nseg), { nf, c } = unilateral(nseg);
  const Gxx = new Array(nf).fill(0), Gyy = new Array(nf).fill(0), re = new Array(nf).fill(0), im = new Array(nf).fill(0);
  for (const i0 of ini) {
    const X = segmentoDFT(x, i0, nseg, w), Y = segmentoDFT(y, i0, nseg, w);
    for (let k = 0; k < nf; k++) {
      Gxx[k] += X.re[k] ** 2 + X.im[k] ** 2;
      Gyy[k] += Y.re[k] ** 2 + Y.im[k] ** 2;
      re[k] += X.re[k] * Y.re[k] + X.im[k] * Y.im[k];   // conj(X)·Y
      im[k] += X.re[k] * Y.im[k] - X.im[k] * Y.re[k];
    }
  }
  const esc = (k) => c[k] / (ini.length * fs * suma(w.map((v) => v * v)));
  return {
    f: Array.from({ length: nf }, (_, k) => (k * fs) / nseg),
    Gxx: Gxx.map((v, k) => v * esc(k)), Gyy: Gyy.map((v, k) => v * esc(k)),
    Gxy: { re: re.map((v, k) => v * esc(k)), im: im.map((v, k) => v * esc(k)) },
  };
}
/** Coherencia γ² = |Gxy|²/(Gxx·Gyy). */
export const coherencia = (Gxx, Gyy, Gxy) => Gxx.map((g, k) => (Gxy.re[k] ** 2 + Gxy.im[k] ** 2) / (g * Gyy[k]));
/** H1 = Gxy/Gxx: insesgado con ruido en la salida. */
export const frfH1 = (Gxx, Gxy) => ({ re: Gxy.re.map((v, k) => v / Gxx[k]), im: Gxy.im.map((v, k) => v / Gxx[k]) });
/** H2 = Gyy/conj(Gxy): insesgado con ruido en la entrada. */
export function frfH2(Gyy, Gxy) {
  const re = [], im = [];
  Gxy.re.forEach((a, k) => { const b = -Gxy.im[k], m = a * a + b * b; re.push((Gyy[k] * a) / m); im.push((-Gyy[k] * b) / m); });
  return { re, im };
}
/** Atajo: {f, H1, H2, coherencia, Gxx, Gyy, Gxy}. */
export function estimarFrf(x, y, fs, opciones = {}) {
  const { f, Gxx, Gyy, Gxy } = espectrosCruzados(x, y, fs, opciones);
  return { f, H1: frfH1(Gxx, Gxy), H2: frfH2(Gyy, Gxy), coherencia: coherencia(Gxx, Gyy, Gxy), Gxx, Gyy, Gxy };
}
/** Espectrograma: {t, f, P} con P[k][j] (frecuencia k, segmento j); su promedio temporal es la PSD de Welch. */
export function espectrograma(x, fs, { nseg = 256, solape = 0.75, ventana: nombre = "hann" } = {}) {
  const ini = inicios(x.length, nseg, solape), w = ventana(nombre, nseg), { nf, c } = unilateral(nseg);
  const ew = suma(w.map((v) => v * v)), P = Array.from({ length: nf }, () => new Array(ini.length));
  ini.forEach((i0, j) => {
    const X = segmentoDFT(x, i0, nseg, w);
    for (let k = 0; k < nf; k++) P[k][j] = (c[k] * (X.re[k] ** 2 + X.im[k] ** 2)) / (fs * ew);
  });
  return { t: ini.map((i0) => (i0 + nseg / 2) / fs), f: Array.from({ length: nf }, (_, k) => (k * fs) / nseg), P };
}

// ---------- filtros (M4.2) ----------
const TIPOS = ["pasabajos", "pasaaltos", "pasabanda", "rechazabanda"];
function validarDiseno(tipo, fc, fs) {
  if (!TIPOS.includes(tipo)) throw new Error(`tipo desconocido: ${tipo}`);
  if (!(fs > 0)) throw new Error("fs debe ser positiva");
  const bordes = Array.isArray(fc) ? fc : [fc], banda = tipo === "pasabanda" || tipo === "rechazabanda";
  if (bordes.length !== (banda ? 2 : 1)) throw new Error(`${tipo} necesita ${banda ? "[f1, f2]" : "una sola frecuencia de corte"}`);
  if (!bordes.every((b) => b > 0 && b < fs / 2)) throw new Error("las frecuencias de corte deben estar entre 0 y fs/2");
  if (banda && !(bordes[0] < bordes[1])) throw new Error("hace falta f1 < f2");
  return bordes;
}
const sinc = (x) => (x === 0 ? 1 : Math.sin(Math.PI * x) / (Math.PI * x));

/** Respuesta en frecuencia {re, im} de un FIR ({b}) o un IIR ({sos}) en `f` (número o vector). */
export function respuestaFrecuencia(filtro, f, fs) {
  const fr = Array.isArray(f) ? f : [f], re = [], im = [];
  for (const q of fr) {
    const w = (2 * Math.PI * q) / fs, polinomio = (c) => {
      let a = 0, b = 0;
      c.forEach((v, n) => { a += v * Math.cos(-w * n); b += v * Math.sin(-w * n); });
      return [a, b];
    };
    let H;
    if (filtro.b) H = polinomio(filtro.b);
    else { H = [1, 0]; for (const [b0, b1, b2, , a1, a2] of filtro.sos) H = cdiv(cmul(H, polinomio([b0, b1, b2])), polinomio([1, a1, a2])); }
    re.push(H[0]); im.push(H[1]);
  }
  return { re, im };
}
/** FIR por ventana: {b}. `fc` es un número o [f1, f2]. */
export function filtroFir(ntaps, fc, fs, { tipo = "pasabajos", ventana: nombre = "hamming" } = {}) {
  if (ntaps < 3) throw new Error("ntaps debe ser al menos 3");
  const bordes = validarDiseno(tipo, fc, fs);
  if ((tipo === "pasaaltos" || tipo === "rechazabanda") && ntaps % 2 === 0) throw new Error(`para ${tipo} ntaps debe ser impar`);
  const n = Array.from({ length: ntaps }, (_, i) => i - (ntaps - 1) / 2);
  const pasabajos = (f) => n.map((v) => ((2 * f) / fs) * sinc(((2 * f) / fs) * v));
  const delta = n.map((v) => (v === 0 ? 1 : 0));
  let h;
  if (tipo === "pasabajos") h = pasabajos(bordes[0]);
  else if (tipo === "pasaaltos") h = delta.map((d, i) => d - pasabajos(bordes[0])[i]);
  else if (tipo === "pasabanda") h = pasabajos(bordes[1]).map((v, i) => v - pasabajos(bordes[0])[i]);
  else h = delta.map((d, i) => d - (pasabajos(bordes[1])[i] - pasabajos(bordes[0])[i]));
  const wv = ventanaSimetrica(nombre, ntaps);
  h = h.map((v, i) => v * wv[i]);
  const fRef = tipo === "pasabajos" || tipo === "rechazabanda" ? 0 : tipo === "pasaaltos" ? fs / 2 : (bordes[0] + bordes[1]) / 2;
  const R = respuestaFrecuencia({ b: h }, fRef, fs), g = Math.hypot(R.re[0], R.im[0]);
  return { b: h.map((v) => v / g) };
}

const polosButterworth = (N) => Array.from({ length: N }, (_, i) => {
  const a = (Math.PI * (2 * (i + 1) + N - 1)) / (2 * N);
  return [Math.cos(a), Math.sin(a)];
});
function prototipoAAnalogico(N, tipo, w) {
  const pk = polosButterworth(N), ceros = (n) => Array.from({ length: n }, () => [0, 0]);
  if (tipo === "pasabajos") return { z: [], p: pk.map(([a, b]) => [w[0] * a, w[0] * b]), k: w[0] ** N };
  if (tipo === "pasaaltos") return { z: ceros(N), p: pk.map((q) => { const [a, b] = cdiv([w[0], 0], q); return [a, b]; }), k: 1 };
  const B = w[1] - w[0], w02 = w[0] * w[1], p = [];
  if (tipo === "pasabanda") {
    for (const q of pk) {
      const Bq = [B * q[0], B * q[1]], t = cmul(Bq, Bq), d = csqrt([t[0] - 4 * w02, t[1]]);
      p.push([(Bq[0] + d[0]) / 2, (Bq[1] + d[1]) / 2], [(Bq[0] - d[0]) / 2, (Bq[1] - d[1]) / 2]);
    }
    return { z: ceros(N), p, k: B ** N };
  }
  for (const q of pk) {
    const t = cmul(q, q), d = csqrt([B * B - 4 * w02 * t[0], -4 * w02 * t[1]]);
    p.push(cdiv([B + d[0], d[1]], [2 * q[0], 2 * q[1]]), cdiv([B - d[0], -d[1]], [2 * q[0], 2 * q[1]]));
  }
  const z0 = Math.sqrt(w02);
  return { z: [...Array.from({ length: N }, () => [0, z0]), ...Array.from({ length: N }, () => [0, -z0])], p, k: 1 };
}
// Agrupa raíces [re, im] en polinomios [1, c1, c2] (en z⁻¹): par conjugado → uno; dos reales → otro; una real → de primer orden.
function agruparRaices(r, ordenarPorModulo = false) {
  const tol = (q) => 1e-9 * Math.max(1, Math.hypot(q[0], q[1]));
  let complejas = r.filter((q) => q[1] > tol(q));
  const reales = r.filter((q) => Math.abs(q[1]) <= tol(q)).map((q) => q[0]).sort((a, b) => a - b);
  if (ordenarPorModulo) complejas = complejas.slice().sort((a, b) => Math.hypot(...a) - Math.hypot(...b));
  const pol = complejas.map((q) => [1, -2 * q[0], q[0] ** 2 + q[1] ** 2]);
  let i = 0, j = reales.length - 1;
  while (i < j) { pol.push([1, -(reales[i] + reales[j]), reales[i] * reales[j]]); i++; j--; }
  if (i === j) pol.push([1, -reales[i], 0]);
  return pol;
}
/** Butterworth IIR (bilineal con prewarping) como cascada de secciones: {sos}. */
export function filtroButterworth(orden, fc, fs, { tipo = "pasabajos" } = {}) {
  if (!(orden >= 1)) throw new Error("el orden debe ser al menos 1");
  const bordes = validarDiseno(tipo, fc, fs), fs2 = 2 * fs;
  const w = bordes.map((f) => fs2 * Math.tan((Math.PI * f) / fs));
  const { z, p, k } = prototipoAAnalogico(orden, tipo, w);
  const zd = [...z.map((q) => cdiv([fs2 + q[0], q[1]], [fs2 - q[0], -q[1]])), ...Array.from({ length: p.length - z.length }, () => [-1, 0])];
  const pd = p.map((q) => cdiv([fs2 + q[0], q[1]], [fs2 - q[0], -q[1]]));
  let num = [1, 0], den = [1, 0];
  for (const q of z) num = cmul(num, [fs2 - q[0], -q[1]]);
  for (const q of p) den = cmul(den, [fs2 - q[0], -q[1]]);
  const kd = k * cdiv(num, den)[0];
  const nu = agruparRaices(zd), de = agruparRaices(pd, true), nsec = Math.max(nu.length, de.length);
  const sos = Array.from({ length: nsec }, (_, s) => [...(nu[s] ?? [1, 0, 0]), ...(de[s] ?? [1, 0, 0])]);
  sos[0][0] *= kd; sos[0][1] *= kd; sos[0][2] *= kd;
  return { sos };
}
function tauPolinomio(c, w) {
  let nr = 0, ni = 0, dr = 0, di = 0;
  c.forEach((v, n) => {
    const a = -w * n;
    nr += n * v * Math.cos(a); ni += n * v * Math.sin(a); dr += v * Math.cos(a); di += v * Math.sin(a);
  });
  return cdiv([nr, ni], [dr, di])[0];
}
/** Retardo de grupo (s) en `f` (número o vector). */
export function retardoGrupo(filtro, f, fs) {
  const calc = (q) => {
    const w = (2 * Math.PI * q) / fs;
    if (filtro.b) return tauPolinomio(filtro.b, w) / fs;
    return filtro.sos.reduce((a, s) => a + tauPolinomio(s.slice(0, 3), w) - tauPolinomio(s.slice(3), w), 0) / fs;
  };
  return Array.isArray(f) ? f.map(calc) : calc(f);
}
function filtrarSos(sos, x, estacionario = false) {
  let y = x.slice();
  for (const [b0, b1, b2, , a1, a2] of sos) {
    let z1 = 0, z2 = 0;
    if (estacionario) { const g = (b0 + b1 + b2) / (1 + a1 + a2); z1 = (g - b0) * y[0]; z2 = (b2 - a2 * g) * y[0]; }
    for (let n = 0; n < y.length; n++) {
      const xn = y[n], yn = b0 * xn + z1;
      z1 = b1 * xn - a1 * yn + z2; z2 = b2 * xn - a2 * yn; y[n] = yn;
    }
  }
  return y;
}
function convolucionCausal(b, x) {
  const y = new Array(x.length).fill(0);
  for (let n = 0; n < x.length; n++) for (let k = 0; k < Math.min(b.length, n + 1); k++) y[n] += b[k] * x[n - k];
  return y;
}
/** Filtrado causal (estado inicial nulo). Con `compensar` (solo FIR de longitud impar) adelanta la salida (ntaps−1)/2 muestras. */
export function filtrar(filtro, x, { compensar = false } = {}) {
  if (filtro.sos) return filtrarSos(filtro.sos, x);
  const y = convolucionCausal(filtro.b, x);
  if (!compensar) return y;
  if (filtro.b.length % 2 === 0) throw new Error("compensar exige ntaps impar");
  const d = (filtro.b.length - 1) / 2;
  return [...y.slice(d), ...new Array(d).fill(0)];
}
/** Filtrado de fase cero (adelante-atrás, |H|²) con reflexión impar y estado estacionario en los extremos. */
export function filtrarFaseCero(filtro, x) {
  const N = x.length;
  if (N < 2) throw new Error("hacen falta al menos 2 muestras");
  const orden = filtro.sos ? 2 * filtro.sos.length + 1 : filtro.b.length, npad = Math.min(3 * orden, N - 1);
  const ext = [
    ...Array.from({ length: npad }, (_, i) => 2 * x[0] - x[npad - i]),
    ...x,
    ...Array.from({ length: npad }, (_, i) => 2 * x[N - 1] - x[N - 2 - i]),
  ];
  const pasada = (v) => (filtro.sos ? filtrarSos(filtro.sos, v, true) : convolucionCausal(filtro.b, v));
  const y = pasada(pasada(ext).reverse()).reverse();
  return y.slice(npad, npad + N);
}
/** Reduce q veces la frecuencia de muestreo con un FIR antialiasing de fase cero (Hamming, 20q+1 coeficientes). */
export function diezmar(x, q) {
  if (!(q >= 1)) throw new Error("q debe ser al menos 1");
  if (q === 1) return x.slice();
  const y = filtrar(filtroFir(20 * q + 1, 0.4 / q, 1, { tipo: "pasabajos", ventana: "hamming" }), x, { compensar: true });
  return y.filter((_, i) => i % q === 0);
}

// ---------- oscilador de 1 GDL (M4.6) ----------
/** Aceleración de un oscilador de 1 GDL, x'' + 2ζω x' + ω² x = u, partiendo del reposo (retenedor de orden cero exacto). */
export function aceleracion1gdl(u, f0, zeta, fs) {
  if (!(zeta >= 0 && zeta < 1)) throw new Error("zeta debe estar en [0, 1)");
  if (!(f0 > 0 && fs > 0)) throw new Error("f0 y fs deben ser positivas");
  const w = 2 * Math.PI * f0, wd = w * Math.sqrt(1 - zeta * zeta), h = 1 / fs;
  const c = Math.cos(wd * h), s = Math.sin(wd * h), e = Math.exp(-zeta * w * h), k = (zeta * w) / wd;
  const p11 = e * (c + k * s), p12 = (e * s) / wd, p21 = (-e * w * w * s) / wd, p22 = e * (c - k * s);
  // Γ = A⁻¹ (Φ − I) B con B = [0, 1]ᵀ y A = [[0, 1], [−w², −2ζw]]
  const r1 = p12, r2 = p22 - 1, det = w * w;                // A⁻¹ = (1/w²)·[[−2ζw, −1], [w², 0]]
  const g1 = (-2 * zeta * w * r1 - r2) / det, g2 = r1;
  let x = 0, v = 0;
  const a = new Array(u.length);
  for (let n = 0; n < u.length; n++) {
    a[n] = -2 * zeta * w * v - w * w * x + u[n];
    [x, v] = [p11 * x + p12 * v + g1 * u[n], p21 * x + p22 * v + g2 * u[n]];
  }
  return a;
}
