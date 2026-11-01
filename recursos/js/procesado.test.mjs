// Pruebas de procesado.js frente a Julia (mse/m04-senales-ii/referencia/procesado.json,
// generado por scripts/m04/generar_referencia.jl) y frente a identidades.
// Ejecutar con: deno test --no-check --allow-read recursos/js/   (o: node --test recursos/js/)
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import * as P from "./procesado.js";

const ref = JSON.parse(readFileSync(new URL("../../mse/m04-senales-ii/referencia/procesado.json", import.meta.url), "utf8"));

const cerca = (a, b, tol = 1e-10, msg = "") =>
  assert.ok(Math.abs(a - b) <= tol * Math.max(1, Math.abs(b)), `${msg} ${a} ≠ ${b}`);
const vecCerca = (a, b, tol = 1e-10, msg = "") => {
  assert.equal(a.length, b.length, `${msg} longitud`);
  a.forEach((v, i) => cerca(v, b[i], tol, `${msg}[${i}]`));
};
const cxCerca = (a, b, tol = 1e-10, msg = "") => { vecCerca(a.re, b.re, tol, msg + ".re"); vecCerca(a.im, b.im, tol, msg + ".im"); };
const suma = (x) => x.reduce((s, v) => s + v, 0);
const dB = (c, k) => 20 * Math.log10(Math.hypot(c.re[k], c.im[k]));

test("propiedades de las ventanas frente a Julia", () => {
  const r = ref.ventanas, N = r.N;
  for (const nombre of r.nombres) {
    const w = P.ventana(nombre, N), p = r.propiedades[nombre];
    cerca(P.perdidaEscalonamiento(w), p.perdida, 1e-9, nombre + " pérdida");
    cerca(P.anchoBanda3dB(w), p.ancho3db, 1e-9, nombre + " ancho");
    cerca(P.nivelLobuloLateral(w), p.lobulo, 1e-9, nombre + " lóbulo");
    cerca(P.anchoBandaRuido(w), p.enbw, 1e-12, nombre + " ENBW");
    cerca(P.gananciaCoherente(w), p.gcoh, 1e-12, nombre + " ganancia");
  }
  const wh = P.ventana("hann", N), wr = P.ventana("rectangular", N);
  cerca(P.correlacionSolape(wh, 32), r.solape_hann_32, 1e-12);
  cerca(P.correlacionSolape(wr, 32), r.solape_rect_32, 1e-12);
  assert.equal(P.correlacionSolape(wh, 0), r.solape_hann_0);
  assert.equal(P.correlacionSolape(wh, 64), r.solape_hann_64);
  for (const v of r.varianza_welch) {
    const o = P.varianzaWelch(P.ventana(v.nombre, N), v.solape, r.longitud);
    assert.equal(o.K, v.K);
    cerca(o.varianza, v.var, 1e-12, `${v.nombre} ${v.solape}`);
  }
});

test("valores de referencia de las ventanas (compromiso resolución–fuga)", () => {
  const w = (n) => P.ventana(n, 256);
  cerca(P.perdidaEscalonamiento(w("rectangular")), 3.92, 3e-3);
  cerca(P.perdidaEscalonamiento(w("hann")), 1.42, 7e-3);
  assert.ok(P.perdidaEscalonamiento(w("flattop")) < 0.05);
  cerca(P.nivelLobuloLateral(w("hann")), -31.47, 4e-3);
  assert.ok(P.nivelLobuloLateral(w("flattop")) < -80);
  const anchos = ["rectangular", "hann", "blackman", "flattop"].map((n) => P.anchoBanda3dB(w(n)));
  assert.deepEqual(anchos, [...anchos].sort((a, b) => a - b));
});

test("tendencia, remuestreo, integración y SNR frente a Julia", () => {
  const t = ref.tendencia;
  for (const g of ["0", "1", "2"]) {
    const o = P.quitarTendencia(t.x, Number(g));
    vecCerca(o.y, t.resultados[g].y, 1e-9, "y" + g);
    vecCerca(o.tendencia, t.resultados[g].tendencia, 1e-9, "tendencia" + g);
  }
  const i = ref.interpolar, u = P.interpolarUniforme(i.t, i.x, i.fs);
  vecCerca(u.t, i.tu, 1e-12); vecCerca(u.x, i.xu, 1e-12);
  assert.deepEqual(u.hueco, i.hueco);
  const g = ref.integracion;
  vecCerca(P.integrarTrapecio(g.x, g.fs), g.trapecio, 1e-12, "trapecio");
  vecCerca(P.integrarFrecuencia(g.x, g.fs, { fcorte: g.fcorte, orden: 1 }), g.frecuencia1, 1e-9, "orden 1");
  vecCerca(P.integrarFrecuencia(g.x, g.fs, { fcorte: g.fcorte, orden: 2 }), g.frecuencia2, 1e-9, "orden 2");
  const s = ref.snr;
  cerca(P.snrDb(s.x, s.ruido), s.snr_db, 1e-12);
  cerca(P.snrBanda(s.f, s.P, s.Pruido, s.banda), s.snr_banda, 1e-12);
  cerca(P.snrBanda(s.f, s.P, s.Pruido, [0, 10.5]), s.snr_banda_total, 1e-12);
  cerca(P.rmsRuidoBanda(s.densidad, s.fa, s.fb), s.rms_banda, 1e-12);
});

test("espectros cruzados, coherencia, H1 y H2 frente a Julia", () => {
  const r = ref.cruzados, e = P.estimarFrf(r.x, r.y, r.fs, { nseg: r.nseg, solape: r.solape });
  vecCerca(e.f, r.f, 1e-12);
  vecCerca(e.Gxx, r.Gxx, 1e-10, "Gxx"); vecCerca(e.Gyy, r.Gyy, 1e-10, "Gyy");
  cxCerca(e.Gxy, r.Gxy, 1e-9, "Gxy");
  vecCerca(e.coherencia, r.coherencia, 1e-9, "coherencia");
  cxCerca(e.H1, r.H1, 1e-9, "H1"); cxCerca(e.H2, r.H2, 1e-9, "H2");
  // identidad: H1/H2 = γ² (cociente complejo con parte imaginaria nula)
  e.H1.re.forEach((a, k) => {
    const b = e.H1.im[k], c = e.H2.re[k], d = e.H2.im[k], m = c * c + d * d;
    cerca((a * c + b * d) / m, e.coherencia[k], 1e-9, "H1/H2 real");
    assert.ok(Math.abs((b * c - a * d) / m) < 1e-9, "H1/H2 imaginario");
  });
});

test("espectrograma frente a Julia y su promedio es la PSD de Welch", () => {
  const r = ref.espectrograma, e = P.espectrograma(r.x, r.fs, { nseg: r.nseg, solape: r.solape });
  vecCerca(e.t, r.t, 1e-12); vecCerca(e.f, r.f, 1e-12);
  e.P.forEach((fila, k) => vecCerca(fila, r.P[k], 1e-9, `P[${k}]`));
});

test("Butterworth frente a Julia", () => {
  for (const d of ref.filtros.butterworth) {
    const h = P.filtroButterworth(d.orden, d.fc, d.fs, { tipo: d.tipo });
    h.sos.forEach((fila, s) => vecCerca(fila, d.sos[s], 1e-10, `${d.tipo} sos[${s}]`));
    assert.equal(h.sos.length, d.sos.length);
    cxCerca(P.respuestaFrecuencia(h, d.f, d.fs), d.H, 1e-10, d.tipo);
    vecCerca(P.retardoGrupo(h, d.f_retardo, d.fs), d.retardo, 1e-8, d.tipo + " retardo");
  }
});

test("FIR frente a Julia", () => {
  for (const d of ref.filtros.fir) {
    const h = P.filtroFir(d.ntaps, d.fc, d.fs, { tipo: d.tipo, ventana: d.ventana });
    vecCerca(h.b, d.b, 1e-12, d.tipo);
    cxCerca(P.respuestaFrecuencia(h, d.f, d.fs), d.H, 1e-11, d.tipo);
    cerca(P.retardoGrupo(h, 5, d.fs), d.retardo, 1e-9, d.tipo + " retardo");
  }
});

test("filtrado causal, de fase cero y diezmado frente a Julia", () => {
  const r = ref.filtros, lp = P.filtroButterworth(3, 10, 100), hp = P.filtroFir(21, 10, 100);
  vecCerca(P.filtrar(lp, r.x), r.iir_causal, 1e-10, "iir causal");
  vecCerca(P.filtrarFaseCero(lp, r.x), r.iir_fase_cero, 1e-9, "iir fase cero");
  vecCerca(P.filtrar(hp, r.x), r.fir_causal, 1e-10, "fir causal");
  vecCerca(P.filtrar(hp, r.x, { compensar: true }), r.fir_compensado, 1e-10, "fir compensado");
  vecCerca(P.filtrarFaseCero(hp, r.x), r.fir_fase_cero, 1e-9, "fir fase cero");
  vecCerca(P.diezmar(r.x_diezmar, r.diezmar_q), r.diezmado, 1e-10, "diezmado");
});

test("paso alto de la Tabla 6.1 del capítulo de filtrado de NeuroMIND", () => {
  const h = P.filtroButterworth(4, 0.5, 500, { tipo: "pasaaltos" }), f = [0.1, 0.25, 0.5, 1, 2, 5];
  const H = P.respuestaFrecuencia(h, f, 500);
  [-55.92, -24.10, -3.01, -0.02, 0, 0].forEach((v, k) => assert.ok(Math.abs(dB(H, k) - v) < 0.006, `ganancia ${f[k]} Hz`));
  [-111.84, -48.20, -6.02, -0.03, 0, 0].forEach((v, k) => assert.ok(Math.abs(2 * dB(H, k) - v) < 0.012, `doble pasada ${f[k]} Hz`));
  const fase = (k) => (Math.atan2(H.im[k], H.re[k]) * 180) / Math.PI;
  [[0, -30.1], [1, -78.0], [3, 78.0], [4, 37.8], [5, 15.0]].forEach(([k, v]) => assert.ok(Math.abs(fase(k) - v) < 0.05, `fase ${f[k]} Hz`));
  assert.ok(Math.abs(Math.abs(fase(2)) - 180) < 0.06);
});

test("fase cero: ganancia |H|², corte efectivo y ausencia de retardo", () => {
  const fs = 100, lp = P.filtroButterworth(4, 2, fs);
  const H2 = (f) => { const H = P.respuestaFrecuencia(lp, f, fs); return H.re[0] ** 2 + H.im[0] ** 2; };
  cerca(10 * Math.log10(H2(2) ** 2), -6.0206, 2e-4);            // |H|² en dB: −6,02 en fc
  const f3 = (fs / Math.PI) * Math.atan((Math.SQRT2 - 1) ** (1 / 8) * Math.tan((Math.PI * 2) / fs));
  cerca(H2(f3), 1 / Math.SQRT2, 1e-9);                          // el −3 dB baja a (√2−1)^(1/2N)·fc
  assert.ok(f3 < 2);
  // retardo de la sinusoide de 1,1 Hz: por correlación, positivo con `filtrar` y nulo con fase cero
  const s = Array.from({ length: 3000 }, (_, n) => Math.sin((2 * Math.PI * 1.1 * n) / fs));
  const retraso = (u, v) => {
    let mejor = 0, lag = 0;
    for (let k = -100; k <= 100; k++) {
      let c = 0;
      for (let n = Math.max(0, -k); n < Math.min(u.length, u.length - k); n++) c += u[n] * v[n + k];
      if (c > mejor) { mejor = c; lag = k; }
    }
    return lag;
  };
  assert.ok(retraso(s, P.filtrar(lp, s)) > 0);
  assert.equal(retraso(s, P.filtrarFaseCero(lp, s)), 0);
});

test("integración: velocidad y desplazamiento exactos; el offset se descarta", () => {
  const fs = 100, f0 = 5, w = 2 * Math.PI * f0, t = Array.from({ length: 1000 }, (_, n) => n / fs);
  const x = t.map((v) => Math.cos(w * v));
  vecCerca(P.integrarFrecuencia(x.map((v) => v + 0.3), fs, { fcorte: 1, orden: 1 }), t.map((v) => Math.sin(w * v) / w), 1e-9);
  vecCerca(P.integrarFrecuencia(x, fs, { fcorte: 1, orden: 2 }), t.map((v) => -Math.cos(w * v) / (w * w)), 1e-9);
  cerca(P.integrarTrapecio(new Array(1000).fill(0.2), fs)[999], (0.2 * 999) / fs, 1e-12);   // rampa c·t
});

test("diezmar evita el aliasing", () => {
  const fs = 100, N = 4000, rms = (v) => Math.sqrt(suma(v.map((a) => a * a)) / v.length);
  const alias = Array.from({ length: N }, (_, n) => Math.sin((2 * Math.PI * 40 * n) / fs));
  cerca(rms(alias.filter((_, i) => i % 4 === 0)), 1 / Math.SQRT2, 0.01);      // sin filtrar se pliega entero
  assert.ok(rms(P.diezmar(alias, 4).slice(100, 900)) < 0.01);
  assert.equal(P.diezmar(alias, 4).length, 1000);
});

test("errores", () => {
  assert.throws(() => P.filtroButterworth(0, 10, 100));
  assert.throws(() => P.filtroButterworth(2, 60, 100));
  assert.throws(() => P.filtroButterworth(2, 10, 100, { tipo: "pasabanda" }));
  assert.throws(() => P.filtroFir(100, 10, 100, { tipo: "pasaaltos" }));
  assert.throws(() => P.integrarFrecuencia(new Array(8).fill(1), 10, { fcorte: 1, orden: 3 }));
  assert.throws(() => P.espectrosCruzados(new Array(100).fill(1), new Array(99).fill(1), 10));
  assert.throws(() => P.varianzaWelch(P.ventana("hann", 8), 1, 64));
  assert.throws(() => P.interpolarUniforme([0, 1, 1], [1, 2, 3], 1));
});
