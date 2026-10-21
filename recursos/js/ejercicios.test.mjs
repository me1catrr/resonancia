// Pruebas de la lógica pura de ejercicios.js. Ejecutar con:
//   deno test --no-check --allow-read recursos/js/ejercicios.test.mjs
import assert from "node:assert/strict";
import test from "node:test";

globalThis.__EJ_TEST__ = true;
await import("./ejercicios.js");
const { parseNumero, parseTolerancia, comprobarNumerico, normalizaVF, mismasOpciones } = globalThis.__EJ_EXPORTS__;

test("parseNumero acepta formatos españoles e ingleses", () => {
  const casos = [
    ["0,0307", 0.0307], ["0.0307", 0.0307], ["3.07e-2", 0.0307], ["3,07e-2", 0.0307],
    ["3,07·10^-2", 0.0307], ["3.07x10^-2", 0.0307], ["3,07×10-2", 0.0307],
    ["30,7 mm", 30.7], ["-0,021933", -0.021933], ["−0,5", -0.5], ["1.234,5", 1234.5], [" 20 ", 20], ["+2", 2],
  ];
  for (const [t, v] of casos) assert.ok(Math.abs(parseNumero(t) - v) < 1e-12, `${t} → ${parseNumero(t)} ≠ ${v}`);
  for (const t of ["", "abc", null, undefined, "—"]) assert.ok(Number.isNaN(parseNumero(t)), String(t));
});

test("tolerancias relativa y absoluta", () => {
  assert.deepEqual(parseTolerancia("1%"), { tipo: "rel", valor: 0.01 });
  assert.deepEqual(parseTolerancia("0.002"), { tipo: "abs", valor: 0.002 });
  assert.deepEqual(parseTolerancia("abs:0.5"), { tipo: "abs", valor: 0.5 });
  assert.deepEqual(parseTolerancia(""), { tipo: "rel", valor: 0.01 });
});

test("comprobarNumerico", () => {
  assert.equal(comprobarNumerico("0,2", 0.2, "1%").ok, true);
  assert.equal(comprobarNumerico("0,201", 0.2, "1%").ok, true);
  assert.equal(comprobarNumerico("0,205", 0.2, "1%").ok, false);
  assert.equal(comprobarNumerico("19,596", "19.5959", "0.5%").ok, true);
  assert.equal(comprobarNumerico("0,0001", 0, "abs:0.001").ok, true);
  assert.equal(comprobarNumerico("hola", 1, "1%").invalida, true);
  assert.equal(comprobarNumerico("-0,0219", -0.021933, "1%").ok, true);
});

test("verdadero/falso y opción múltiple", () => {
  assert.equal(normalizaVF("V"), "verdadero");
  assert.equal(normalizaVF("Falso"), "falso");
  assert.equal(normalizaVF("sí"), "verdadero");
  assert.equal(mismasOpciones("c,a", "a, c"), true);
  assert.equal(mismasOpciones("a", "a,c"), false);
});
