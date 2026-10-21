// Barrera de publicación: los apuntes locales no deben estar en la salida web.
// Quarto ejecuta este script con su Deno integrado tras cada render.
import { join, resolve } from "node:path";

export function comprobarSalida(salida: string): void {
  if (!salida.trim()) {
    throw new Error("Falta QUARTO_PROJECT_OUTPUT_DIR; no se puede comprobar la salida web.");
  }
  const docs = join(resolve(salida), "docs");
  try {
    Deno.lstatSync(docs);
  } catch (error) {
    if (error instanceof Deno.errors.NotFound) return;
    throw error;
  }
  throw new Error(
    "Publicación bloqueada: existe docs/ en la salida web. " +
      "Retira los enlaces o recursos de apuntes locales y vuelve a compilar. " +
      "No se ha borrado ningún documento.",
  );
}

if (import.meta.main) {
  comprobarSalida(Deno.env.get("QUARTO_PROJECT_OUTPUT_DIR") ?? "");
}
