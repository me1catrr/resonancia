// Prueba de humo de la capa DOM de ejercicios.js con un DOM mínimo (sin navegador).
// Construye ejercicios con la misma estructura que genera Pandoc y simula clics.
//   deno test --no-check --allow-read recursos/js/ejercicios.dom.test.mjs
import assert from "node:assert/strict";
import test from "node:test";

/* ---------------- DOM mínimo ---------------- */
class Nodo {
  constructor(tag) { this.tag = tag; this.hijos = []; this.padre = null; this.attrs = {}; this.clases = new Set(); this.oyentes = {}; this._texto = ""; this.checked = false; this.value = ""; this.hidden = false; this.dataset = {}; }
  get className() { return [...this.clases].join(" "); }
  set className(v) { this.clases = new Set(String(v).split(/\s+/).filter(Boolean)); }
  get classList() { const c = this.clases; return { add: (x) => c.add(x), remove: (x) => c.delete(x), contains: (x) => c.has(x) }; }
  get id() { return this.attrs.id || ""; } set id(v) { this.attrs.id = v; }
  get type() { return this.attrs.type; }
  setAttribute(k, v) { this.attrs[k] = String(v); if (k === "value") this.value = String(v); if (k.startsWith("data-")) this.dataset[k.slice(5)] = String(v); }
  get textContent() { return this._texto + this.hijos.map((h) => (typeof h === "string" ? h : h.textContent)).join(""); }
  set textContent(v) { this.hijos = []; this._texto = String(v); }
  get firstChild() { return this.hijos[0] || null; }
  append(...xs) { xs.forEach((x) => { if (x.padre) x.padre.hijos = x.padre.hijos.filter((h) => h !== x); if (typeof x !== "string") x.padre = this; this.hijos.push(x); }); }
  prepend(x) { if (x.padre) x.padre.hijos = x.padre.hijos.filter((h) => h !== x); x.padre = this; this.hijos.unshift(x); }
  before(x) { const p = this.padre; if (x.padre) x.padre.hijos = x.padre.hijos.filter((h) => h !== x); x.padre = p; p.hijos.splice(p.hijos.indexOf(this), 0, x); }
  remove() { if (this.padre) this.padre.hijos = this.padre.hijos.filter((h) => h !== this); this.padre = null; }
  addEventListener(t, f) { (this.oyentes[t] ||= []).push(f); }
  click() { if (this.attrs.type === "radio") { this.padre && this.raiz().todos().filter((n) => n.attrs.name === this.attrs.name).forEach((n) => (n.checked = false)); this.checked = true; } else if (this.attrs.type === "checkbox") this.checked = !this.checked; (this.oyentes.click || []).forEach((f) => f({})); (this.oyentes.change || []).forEach((f) => f({})); }
  raiz() { let n = this; while (n.padre) n = n.padre; return n; }
  todos() { return this.hijos.flatMap((h) => (typeof h === "string" ? [] : [h, ...h.todos()])); }
  coincide(sel) {
    return sel.split(/(?=[.\[:])/).filter(Boolean).every((p) => {
      if (p.startsWith(".")) return this.clases.has(p.slice(1));
      if (p === ":checked") return this.checked;
      const m = p.match(/^\[(\w+)=["']?([^"'\]]*)["']?\]$/);
      if (m) return (m[1] === "type" ? this.attrs.type : m[1] === "value" ? this.value : this.attrs[m[1]]) === m[2];
      return this.tag === p;
    });
  }
  querySelectorAll(sel) {
    return sel.split(",").map((s) => s.trim()).flatMap((s) => {
      const solo = s.startsWith(":scope >");
      const partes = s.replace(":scope >", "").trim().split(/\s*>\s*/).map((x) => x.trim());
      let actuales = [this];
      partes.forEach((p, i) => {
        const hijo = solo || i > 0;
        actuales = actuales.flatMap((n) => (hijo ? n.hijos.filter((h) => typeof h !== "string") : n.todos())).filter((n) => n.coincide(p));
      });
      return actuales;
    });
  }
  querySelector(sel) { return this.querySelectorAll(sel)[0] || null; }
}
const raiz = new Nodo("body");
globalThis.document = {
  readyState: "complete", body: raiz,
  createElement: (t) => new Nodo(t),
  querySelectorAll: (s) => raiz.querySelectorAll(s),
  querySelector: (s) => raiz.querySelector(s),
  addEventListener() {},
};
globalThis.location = { pathname: "/prueba/" };
const almacen = new Map();
const falso = {};
Object.defineProperty(falso, "getItem", { value: (k) => (almacen.has(k) ? almacen.get(k) : null) });
Object.defineProperty(falso, "setItem", { value: (k, v) => { almacen.set(k, String(v)); } });
Object.defineProperty(falso, "removeItem", { value: (k) => { almacen.delete(k); } });
const proxy = new Proxy(falso, { ownKeys: () => [...almacen.keys()], getOwnPropertyDescriptor: () => ({ enumerable: true, configurable: true }) });
Object.defineProperty(globalThis, "localStorage", { value: proxy, configurable: true });
globalThis.confirm = () => true;

/* ---------------- Utilidades de construcción ---------------- */
function div(clases, attrs = {}, texto = "") {
  const d = new Nodo("div"); d.className = clases; Object.entries(attrs).forEach(([k, v]) => d.setAttribute(k, v)); if (texto) d.textContent = texto; return d;
}
function lista(items) { const ul = new Nodo("ul"); items.forEach((t) => { const li = new Nodo("li"); li.textContent = t; ul.append(li); }); return ul; }
function ejercicio(tipo, id, datos, hijos = []) {
  const e = div("ejercicio", { id, "data-tipo": tipo, ...datos });
  hijos.forEach((h) => e.append(h)); return e;
}
function cajaConLista(clase, items) { const d = div(clase); d.append(lista(items)); return d; }

const h2 = new Nodo("h2"); h2.textContent = "Objetivos"; raiz.append(h2);
const vf = ejercicio("vf", "t-vf", { "data-respuesta": "falso" }, [div("solucion", {}, "Falso porque…")]);
const op = ejercicio("opcion", "t-op", { "data-respuesta": "b" }, [cajaConLista("opciones", ["3", "6", "9"]), div("solucion", {}, "La b")]);
const nu = ejercicio("numerico", "t-nu", { "data-respuesta": "0.2", "data-tol": "1%", "data-unidad": "" }, [div("pista", {}, "c/cc"), div("solucion", {}, "0,2")]);
const ab = ejercicio("abierta", "t-ab", {}, [cajaConLista("rubrica", ["a", "b"]), div("solucion", {}, "modelo")]);
const en = ejercicio("encuesta", "t-en", {}, [cajaConLista("opciones", ["Sí", "No"])]);
[vf, op, nu, ab, en].forEach((e) => raiz.append(e));

await import("./ejercicios.js");

const boton = (ej, texto) => ej.todos().find((n) => n.tag === "button" && n.textContent === texto);
const feedback = (ej) => ej.querySelector(".ej-feedback");

test("se activan todas las tarjetas y aparece el panel de progreso", () => {
  for (const e of [vf, op, nu, ab, en]) assert.ok(e.clases.has("ej-activo"), e.id);
  assert.ok(raiz.querySelector(".ej-progreso"));
  assert.match(raiz.querySelector(".ej-resumen").textContent, /0 de 4 ejercicios resueltos/);
});

test("las soluciones y pistas quedan ocultas hasta pedirlas", () => {
  assert.equal(vf.querySelector(".solucion").hidden, true);
  assert.equal(nu.querySelector(".pista").hidden, true);
  boton(nu, "Pista").click();
  assert.equal(nu.querySelector(".pista").hidden, false);
});

test("verdadero/falso: error y acierto", () => {
  const [rv, rf] = vf.querySelectorAll("input");
  rv.click(); boton(vf, "Comprobar").click();
  assert.match(feedback(vf).textContent, /No es correcto/);
  rf.click(); boton(vf, "Comprobar").click();
  assert.match(feedback(vf).textContent, /Correcto/);
  assert.equal(vf.dataset.estado, "correcto");
  assert.equal(vf.querySelector(".solucion").hidden, false);
});

test("opción única", () => {
  const radios = op.querySelectorAll("input");
  assert.equal(radios.length, 3);
  radios[0].click(); boton(op, "Comprobar").click();
  assert.match(feedback(op).textContent, /No es correcto/);
  radios[1].click(); boton(op, "Comprobar").click();
  assert.equal(op.dataset.estado, "correcto");
});

test("numérico con coma decimal y tolerancia", () => {
  const entrada = nu.querySelector("input");
  entrada.value = "0,3"; boton(nu, "Comprobar").click();
  assert.match(feedback(nu).textContent, /Aún no/);
  entrada.value = "0,2"; boton(nu, "Comprobar").click();
  assert.equal(nu.dataset.estado, "correcto");
});

test("abierta: exige marcar la rúbrica y luego queda hecha", () => {
  boton(ab, "He terminado").click();
  assert.match(feedback(ab).textContent, /Marca todos/);
  ab.querySelectorAll("input").forEach((i) => i.click());
  boton(ab, "He terminado").click();
  assert.equal(ab.dataset.estado, "hecho");
});

test("encuesta: se guarda y no cuenta para el progreso", () => {
  en.querySelectorAll("input")[0].click();
  boton(en, "Guardar").click();
  assert.equal(en.dataset.estado, "enviado");
  assert.match(raiz.querySelector(".ej-resumen").textContent, /4 de 4 ejercicios resueltos/);
});

test("el estado se guardó en el almacenamiento local y Reiniciar lo borra", () => {
  assert.ok([...almacen.keys()].some((k) => k.endsWith(":t-vf")));
  boton(vf, "Reiniciar").click();
  assert.equal(vf.dataset.estado, "pendiente");
  assert.equal(vf.querySelector(".solucion").hidden, true);
  assert.match(raiz.querySelector(".ej-resumen").textContent, /3 de 4/);
});
