// Pruebas de vibraciones.js frente a valores de referencia calculados en Julia
// (LinearAlgebra: exponencial matricial, inversión directa, autovalores del
// espacio de estados y RK4 con paso 1e-4). Ejecutar con: node --test recursos/js/
import test from "node:test";
import assert from "node:assert/strict";
import * as V from "./vibraciones.js";

const cerca = (a, b, tol = 1e-9, msg = "") =>
  assert.ok(Math.abs(a - b) <= tol * Math.max(1, Math.abs(b)), `${msg} ${a} ≠ ${b}`);

test("respuesta libre de 1 GDL (subcrítico, crítico, supercrítico)", () => {
  const ref = [
    [1, 100, 0.6, 0.01, 0.3, 0.37, -0.0219333729256],
    [1, 100, 0.6, 0.01, 0.3, 1.9, 0.00802274264266],
    [1, 100, 20, 0.01, 0.3, 0.37, 0.00390631718231],
    [1, 100, 20, 0.01, 0.3, 1.9, 4.3141532569e-9],
    [1, 100, 40, 0.01, 0.3, 0.37, 0.00721093239214],
    [1, 100, 40, 0.01, 0.3, 1.9, 0.000119549703571],
  ];
  for (const [m, k, c, x0, v0, t, x] of ref) cerca(V.sdofLibre(m, k, c, x0, v0, t), x, 1e-9, `c=${c} t=${t}`);
});

test("parámetros del 1 GDL: ζ, ω_d, polos", () => {
  const p = V.sdofParametros(1, 100, 0.6);
  cerca(p.wn, 10);
  cerca(p.zeta, 0.03);
  cerca(p.sigma, -0.3);
  cerca(p.wd, 10 * Math.sqrt(1 - 0.03 ** 2));
  assert.equal(p.regimen, "subcrítico");
  assert.equal(V.sdofParametros(1, 100, 20).regimen, "crítico");
  assert.equal(V.sdofParametros(1, 100, 40).regimen, "supercrítico");
});

test("receptancia viscosa e histerética", () => {
  for (const [w, re, im] of [[9, 0.0486979700636, -0.0138404757023], [10, 0, -0.166666666667], [11.5, -0.0296504692359, -0.00634382132489]]) {
    const H = V.receptancia(1, 100, 0.6, w);
    cerca(H.re, re, 1e-9); cerca(H.im, im, 1e-9);
  }
  for (const [w, re, im] of [[8, 0.0212264150943, -0.0117924528302], [10, 0, -0.05], [12, -0.0188356164384, -0.00856164383562]]) {
    const H = V.receptanciaHisteretica(1, 100, 20, w);
    cerca(H.re, re, 1e-9); cerca(H.im, im, 1e-9);
  }
});

test("movilidad e inertancia: módulo y fase relativos a la receptancia", () => {
  const w = 7.3, a = V.receptancia(1, 100, 0.6, w);
  cerca(V.cabs(V.movilidad(1, 100, 0.6, w)), w * V.cabs(a));
  cerca(V.cabs(V.inertancia(1, 100, 0.6, w)), w * w * V.cabs(a));
  cerca(V.faseGrados(V.movilidad(1, 100, 0.6, w)) - V.faseGrados(a), 90, 1e-9);
  cerca(Math.abs(V.faseGrados(V.inertancia(1, 100, 0.6, w)) - V.faseGrados(a)), 180, 1e-9);
});

test("respuesta forzada total frente a RK4 en Julia", () => {
  for (const [t, x] of [[1, -0.0140122086407], [3, -0.070859740318], [6, 0.102474180723]])
    cerca(V.sdofForzada(1, 100, 0.6, 1, 9.5, 0, 0, t).total, x, 1e-6, `t=${t}`);
});

test("amplificación Q y pico de la receptancia", () => {
  cerca(V.factorAmplificacion(1, 0.03), 1 / 0.06, 1e-12);
  cerca(V.factorAmplificacion(1, 0.05), 10, 1e-12);
  const H = V.receptancia(1, 100, 0.6, 10);
  cerca(V.cabs(H), 1 / (0.6 * 10), 1e-12);
});

test("respuesta impulsional: h(0)=0 y h'(0)=1/m", () => {
  assert.equal(V.sdofImpulsional(2, 50, 1, 0), 0);
  const dt = 1e-6;
  cerca((V.sdofImpulsional(2, 50, 1, dt) - V.sdofImpulsional(2, 50, 1, 0)) / dt, 0.5, 1e-4);
});

test("raíces de polinomios (Durand–Kerner)", () => {
  const r = V.raicesPolinomio([1, -6, 11, -6]).map((z) => z.re).sort((a, b) => a - b);
  [1, 2, 3].forEach((v, i) => cerca(r[i], v, 1e-9));
});

const caso = {
  prop: { ...V.cadena2({ m1: 5, m2: 10, k1: 2, k2: 2, k3: 4, c1: 1, c2: 1, c3: 2 }) },
  noprop: { ...V.cadena2({ m1: 5, m2: 10, k1: 2, k2: 2, k3: 4, c1: 2, c2: 4, c3: 1 }) },
};

test("matrices del ejemplo de dos masas", () => {
  assert.deepEqual(caso.prop.K, [[4, -2], [-2, 6]]);
  assert.deepEqual(caso.prop.C, [[2, -1], [-1, 3]]);
  assert.deepEqual(caso.noprop.C, [[6, -4], [-4, 5]]);
});

test("modos no amortiguados normalizados a la masa", () => {
  const [a, b] = V.modosNoAmortiguados(caso.prop);
  cerca(a.w, Math.sqrt(0.4)); cerca(b.w, 1);
  cerca(a.phi[0], 1 / Math.sqrt(15)); cerca(a.phi[1], 1 / Math.sqrt(15));
  cerca(b.phi[0], Math.sqrt(2 / 15)); cerca(b.phi[1], -Math.sqrt(2 / 15) / 2);
});

test("proporcionalidad", () => {
  assert.equal(V.esProporcional(caso.prop), true);
  assert.equal(V.esProporcional(caso.noprop), false);
});

test("polos del ejemplo (proporcional y no proporcional)", () => {
  const p = V.polosYModos(caso.prop).filter((x) => x.s.im > 0);
  cerca(p[0].s.re, -0.1); cerca(p[0].s.im, 0.62449979984); cerca(p[0].zeta, 0.158113883008); cerca(p[0].omega, 0.632455532034);
  cerca(p[1].s.re, -0.25); cerca(p[1].s.im, 0.968245836552); cerca(p[1].zeta, 0.25);
  const q = V.polosYModos(caso.noprop).filter((x) => x.s.im > 0);
  cerca(q[0].s.re, -0.0953630921246, 1e-8); cerca(q[0].s.im, 0.629493883389, 1e-8); cerca(q[0].zeta, 0.149782702944, 1e-8);
  cerca(q[1].s.re, -0.754636907875, 1e-8); cerca(q[1].s.im, 0.645994143041, 1e-8); cerca(q[1].zeta, 0.759673028182, 1e-8);
});

test("residuos modales (apuntes: caso proporcional)", () => {
  const p = V.polosYModos(caso.prop).filter((x) => x.s.im > 0);
  const A = (m, j, k) => V.cmul(m.phi[j], m.phi[k]);
  cerca(A(p[0], 0, 0).im, -Math.sqrt(39) / 117, 1e-9); cerca(A(p[0], 0, 0).re, 0, 1e-9);
  cerca(A(p[1], 0, 0).im, -(4 * Math.sqrt(15)) / 225, 1e-9);
  cerca(A(p[1], 1, 0).im, (2 * Math.sqrt(15)) / 225, 1e-9);
});

test("receptancia matricial: inversión directa frente a Julia y a las sumas modales", () => {
  const ref = {
    prop: [[0.5, 0.467692307692, -0.258461538462, 0.227692307692, -0.178461538462, 0.347692307692, -0.218461538462],
           [1.2, -0.166834448269, -0.15855361434, -0.00787491069689, 0.0582093914399, -0.087354679483, -0.0501721114503]],
    noprop: [[0.5, 0.334122421373, -0.297598917822, 0.248900913088, -0.156915793033, 0.367602299628, -0.210010145418],
             [1.2, -0.0629688158174, -0.0832193044193, -0.0479510116087, 0.0215455779892, -0.0736500328351, -0.0303364877699]],
  };
  for (const nombre of ["prop", "noprop"]) {
    for (const [w, r11, i11, r21, i21, r22, i22] of ref[nombre]) {
      const R = V.receptanciaMatriz(caso[nombre], w);
      cerca(R[0][0].re, r11, 1e-9); cerca(R[0][0].im, i11, 1e-9);
      cerca(R[1][0].re, r21, 1e-9); cerca(R[1][0].im, i21, 1e-9);
      cerca(R[1][1].re, r22, 1e-9); cerca(R[1][1].im, i22, 1e-9);
      const S = V.receptanciaModal(caso[nombre], w);
      for (const [j, k] of [[0, 0], [1, 0], [1, 1], [0, 1]]) {
        cerca(S[j][k].re, R[j][k].re, 1e-7, `modal ${nombre} w=${w}`);
        cerca(S[j][k].im, R[j][k].im, 1e-7, `modal ${nombre} w=${w}`);
      }
    }
  }
  const T = V.receptanciaModalReal(caso.prop, 0.5), R = V.receptanciaMatriz(caso.prop, 0.5);
  cerca(T[0][0].re, R[0][0].re, 1e-9); cerca(T[1][0].im, R[1][0].im, 1e-9);
});

test("el círculo de la receptancia histerética (centro −1/2h, radio 1/2h)", () => {
  const h = 20;
  for (let w = 0.5; w < 60; w += 0.7) {
    const H = V.receptanciaHisteretica(1, 100, h, w);
    cerca(Math.hypot(H.re, H.im + 1 / (2 * h)), 1 / (2 * h), 1e-12);
  }
});

test("la movilidad viscosa describe un círculo exacto (diámetro 1/c)", () => {
  const c = 0.6;
  for (let w = 0.5; w < 60; w += 0.7) {
    const Y = V.movilidad(1, 100, c, w);
    cerca(Math.hypot(Y.re - 1 / (2 * c), Y.im), 1 / (2 * c), 1e-12);
  }
});
