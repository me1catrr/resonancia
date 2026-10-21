// Ejecutar con el Deno de Quarto:
// deno test --allow-read --allow-write scripts/no_publicar_docs.test.ts
import { strict as assert } from "node:assert";
import { join } from "node:path";
import { comprobarSalida } from "./no_publicar_docs.ts";

Deno.test("permite una salida sin docs y no modifica otros recursos", () => {
  const salida = Deno.makeTempDirSync();
  try {
    Deno.writeTextFileSync(join(salida, "index.html"), "Página pública");
    comprobarSalida(salida);
    assert.equal(Deno.readTextFileSync(join(salida, "index.html")), "Página pública");
  } finally {
    Deno.removeSync(salida, { recursive: true });
  }
});

Deno.test("bloquea docs con PDF sin leer ni borrar el documento", () => {
  const salida = Deno.makeTempDirSync();
  try {
    const docs = join(salida, "docs", "tema");
    Deno.mkdirSync(docs, { recursive: true });
    const pdf = join(docs, "prueba.pdf");
    Deno.writeTextFileSync(pdf, "%PDF-1.4\n%%EOF\n");
    assert.throws(() => comprobarSalida(salida), /Publicación bloqueada/);
    assert.equal(Deno.readTextFileSync(pdf), "%PDF-1.4\n%%EOF\n");
  } finally {
    Deno.removeSync(salida, { recursive: true });
  }
});

Deno.test("bloquea también una carpeta docs vacía o un archivo llamado docs", () => {
  const salida = Deno.makeTempDirSync();
  try {
    const docs = join(salida, "docs");
    Deno.mkdirSync(docs);
    assert.throws(() => comprobarSalida(salida), /Publicación bloqueada/);
    Deno.removeSync(docs);
    Deno.writeTextFileSync(docs, "No publicar");
    assert.throws(() => comprobarSalida(salida), /Publicación bloqueada/);
  } finally {
    Deno.removeSync(salida, { recursive: true });
  }
});

Deno.test("falla si no se conoce el directorio de salida", () => {
  assert.throws(() => comprobarSalida(""), /QUARTO_PROJECT_OUTPUT_DIR/);
});
