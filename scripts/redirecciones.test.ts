// Ejecutar con el Deno de Quarto:
// deno test --allow-read --allow-write scripts/redirecciones.test.ts
import { strict as assert } from "node:assert";
import { join } from "node:path";
import { escribir, pagina, type Redireccion } from "./redirecciones.ts";

const r: Redireccion = {
  de: "claude/c2-terminal/index.html",
  a: "https://me1catrr.github.io/claudedo/c2-terminal/",
  sitio: "ClaudeDo",
  titulo: "C2 · Preparación del entorno y terminal",
};

Deno.test("la página redirige, conserva el ancla y no se indexa", () => {
  const html = pagina(r);
  assert.match(html, /<meta http-equiv="refresh" content="0; url=https:\/\/me1catrr\.github\.io\/claudedo\/c2-terminal\/">/);
  assert.match(html, /<link rel="canonical" href="https:\/\/me1catrr\.github\.io\/claudedo\/c2-terminal\/">/);
  assert.match(html, /location\.replace\("https:\/\/me1catrr\.github\.io\/claudedo\/c2-terminal\/" \+ location\.hash\)/);
  assert.match(html, /<meta name="robots" content="noindex">/);
  assert.match(html, /<a href="[^"]+">C2 · Preparación del entorno y terminal<\/a>/);
});

Deno.test("escribe las páginas y es idempotente", () => {
  const salida = Deno.makeTempDirSync();
  try {
    assert.equal(escribir(salida, [r]), 1);
    assert.equal(Deno.readTextFileSync(join(salida, r.de)), pagina(r));
    assert.equal(escribir(salida, [r]), 0);
  } finally {
    Deno.removeSync(salida, { recursive: true });
  }
});

Deno.test("no sobrescribe una página real de la web", () => {
  const salida = Deno.makeTempDirSync();
  try {
    Deno.mkdirSync(join(salida, "claude", "c2-terminal"), { recursive: true });
    Deno.writeTextFileSync(join(salida, r.de), "<html>Página real</html>");
    assert.throws(() => escribir(salida, [r]), /no es una redirección/);
    assert.equal(Deno.readTextFileSync(join(salida, r.de)), "<html>Página real</html>");
  } finally {
    Deno.removeSync(salida, { recursive: true });
  }
});

Deno.test("rechaza rutas que salen de la web y destinos que no son https", () => {
  const salida = Deno.makeTempDirSync();
  try {
    assert.throws(() => escribir(salida, [{ ...r, de: "../fuera.html" }]), /no válida/);
    assert.throws(() => escribir(salida, [{ ...r, de: "/abs.html" }]), /no válida/);
    assert.throws(() => escribir(salida, [{ ...r, a: "javascript:alert(1)" }]), /Destino no válido/);
    assert.throws(() => escribir("  ", [r]), /QUARTO_PROJECT_OUTPUT_DIR/);
  } finally {
    Deno.removeSync(salida, { recursive: true });
  }
});
