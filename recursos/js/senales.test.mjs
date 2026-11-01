// Pruebas de senales.js frente a Julia (mse/m03-senales-i/referencia/senales.json,
// generado por scripts/m03/generar_referencia.jl) y frente a identidades.
// Ejecutar con: deno test --no-check --allow-read recursos/js/   (o: node --test recursos/js/)
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import * as S from "./senales.js";

const ref = JSON.parse(readFileSync(new URL("../../mse/m03-senales-i/referencia/senales.json", import.meta.url), "utf8"));

const cerca = (a, b, tol = 1e-10, msg = "") =>
  assert.ok(Math.abs(a - b) <= tol * Math.max(1, Math.abs(b)), `${msg} ${a} ≠ ${b}`);
const vecCerca = (a, b, tol = 1e-10, msg = "") => {
  assert.equal(a.length, b.length, `${msg} longitud`);
  a.forEach((v, i) => cerca(v, b[i], tol, `${msg}[${i}]`));
};
const suma = (x) => x.reduce((s, v) => s + v, 0);

test("descriptores temporales frente a Julia", () => {
  const r = ref.descriptores, d = S.descriptores(r.x);
  for (const k of ["media", "varianza", "rms", "rms_fluctuante", "pico", "pico_fluctuante", "pico_pico", "cresta", "cresta_fluctuante", "asimetria", "curtosis", "curtosis_exceso"])
    cerca(d[k], r[k], 1e-12, k);
  // RMS² = μ² + σ²
  cerca(d.rms ** 2, d.media ** 2 + d.varianza, 1e-12);
});

test("convertidor ideal frente a Julia", () => {
  const r = ref.cuantizar, c = S.cuantizar(r.x, { bits: r.bits, rango: r.rango, offset: r.offset });
  cerca(c.q, r.q);
  vecCerca(c.y, r.y, 1e-12);
  assert.deepEqual(c.saturada, r.saturada);
});

test("frecuencia aparente frente a Julia", () => {
  const r = ref.alias;
  vecCerca(r.f.map((f) => S.frecuenciaAparente(f, r.fs)), r.aparente, 1e-12);
});

test("DFT de longitud arbitraria (Bluestein) frente a Julia y a la DFT directa", () => {
  const r = ref.dft;
  let X = S.dft(r.x6);
  vecCerca(X.re, r.re6, 1e-10); vecCerca(X.im, r.im6, 1e-10);
  X = S.dft(r.x12);
  vecCerca(X.re, r.re12, 1e-10); vecCerca(X.im, r.im12, 1e-10);
  vecCerca(S.dft(r.mano).re, r.mano_re, 1e-12);
  // N = 7 frente a la definición
  const x = [0.3, -1, 2, 0.5, 0, 1.5, -0.7], N = 7, D = S.dft(x);
  for (let k = 0; k < N; k++) {
    let re = 0, im = 0;
    x.forEach((v, n) => { re += v * Math.cos((-2 * Math.PI * k * n) / N); im += v * Math.sin((-2 * Math.PI * k * n) / N); });
    cerca(D.re[k], re, 1e-10); cerca(D.im[k], im, 1e-10);
  }
});

test("periodograma y espectro de amplitud frente a Julia", () => {
  const r = ref.periodograma;
  let p = S.periodograma(r.x, r.fs);
  vecCerca(p.f, r.f, 1e-12); vecCerca(p.P, r.P, 1e-10, "P");
  vecCerca(S.periodograma(r.x, r.fs, { quitarMedia: false }).P, r.P_con_media, 1e-10, "P con media");
  p = S.periodograma(r.x, r.fs, { ventana: "hann", nfft: 32 });
  vecCerca(p.f, r.f_hann32, 1e-12); vecCerca(p.P, r.P_hann32, 1e-10, "P hann32");
  const a = S.espectroAmplitud(r.x, r.fs);
  vecCerca(a.A, r.A, 1e-10, "A");
  // la fase solo está bien definida donde hay amplitud
  a.fase.forEach((v, k) => { if (r.A[k] > 1e-8) cerca(v, r.fase[k], 1e-9, `fase[${k}]`); });
  vecCerca(S.espectroAmplitud(r.x, r.fs, { ventana: "hann", nfft: 32 }).A, r.A_hann32, 1e-10, "A hann32");
});

test("Parseval, DC y Nyquist", () => {
  const fs = 100, N = 1000, A = 1.5, f0 = 12.3, c = 0.7;
  const x = Array.from({ length: N }, (_, n) => c + A * Math.cos(2 * Math.PI * f0 * n / fs + 0.4));
  const { f, P } = S.periodograma(x, fs, { quitarMedia: false });
  const df = f[1] - f[0];
  cerca(P[0] * df, c * c, 1e-10, "DC");
  cerca(suma(P) * df, c * c + (A * A) / 2, 1e-10, "Parseval");
  const ny = S.periodograma(Array.from({ length: 16 }, (_, n) => (-1) ** n), 16, { quitarMedia: false });
  cerca(ny.P[ny.P.length - 1] * (ny.f[1] - ny.f[0]), 1, 1e-12, "Nyquist");
});

test("Welch frente a Julia y Parseval sobre los segmentos ponderados", () => {
  const r = ref.welch, w = S.welch(r.x, r.fs, { nseg: r.nseg, solape: r.solape });
  vecCerca(w.f, r.f, 1e-12); vecCerca(w.P, r.P, 1e-10, "P");
  assert.equal(w.segmentos, 7);
  // Σ P Δf = media de Σ(x_s w)²/Σw² sobre los segmentos (con la media de cada uno restada)
  const h = S.ventana("hann", r.nseg), ew = suma(h.map((v) => v * v));
  const porSeg = w.inicios.map((i) => {
    const s = r.x.slice(i, i + r.nseg), m = suma(s) / r.nseg;
    return suma(s.map((v, n) => ((v - m) * h[n]) ** 2)) / ew;
  });
  cerca(suma(w.P) * (w.f[1] - w.f[0]), suma(porSeg) / porSeg.length, 1e-10);
});

test("potencia por bandas, NPSD y ANPSD frente a Julia", () => {
  const r = ref.bandas, w = ref.welch;
  const b = S.potenciaBandas(w.f, ref.welch.P, r.bandas);
  vecCerca(b.potencia, r.potencia, 1e-10); vecCerca(b.fraccion, r.fraccion, 1e-10);
  const n = S.psdNormalizada(w.f, w.P, r.banda_n);
  vecCerca(n.f, r.f_n, 1e-12); vecCerca(n.Pn, r.Pn, 1e-10);
  cerca(suma(n.Pn), 1, 1e-12);
  // r.Ps es una matriz bins × canales; anpsd recibe un array de canales
  const canales = r.Ps[0].map((_, j) => r.Ps.map((fila) => fila[j]));
  const a = S.anpsd(w.f, canales, r.banda_n);
  vecCerca(a.A, r.anpsd, 1e-10);
  cerca(suma(a.A), 1, 1e-12);
});

test("utilidades: redondeo al par, dB, coma e histograma", () => {
  assert.deepEqual([0.5, 1.5, 2.5, -0.5, -1.5, 2.4].map(S.redondeo), [0, 2, 2, -0, -2, 2]);
  cerca(S.dB(100, 1), 20); cerca(S.dB(1e-6, 1e-12), 60);
  assert.equal(S.coma(3.14159, 2), "3,14");
  const h = S.histograma([0.1, 0.2, 0.9, 1.5], 2, 0, 1);
  assert.deepEqual(h.map((c) => c.n), [2, 1]);
});

test("ruido de color frente a Julia", () => {
  const r = ref.colorear;
  vecCerca(S.colorear(r.r, 1), r.rosa, 1e-9, "rosa");
  vecCerca(S.colorear(r.r, 2), r.marron, 1e-9, "marrón");
});

// ---------- cadena de adquisición: filtro de Butterworth y suma de tonos ----------
test("ganancia de Butterworth: −3 dB en fc, pendiente −20·orden dB/década y errores", () => {
  const dBg = (f, fc, n) => 20 * Math.log10(S.gananciaButterworth(f, fc, n));
  for (const n of [1, 2, 4, 8]) {
    cerca(S.gananciaButterworth(7, 7, n), 1 / Math.sqrt(2), 1e-14, `|H(fc)| orden ${n}`);
    cerca(dBg(7, 7, n), -3.010299956639812, 1e-12, `−3 dB orden ${n}`);
    cerca(S.gananciaButterworth(0, 7, n), 1, 1e-15, "DC");
    // lejos de fc: de 100·fc a 1000·fc la caída es de 20·n dB
    cerca(dBg(1000 * 7, 7, n) - dBg(100 * 7, 7, n), -20 * n, 1e-4, `pendiente orden ${n}`);
  }
  // valor exacto de orden 2 en f = 2·fc: 1/√(1+16)
  cerca(S.gananciaButterworth(2, 1, 2), 1 / Math.sqrt(17), 1e-15);
  // monótona decreciente
  assert.ok(S.gananciaButterworth(3, 5, 3) > S.gananciaButterworth(6, 5, 3));
  assert.throws(() => S.gananciaButterworth(1, 0, 2), /fc/);
  assert.throws(() => S.gananciaButterworth(1, -3, 2), /fc/);
  assert.throws(() => S.gananciaButterworth(1, NaN, 2), /fc/);
  assert.throws(() => S.gananciaButterworth(1, 5, 0), /orden/);
  assert.throws(() => S.gananciaButterworth(1, 5, 1.5), /orden/);
  assert.throws(() => S.gananciaButterworth(1, 5, -2), /orden/);
});

test("suma de tonos frente a valores a mano y con filtro nulo", () => {
  const t = [0, 0.25, 0.5];
  // 2·sin(2πt) + 1·sin(4πt + π/2) = 2 sin(2πt) + cos(4πt) → [1, 1, 1]
  const tonos = [{ f: 1, A: 2 }, { f: 2, A: 1, fase: Math.PI / 2 }];
  const y = S.sumaTonos(t, tonos);
  assert.ok(y instanceof Float64Array);
  vecCerca(Array.from(y), [1, 1, 1], 1e-14, "sin filtro");
  // filtro null / undefined coincide con la suma sin filtrar
  vecCerca(Array.from(S.sumaTonos(t, tonos, null)), Array.from(y), 1e-15);
  vecCerca(Array.from(S.sumaTonos(t, tonos, undefined)), Array.from(y), 1e-15);
  // con filtro de orden 2 y fc = 1 Hz: g(1) = 1/√2, g(2) = 1/√17 → (2/√2)·sin(2πt) + cos(4πt)/√17
  const yf = S.sumaTonos(t, tonos, { fc: 1, orden: 2 });
  vecCerca(Array.from(yf), [1 / Math.sqrt(17), Math.SQRT2 - 1 / Math.sqrt(17), 1 / Math.sqrt(17)], 1e-14, "filtrado");
  // un tono muy por encima de fc queda atenuado; uno muy por debajo pasa casi intacto
  const tt = Array.from({ length: 100 }, (_, n) => n / 1000);
  const alto = S.sumaTonos(tt, [{ f: 400, A: 1 }], { fc: 4, orden: 3 });
  assert.ok(Math.max(...alto.map(Math.abs)) < 1e-5);
  const bajo = S.sumaTonos(tt, [{ f: 0.5, A: 1 }], { fc: 50, orden: 3 });
  vecCerca(Array.from(bajo), tt.map((ti) => Math.sin(2 * Math.PI * 0.5 * ti)), 1e-9);
  // lista vacía de tonos y de tiempos
  assert.deepEqual(Array.from(S.sumaTonos(t, [])), [0, 0, 0]);
  assert.equal(S.sumaTonos([], tonos).length, 0);
  // admite Float64Array como tiempos y propaga los errores del filtro
  vecCerca(Array.from(S.sumaTonos(new Float64Array(t), tonos)), [1, 1, 1], 1e-14);
  assert.throws(() => S.sumaTonos(t, tonos, { fc: 0, orden: 2 }), /fc/);
  assert.throws(() => S.sumaTonos(t, tonos, { fc: 1, orden: 0.5 }), /orden/);
});

// ---------- paridad con Julia y Python ----------
// periodograma de Welch calculado a mano: DFT directa, Hann periódica y media restada por segmento
function welchDirecto(x, fs, nseg, paso) {
  const w = Array.from({ length: nseg }, (_, n) => 0.5 - 0.5 * Math.cos((2 * Math.PI * n) / nseg));
  const ew = suma(w.map((v) => v * v)), nf = Math.floor(nseg / 2) + 1;
  const P = new Array(nf).fill(0);
  let K = 0;
  for (let i = 0; i + nseg <= x.length; i += paso, K++) {
    const s = x.slice(i, i + nseg), m = suma(s) / nseg;
    for (let k = 0; k < nf; k++) {
      let re = 0, im = 0;
      s.forEach((v, n) => { const a = (v - m) * w[n]; re += a * Math.cos((-2 * Math.PI * k * n) / nseg); im += a * Math.sin((-2 * Math.PI * k * n) / nseg); });
      const c = k === 0 || (nseg % 2 === 0 && k === nf - 1) ? 1 : 2;
      P[k] += (c * (re * re + im * im)) / (fs * ew);
    }
  }
  return { P: P.map((v) => v / K), K };
}
const serie = (N) => Array.from({ length: N }, (_, n) => Math.sin(0.37 * n) + 0.3 * Math.cos(1.9 * n * n / N) + 0.01 * n);

test("Welch con nseg que no es potencia de 2 frente al cálculo directo", () => {
  // Julia exige potencia de 2; JS (Bluestein) y Python no. El resultado es el promedio de periodogramas.
  for (const [nseg, solape, paso] of [[12, 0.5, 6], [12, 0.3, 8], [15, 0.5, 8], [30, 0.0, 30]]) {
    const x = serie(97), w = S.welch(x, 50, { nseg, solape }), d = welchDirecto(x, 50, nseg, paso);
    assert.equal(w.segmentos, d.K, `K con nseg=${nseg}`);
    vecCerca(w.P, d.P, 1e-10, `P nseg=${nseg} solape=${solape}`);
    vecCerca(w.f, Array.from({ length: Math.floor(nseg / 2) + 1 }, (_, k) => (k * 50) / nseg), 1e-12);
  }
});

test("paso de Welch: redondeo al par como Julia y Python (solape ≠ 0,5)", () => {
  // nseg·(1−solape) = 2,5: Math.round daría 3 y el redondeo al par da 2
  const x = serie(30), w = S.welch(x, 10, { nseg: 10, solape: 0.75 });
  assert.deepEqual(w.inicios, Array.from({ length: 11 }, (_, i) => 2 * i));
  vecCerca(w.P, welchDirecto(x, 10, 10, 2).P, 1e-10);
  // 1,5 → 2, 3,5 → 4 y 4,5 → 4 (siempre al par)
  assert.equal(S.welch(serie(40), 10, { nseg: 6, solape: 0.75 }).inicios[1], 2);
  assert.equal(S.welch(serie(40), 10, { nseg: 14, solape: 0.75 }).inicios[1], 4);
  assert.equal(S.welch(serie(40), 10, { nseg: 18, solape: 0.75 }).inicios[1], 4);
  // el paso nunca baja de 1
  assert.equal(S.welch(serie(12), 10, { nseg: 8, solape: 0.99 }).inicios[1], 1);
  // sin solape y con solape no diádico
  assert.deepEqual(S.welch(serie(40), 10, { nseg: 10, solape: 0 }).inicios, [0, 10, 20, 30]);
  assert.deepEqual(S.welch(serie(40), 10, { nseg: 16, solape: 0.3 }).inicios, [0, 11, 22]);   // 11,2 → 11
});

test("errores lanzados por welch, periodograma y compañía", () => {
  assert.throws(() => S.welch(serie(10), 1, { nseg: 16 }), /más corta/);
  assert.throws(() => S.welch(serie(40), 1, { nseg: 16, solape: 1 }), /solape/);
  assert.throws(() => S.welch(serie(40), 1, { nseg: 16, solape: -0.1 }), /solape/);
  assert.throws(() => S.periodograma(serie(16), 1, { nfft: 8 }), /nfft/);
  assert.throws(() => S.descriptores([]), /vacía/);
  assert.throws(() => S.dft([]), /vacía/);
  assert.throws(() => S.psdNormalizada([0, 1, 2], [1, 1, 1], [5, 6]), /banda/);
  assert.throws(() => S.psdNormalizada([0, 1, 2], [0, 0, 0]), /nula/);
  assert.throws(() => S.colorear([1], 1), /2 muestras/);
});

test("cuantizar exige bits enteros ≥ 1 y rango positivo", () => {
  for (const bits of [0, -3, 2.5, 6.0000001, NaN, Infinity, "6x", undefined])
    assert.throws(() => S.cuantizar([0.1], { bits, rango: 1 }), /bits/, `bits=${bits}`);
  assert.throws(() => S.cuantizar([0.1], { bits: 8, rango: 0 }), /rango/);
  assert.throws(() => S.cuantizar([0.1], { bits: 8, rango: -1 }), /rango/);
  // bits = 1: dos niveles, −R y 0 (q = R)
  const c = S.cuantizar([-2, -0.4, 0.6, 2], { bits: 1, rango: 1 });
  assert.deepEqual(c.y.map((v) => v + 0), [-1, 0, 0, 0]);
  assert.deepEqual(c.saturada, [true, false, true, true]);
  cerca(S.cuantizar([0], { bits: 6.0, rango: 2 }).q, 4 / 64);
});

test("coma nunca devuelve «-0,00»", () => {
  assert.equal(S.coma(-0.001, 2), "0,00");
  assert.equal(S.coma(-0.0000001, 3), "0,000");
  assert.equal(S.coma(-0, 2), "0,00");
  assert.equal(S.coma(-0.004, 0), "0");
  assert.equal(S.coma(-0.4, 0), "0");
  assert.equal(S.coma(0.001, 2), "0,00");
  assert.equal(S.coma(-0.01, 2), "-0,01");
  assert.equal(S.coma(-1.5, 1), "-1,5");
  assert.equal(S.coma(-10.004, 2), "-10,00");
  assert.equal(S.coma(NaN), "—");
  assert.equal(S.coma(Infinity), "—");
});

test("histograma: intervalo semiabierto [lo, hi); el valor igual a hi no se cuenta", () => {
  const h = S.histograma([0, 0.5, 0.999, 1, -0.1, 1.2], 2, 0, 1);
  assert.deepEqual(h.map((c) => c.n), [1, 2]);            // 1 (= hi), −0,1 y 1,2 quedan fuera
  assert.deepEqual(h.map((c) => [c.x0, c.x1]), [[0, 0.5], [0.5, 1]]);
  assert.equal(suma(h.map((c) => c.n)), 3);
});

test("periodograma con nfft impar: sin bin de Nyquist", () => {
  const x = [0.3, -1, 2, 0.5, 0, 1.5, -0.7], N = 7, fs = 14;
  const { f, P } = S.periodograma(x, fs);
  assert.equal(f.length, 4);
  cerca(f[3], (3 * fs) / N, 1e-14);
  assert.ok(f[3] < fs / 2);
  // todos los bins salvo DC se duplican (no hay Nyquist que dejar sencillo)
  const m = suma(x) / N, X = S.dft(x.map((v) => v - m));
  P.forEach((v, k) => cerca(v, ((k === 0 ? 1 : 2) * (X.re[k] ** 2 + X.im[k] ** 2)) / (fs * N), 1e-12, `P[${k}]`));
  // Parseval: Σ P Δf = varianza (divisor N)
  cerca(suma(P) * (f[1] - f[0]), suma(x.map((v) => (v - m) ** 2)) / N, 1e-12, "Parseval");
  // con relleno a nfft = 9 también es impar: 5 bins, el último en 4·fs/9
  const p9 = S.periodograma(x, fs, { nfft: 9 });
  assert.equal(p9.f.length, 5);
  cerca(p9.f[4], (4 * fs) / 9, 1e-14);
  // el espectro de amplitud usa el mismo criterio
  assert.equal(S.espectroAmplitud(x, fs).f.length, 4);
});

test("colorear con alfa negativo y con N = 2 (espejo de Python y de Julia)", () => {
  const r = [0.5, -1.2, 0.3, 2.0, -0.7, 1.1, 0.0, -0.4];
  // valores de senales.colorear(r, α) en Python (misma fórmula que Resonancia.colorear)
  vecCerca(S.colorear(r, -1.5), [0.670970912753846, -1.2225830400063322, -0.030707952870855457, 1.690768615776496, -1.376279885780816, 1.0027615123591611, -0.2540871562133232, -0.48084300601817614], 1e-10, "α = −1,5");
  vecCerca(S.colorear(r, -0.5), [0.46523927993660225, -1.3870954808922518, 0.057425374544008555, 1.817570095985223, -1.1219326355216575, 0.9595223913870771, -0.22127034599714104, -0.5694586794418606], 1e-10, "α = −0,5");
  // N = 2: solo hay un bin no nulo (k = 1, ganancia 1): la salida es ±(1, −1) según el signo de r₀ − r₁
  vecCerca(S.colorear([3, 1], 1), [1, -1], 1e-12, "N=2 a");
  vecCerca(S.colorear([1, 3], 2), [-1, 1], 1e-12, "N=2 b");
  vecCerca(S.colorear([1, 3], -3), [-1, 1], 1e-12, "N=2 alfa negativo");
  // N = 3
  vecCerca(S.colorear([0.2, -1, 0.7], 1), [0.32708852, -1.35508101, 1.02799249], 1e-7, "N=3");
  // media 0 y desviación típica 1 con cualquier alfa
  for (const a of [-2, -1, 0, 1, 2]) {
    const y = S.colorear(r, a), m = suma(y) / y.length;
    cerca(m, 0, 1e-12); cerca(Math.sqrt(suma(y.map((v) => (v - m) ** 2)) / y.length), 1, 1e-12);
  }
});
