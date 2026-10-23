// Pruebas de la línea temporal y de los datos de C0.
//   deno test --no-check --allow-read recursos/js/
import assert from "node:assert/strict";
import test from "node:test";
import { validarHitos, categorias, filtrarHitos, lineaTemporal } from "./linea-temporal.js";
import { hitos } from "../../../claude/c0-fluidez/hitos.js";

// DOM mínimo: solo lo que usa el componente.
class Nodo {
  constructor(tag) { this.tag = tag; this.hijos = []; this.attrs = {}; this.dataset = {}; this.hidden = false; this._texto = ""; this.oyentes = {}; this.className = ""; }
  setAttribute(k, v) { this.attrs[k] = String(v); }
  getAttribute(k) { return this.attrs[k] ?? null; }
  append(...xs) { this.hijos.push(...xs); }
  addEventListener(t, f) { (this.oyentes[t] ||= []).push(f); }
  click() { (this.oyentes.click || []).forEach((f) => f({})); }
  get textContent() { return this._texto + this.hijos.map((h) => h.textContent).join(""); }
  set textContent(v) { this.hijos = []; this._texto = String(v); }
  todos() { return this.hijos.flatMap((h) => [h, ...h.todos()]); }
}
const doc = { createElement: (t) => new Nodo(t) };

const ejemplo = [
  { anio: 2017, categoria: "B", titulo: "b1", texto: "t", fuente: { texto: "f", url: "https://x.org" } },
  { anio: 1950, categoria: "A", titulo: "a1", texto: "t", fuente: { texto: "f", url: "https://x.org" } },
  { anio: 2017, categoria: "A", titulo: "a2", texto: "t", fuente: { texto: "f", url: "https://x.org" } },
];

test("los hitos de C0 son válidos y todos tienen fuente https", () => {
  assert.deepEqual(validarHitos(hitos), []);
});

test("los hitos de C0 no se salen del intervalo esperado", () => {
  for (const h of hitos) assert.ok(h.anio >= 1940 && h.anio <= 2026, h.titulo);
});

test("validarHitos detecta campos ausentes y URL no seguras", () => {
  const malos = [{ anio: 1950.5, categoria: "A", titulo: "x", texto: "", fuente: { texto: "f", url: "http://x" } }];
  const e = validarHitos(malos);
  assert.ok(e.some((m) => m.includes("falta texto")));
  assert.ok(e.some((m) => m.includes("entero")));
  assert.ok(e.some((m) => m.includes("https")));
  assert.deepEqual(validarHitos([]), ["no hay hitos"]);
});

test("filtrarHitos ordena por año de forma estable y filtra por categoría", () => {
  assert.deepEqual(filtrarHitos(ejemplo).map((h) => h.titulo), ["a1", "b1", "a2"]);
  assert.deepEqual(filtrarHitos(ejemplo, "A").map((h) => h.titulo), ["a1", "a2"]);
  assert.deepEqual(categorias(ejemplo), ["B", "A"]);
});

test("el componente pinta todos los hitos y filtra con los botones", () => {
  const raiz = lineaTemporal(ejemplo, { doc });
  const nodos = raiz.todos();
  const items = nodos.filter((n) => n.className === "lt-hito");
  const botones = nodos.filter((n) => n.tag === "button");
  const aviso = nodos.find((n) => n.className === "lt-aviso");
  assert.equal(items.length, 3);
  assert.deepEqual(botones.map((b) => b.textContent), ["Todos", "A", "B"]);
  assert.equal(aviso.textContent, "3 de 3 hitos");
  assert.equal(botones[0].getAttribute("aria-pressed"), "true");

  botones[2].click(); // B
  assert.deepEqual(items.map((i) => i.hidden), items.map((i) => i.dataset.categoria !== "B"));
  assert.equal(items.filter((i) => !i.hidden).length, 1);
  assert.equal(aviso.textContent, "1 de 3 hitos · B");
  assert.equal(botones[2].getAttribute("aria-pressed"), "true");
  assert.equal(botones[0].getAttribute("aria-pressed"), "false");

  botones[0].click();
  assert.ok(items.every((i) => !i.hidden));
});

test("con datos inválidos muestra un aviso en lugar de fallar", () => {
  const raiz = lineaTemporal([], { doc });
  assert.match(raiz.textContent, /no disponible/);
});
