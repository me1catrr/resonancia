// Redirecciones de las URL antiguas de las vías J y C (hasta noviembre de 2026
// en julia/ y claude/) a JuliaDo y ClaudeDo. Quarto ejecuta este script con su
// Deno integrado tras cada render. La lista está en _redirecciones.json, que
// genera scripts/generar_redirecciones.jl a partir de temario.yml.
import { dirname, join, resolve } from "node:path";

export interface Redireccion {
  de: string;
  a: string;
  sitio: string;
  titulo: string;
}

const escapar = (s: string): string =>
  s.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");

export function pagina(r: Redireccion): string {
  const a = escapar(r.a);
  return `<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapar(r.titulo)} · ahora en ${escapar(r.sitio)}</title>
<meta name="robots" content="noindex">
<link rel="canonical" href="${a}">
<meta http-equiv="refresh" content="0; url=${a}">
<script>location.replace(${JSON.stringify(r.a)} + location.hash);</script>
</head>
<body>
<p>Esta página se ha trasladado a ${escapar(r.sitio)}:
<a href="${a}">${escapar(r.titulo)}</a>.</p>
</body>
</html>
`;
}

// Escribe las páginas en la salida web. No sobrescribe páginas reales de Resonancia.
export function escribir(salida: string, lista: Redireccion[]): number {
  if (!salida.trim()) {
    throw new Error("Falta QUARTO_PROJECT_OUTPUT_DIR; no se pueden escribir las redirecciones.");
  }
  const base = resolve(salida);
  let n = 0;
  for (const r of lista) {
    if (r.de.startsWith("/") || r.de.split("/").includes("..")) {
      throw new Error(`Ruta de redirección no válida: ${r.de}`);
    }
    if (!/^https:\/\//.test(r.a)) throw new Error(`Destino no válido: ${r.a}`);
    const destino = join(base, r.de);
    const texto = pagina(r);
    try {
      const actual = Deno.readTextFileSync(destino);
      if (actual === texto) continue;
      if (!actual.includes('<meta http-equiv="refresh"')) {
        throw new Error(`${r.de} ya existe en la salida web y no es una redirección.`);
      }
    } catch (error) {
      if (!(error instanceof Deno.errors.NotFound)) throw error;
    }
    Deno.mkdirSync(dirname(destino), { recursive: true });
    Deno.writeTextFileSync(destino, texto);
    n++;
  }
  return n;
}

if (import.meta.main) {
  const lista = JSON.parse(
    Deno.readTextFileSync(new URL("../_redirecciones.json", import.meta.url)),
  ) as Redireccion[];
  escribir(Deno.env.get("QUARTO_PROJECT_OUTPUT_DIR") ?? "", lista);
}
