// Pruebas de matematicas.js frente a Julia (mse/m02-matematicas/referencia/matrices.json,
// generado por scripts/m02/generar_referencia.jl) y frente a identidades matemáticas.
// Ejecutar con: deno test --no-check --allow-read recursos/js/   (o: node --test recursos/js/)
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import * as M from "./matematicas.js";

const ref = JSON.parse(readFileSync(new URL("../../mse/m02-matematicas/referencia/matrices.json", import.meta.url), "utf8"));

const cerca = (a, b, tol = 1e-9, msg = "") =>
  assert.ok(Math.abs(a - b) <= tol * Math.max(1, Math.abs(b)), `${msg} ${a} ≠ ${b}`);
const vecCerca = (a, b, tol = 1e-9, msg = "") => {
  assert.equal(a.length, b.length, `${msg} longitud`);
  a.forEach((v, i) => cerca(v, b[i], tol, `${msg}[${i}]`));
};
const matCerca = (A, B, tol = 1e-9, msg = "") => A.forEach((f, i) => vecCerca(f, B[i], tol, `${msg} fila ${i}`));

test("autovalores de una matriz simétrica (Jacobi) frente a Julia", () => {
  const { A, valores_propios } = ref.simetrica;
  const { valores, vectores } = M.autoSimetrica(A);
  vecCerca(valores, valores_propios, 1e-12);
  // A v = λ v
  valores.forEach((l, j) => vecCerca(M.matVec(A, vectores.map((f) => f[j])), vectores.map((f) => l * f[j]), 1e-10));
  // ortonormalidad
  matCerca(M.matMul(M.traspuesta(vectores), vectores), M.identidad(3), 1e-12);
});

test("SVD, normas, condicionamiento y mínimos cuadrados frente a Julia", () => {
  const r = ref.rectangular;
  const { U, S, V } = M.svd(r.R);
  vecCerca(S, r.valores_singulares, 1e-12);
  // A = U Σ Vᵀ y ortonormalidad de las columnas
  const rec = M.matMul(U.map((f) => f.map((u, k) => u * S[k])), M.traspuesta(V));
  matCerca(rec, r.R, 1e-12);
  matCerca(M.matMul(M.traspuesta(U), U), M.identidad(2), 1e-12);
  cerca(M.norma1(r.R), r.norma1);
  cerca(M.normaInf(r.R), r.normaInf);
  cerca(M.normaFro(r.R), r.normaFro);
  cerca(M.norma2(r.R), r.norma2, 1e-12);
  cerca(M.cond2(r.R), r.cond2, 1e-10);
  vecCerca(M.minimosCuadrados(r.R, r.b_ls), r.minimos_cuadrados, 1e-10);
  assert.equal(M.rango(r.R), 2);
});

test("SVD de una matriz ancha y de rango deficiente", () => {
  const W = [[1, 2, 3], [4, 5, 6]];
  const { U, S, V } = M.svd(W);
  assert.equal(S.length, 2);
  const rec = M.matMul(U.map((f) => f.map((u, k) => u * S[k])), M.traspuesta(V));
  matCerca(rec, W, 1e-12);
  assert.equal(M.rango([[1, 2], [2, 4], [3, 6]]), 1);
  assert.equal(M.cond2([[1, 2], [2, 4]]), Infinity);
});

test("Eckart–Young: el error de la aproximación de rango r es el valor singular siguiente", () => {
  const A = [[3, 1, 0, 2], [1, 4, 1, 0], [0, 1, 5, 1], [2, 0, 1, 6], [1, 1, 1, 1]];
  const { S } = M.svd(A);
  for (const r of [1, 2, 3]) {
    const Ar = M.aproxRango(A, r);
    const resta = A.map((f, i) => f.map((v, j) => v - Ar[i][j]));
    cerca(M.norma2(resta), S[r], 1e-9, `r=${r}`);
    cerca(M.normaFro(resta), Math.sqrt(S.slice(r).reduce((s, v) => s + v * v, 0)), 1e-9, `Fro r=${r}`);
  }
});

test("Hilbert 5×5: número de condición y solución del sistema", () => {
  const { H, cond2, solucion } = ref.hilbert5;
  cerca(M.cond2(H), cond2, 1e-6);
  vecCerca(M.resolver(H, new Array(5).fill(1)), solucion, 1e-6);
  assert.throws(() => M.resolver([[1, 2], [2, 4]], [1, 2]), /singular/);
});

test("FFT frente a Julia y a la definición; ifft(fft(x)) = x", () => {
  const { x, re, im } = ref.fft8;
  const X = M.fft(x);
  vecCerca(X.re, re, 1e-12);
  vecCerca(X.im, im, 1e-12);
  const n = x.length;
  const dftRe = Array.from({ length: n }, (_, k) => x.reduce((s, v, j) => s + v * Math.cos((2 * Math.PI * k * j) / n), 0));
  vecCerca(X.re, dftRe, 1e-12);
  const back = M.ifft(X.re, X.im);
  vecCerca(back.re, x, 1e-12);
  vecCerca(back.im, new Array(n).fill(0), 1e-12);
  assert.throws(() => M.fft(new Array(6).fill(1)), /potencia de 2/);
});

test("convolución circular directa, por FFT y como producto con la circulante", () => {
  const { a, b, c } = ref.conv_circular;
  vecCerca(M.convCircular(a, b), c, 1e-12);
  vecCerca(M.convCircularFFT(a, b), c, 1e-12);
  vecCerca(M.matVec(M.circulante(a), b), c, 1e-12);
});

test("Toeplitz, Hankel, circulante y Vandermonde: definición", () => {
  assert.deepEqual(M.toeplitz([1, 2, 3], [1, 5, 6]), [[1, 5, 6], [2, 1, 5], [3, 2, 1]]);
  assert.deepEqual(M.toeplitz([1, 2, 3]), [[1, 2, 3], [2, 1, 2], [3, 2, 1]]);
  assert.throws(() => M.toeplitz([1, 2], [9, 3]));
  assert.deepEqual(M.hankel([1, 2, 3], [3, 4, 5]), [[1, 2, 3], [2, 3, 4], [3, 4, 5]]);
  assert.deepEqual(M.hankel([1, 2, 3]), [[1, 2, 3], [2, 3, 0], [3, 0, 0]]);
  assert.deepEqual(M.hankelTrayectoria([1, 2, 3, 4, 5], 3), [[1, 2, 3], [2, 3, 4], [3, 4, 5]]);
  assert.deepEqual(M.circulante([1, 2, 3]), [[1, 3, 2], [2, 1, 3], [3, 2, 1]]);
  assert.deepEqual(M.vandermonde([1, 2, 3]), [[1, 1, 1], [1, 2, 4], [1, 3, 9]]);
  assert.deepEqual(M.promedioAntidiagonal([[1, 2], [3, 4]]), [1, 2.5, 4]);
});

test("autocorrelación y Yule–Walker frente a Julia", () => {
  const { z, r, phi, sigma2 } = ref.yule_walker;
  vecCerca(M.autocorrelacion(z, 5), r, 1e-12);
  const yw = M.yuleWalker(r, 2);
  vecCerca(yw.phi, phi, 1e-10);
  cerca(yw.sigma2, sigma2, 1e-10);
});

test("Yule–Walker recupera un AR(1) de autocorrelación teórica", () => {
  const phi = 0.7, s2 = 2;
  const r = Array.from({ length: 4 }, (_, k) => (s2 * phi ** k) / (1 - phi * phi));
  const yw = M.yuleWalker(r, 1);
  cerca(yw.phi[0], phi, 1e-12);
  cerca(yw.sigma2, s2, 1e-12);
});

test("AR(1) simulado con semilla fija: reproducible y con la autocorrelación esperada", () => {
  const x1 = M.simulaAR([0.8], 1, 20000, 7), x2 = M.simulaAR([0.8], 1, 20000, 7);
  assert.deepEqual(x1, x2);
  const r = M.autocorrelacion(x1, 3);
  cerca(r[1] / r[0], 0.8, 0.03);
  cerca(r[2] / r[0], 0.64, 0.05);
});

test("SSA de dos sinusoides: valores singulares y reconstrucción frente a Julia", () => {
  const { x, L, valores_singulares, reconstruccion_rango4 } = ref.ssa;
  const { reconstruccion, valoresSingulares } = M.ssa(x, L, 4);
  vecCerca(valoresSingulares.slice(0, 8), valores_singulares, 1e-9);
  vecCerca(reconstruccion, reconstruccion_rango4, 1e-9);
  // solo 4 valores singulares no nulos (dos sinusoides) y la señal se recupera
  assert.ok(valoresSingulares[4] < 1e-9 * valoresSingulares[0]);
  vecCerca(reconstruccion, x, 1e-8);
});

test("cadena de 4 masas y muelles: frecuencias y modos frente a Julia", () => {
  const { m, k, f, modos_abs } = ref.cadena4;
  const { M: Mm, K } = M.cadenaMasasMuelles(4, m, k);
  const modos = M.modosPropios(K, Mm);
  vecCerca(modos.f, f, 1e-10);
  modos.Phi.forEach((fila, i) => vecCerca(fila.map(Math.abs), modos_abs[i], 1e-8, `modo fila ${i}`));
  // normalizado a masa unidad: Φᵀ M Φ = I
  matCerca(M.matMul(M.traspuesta(modos.Phi), M.matMul(Mm, modos.Phi)), M.identidad(4), 1e-10);
  // fórmula cerrada ω_j² = 2k/m [1 − cos((2j−1)π/(2n+1))]
  modos.f.forEach((fj, j) => cerca((2 * Math.PI * fj) ** 2, ((2 * k) / m) * (1 - Math.cos(((2 * (j + 1) - 1) * Math.PI) / 9)), 1e-10));
});

test("edificio de cortante genérico frente a Julia", () => {
  const { m, k, K, f, modos_abs } = ref.edificio_generico;
  const e = M.edificioCortante(m, k);
  matCerca(e.K, K, 1e-14);
  const modos = M.modosPropios(e.K, e.M);
  vecCerca(modos.f, f, 1e-10);
  modos.Phi.forEach((fila, i) => vecCerca(fila.map(Math.abs), modos_abs[i], 1e-8, `modo fila ${i}`));
  // convención de signo: la suma de cada modo (columna) es positiva
  m.forEach((_, j) => assert.ok(modos.Phi.reduce((s, fila) => s + fila[j], 0) > 0, `signo del modo ${j}`));
});

test("MAC frente a Julia y propiedades", () => {
  const { a, b, valor } = ref.mac;
  cerca(M.mac(a, b), valor, 1e-12);
  cerca(M.mac(a, a), 1, 1e-14);
  cerca(M.mac(a, a.map((v) => -4.2 * v)), 1, 1e-14);
  assert.equal(M.mac([1, 0], [0, 1]), 0);
});

test("generador pseudoaleatorio determinista", () => {
  const u = M.rng(42), v = M.rng(42);
  const a = Array.from({ length: 5 }, u), b = Array.from({ length: 5 }, v);
  assert.deepEqual(a, b);
  assert.ok(a.every((x) => x >= 0 && x < 1));
  const g = M.rng(3), n = Array.from({ length: 20000 }, () => M.normal(g));
  const media = n.reduce((s, x) => s + x, 0) / n.length;
  const varz = n.reduce((s, x) => s + (x - media) ** 2, 0) / n.length;
  cerca(media, 0, 0.05);
  cerca(varz, 1, 0.05);
});
