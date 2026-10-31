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
