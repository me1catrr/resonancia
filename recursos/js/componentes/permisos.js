// Evaluador didáctico de reglas de permisos de Claude Code (solo reglas Bash).
// Uso en una celda OJS:
//   import {evaluar, REGLAS_EJEMPLO} from "../../recursos/js/componentes/permisos.js"
//   evaluar(REGLAS_EJEMPLO, "git push origin main")
//
// MODELO SIMPLIFICADO, solo para enseñar el orden deny → ask → allow. Lo que SÍ imita (según la
// documentación consultada el 23-10-2026): el orden de evaluación, el comodín `*`, que un `*` final
// tras un espacio también casa con la orden sin argumentos, el troceo de órdenes compuestas
// (&&, ||, ;, |: deny y ask casan si lo hace cualquier parte; allow exige que casen todas) y el
// descarte de los envoltorios timeout, time, nice, nohup y stdbuf. Lo que NO modela: reglas de
// otras herramientas (Read, Edit, WebFetch…), redirecciones, el clasificador del modo auto ni
// las comprobaciones de rutas. Las reglas reales de Bash que limitan argumentos son frágiles.

export const REGLAS_EJEMPLO = {
  allow: ["git status *", "git diff *", "git log *", "git add *", "git commit *", "julia --project=. *", "quarto render *", "uv run *"],
  ask: ["git push *", "git restore *", "git reset --hard*", "git clean *", "git rebase *", "uv add *", "gh pr *"],
  deny: ["rm -rf *", "*datos/privados*"],
};

const ENVOLTORIOS = new Set(["timeout", "time", "nice", "nohup", "stdbuf"]);

/** Convierte un patrón con `*` en una expresión regular anclada. */
export function patronARegex(patron) {
  let p = String(patron).trim();
  p = p.replace(/:\*$/, " *"); // `ls:*` equivale a `ls *`
  const colaOpcional = / \*$/.test(p);
  if (colaOpcional) p = p.slice(0, -2);
  const cuerpo = p.split("*").map((t) => t.replace(/[.+?^${}()|[\]\\]/g, "\\$&")).join(".*");
  return new RegExp("^" + cuerpo + (colaOpcional ? "( .*)?" : "") + "$");
}

/** Quita envoltorios iniciales (`timeout 30 npm test` → `npm test`). Aproximado. */
export function quitarEnvoltorios(orden) {
  const t = orden.trim().split(/\s+/);
  while (t.length && ENVOLTORIOS.has(t[0])) {
    t.shift();
    if (t[0] && /^[\d.]+[smhd]?$/.test(t[0])) t.shift(); // duración de timeout
  }
  return t.join(" ");
}

/** Divide una orden compuesta en sus partes. */
export function partes(orden) {
  return orden.split(/&&|\|\||;|\|/).map((s) => s.trim()).filter(Boolean);
}

function primeraCoincidencia(lista, candidatos) {
  for (const patron of lista) {
    const re = patronARegex(patron);
    if (candidatos.some((c) => re.test(c))) return patron;
  }
  return null;
}

/**
 * Evalúa una orden contra las reglas. Devuelve {decision, regla, motivo}:
 * decision ∈ "deny" | "ask" | "allow" | "ask-por-defecto".
 */
export function evaluar(reglas, orden) {
  const entera = orden.trim();
  if (!entera) return { decision: "ask-por-defecto", regla: null, motivo: "Orden vacía." };
  const trozos = partes(entera).map(quitarEnvoltorios);
  const candidatos = [quitarEnvoltorios(entera), ...trozos];

  const d = primeraCoincidencia(reglas.deny ?? [], candidatos);
  if (d) return { decision: "deny", regla: d, motivo: "Una regla deny casa: se bloquea sin preguntar." };
  const a = primeraCoincidencia(reglas.ask ?? [], candidatos);
  if (a) return { decision: "ask", regla: a, motivo: "Una regla ask casa: Claude Code te pregunta antes." };

  const permitidas = trozos.map((t) => primeraCoincidencia(reglas.allow ?? [], [t]));
  if (trozos.length > 0 && permitidas.every(Boolean)) {
    return { decision: "allow", regla: permitidas[0], motivo: trozos.length > 1 ? "Casan con allow todas las partes de la orden." : "Una regla allow casa: se ejecuta sin preguntar." };
  }
  return { decision: "ask-por-defecto", regla: null, motivo: "Ninguna regla casa del todo: en modo normal pregunta (salvo órdenes de solo lectura integradas)." };
}
