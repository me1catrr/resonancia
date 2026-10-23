// Línea temporal filtrable y accesible. Sin dependencias externas.
// Uso en una celda OJS:
//   import {lineaTemporal} from "../../recursos/js/componentes/linea-temporal.js"
//   import {hitos} from "./hitos.js"
//   lineaTemporal(hitos)
// Cada hito: {anio, categoria, titulo, texto, fuente: {texto, url}, secundaria?}.

const CAMPOS = ["anio", "categoria", "titulo", "texto", "fuente"];

/** Devuelve una lista de errores (vacía si los hitos son válidos). */
export function validarHitos(hitos) {
  const errores = [];
  if (!Array.isArray(hitos) || hitos.length === 0) return ["no hay hitos"];
  hitos.forEach((h, i) => {
    const nombre = `hito ${i + 1} (${h?.titulo ?? "sin título"})`;
    for (const c of CAMPOS) if (h?.[c] === undefined || h[c] === "") errores.push(`${nombre}: falta ${c}`);
    if (h && !Number.isInteger(h.anio)) errores.push(`${nombre}: el año no es un entero`);
    if (h?.fuente && !/^https:\/\//.test(h.fuente.url ?? "")) errores.push(`${nombre}: la fuente no tiene URL https`);
    if (h?.fuente && !h.fuente.texto) errores.push(`${nombre}: la fuente no tiene texto`);
  });
  return errores;
}

/** Categorías en orden de primera aparición. */
export function categorias(hitos) {
  return [...new Set(hitos.map((h) => h.categoria))];
}

/** Hitos de una categoría (o todos si es null), ordenados por año de forma estable. */
export function filtrarHitos(hitos, categoria = null) {
  return hitos
    .map((h, i) => [h, i])
    .filter(([h]) => categoria === null || h.categoria === categoria)
    .sort((a, b) => a[0].anio - b[0].anio || a[1] - b[1])
    .map(([h]) => h);
}

/** Construye el componente. `doc` permite probarlo sin navegador. */
export function lineaTemporal(hitos, { doc = globalThis.document, titulo = "Línea temporal" } = {}) {
  const errores = validarHitos(hitos);
  const raiz = doc.createElement("div");
  raiz.className = "linea-temporal";
  if (errores.length) {
    raiz.textContent = "Línea temporal no disponible: " + errores.join("; ");
    return raiz;
  }

  const filtros = doc.createElement("div");
  filtros.className = "lt-filtros";
  filtros.setAttribute("role", "group");
  filtros.setAttribute("aria-label", `${titulo}: filtrar por tema`);

  const aviso = doc.createElement("p");
  aviso.className = "lt-aviso";
  aviso.setAttribute("aria-live", "polite");

  const lista = doc.createElement("ol");
  lista.className = "lt-lista";
  const ordenados = filtrarHitos(hitos);
  const items = ordenados.map((h) => {
    const li = doc.createElement("li");
    li.className = "lt-hito";
    li.dataset.categoria = h.categoria;
    const anio = doc.createElement("span");
    anio.className = "lt-anio";
    anio.textContent = String(h.anio);
    const cat = doc.createElement("span");
    cat.className = "lt-categoria";
    cat.textContent = h.categoria;
    const tit = doc.createElement("strong");
    tit.className = "lt-titulo";
    tit.textContent = h.titulo;
    const txt = doc.createElement("p");
    txt.textContent = h.texto;
    const enlace = doc.createElement("a");
    enlace.setAttribute("href", h.fuente.url);
    enlace.textContent = "Fuente: " + h.fuente.texto + (h.secundaria ? " (fuente secundaria)" : "");
    const pie = doc.createElement("p");
    pie.className = "lt-fuente";
    pie.append(enlace);
    li.append(anio, cat, tit, txt, pie);
    lista.append(li);
    return [h, li];
  });

  const botones = [];
  const aplicar = (categoria) => {
    let n = 0;
    for (const [h, li] of items) {
      li.hidden = !(categoria === null || h.categoria === categoria);
      if (!li.hidden) n++;
    }
    for (const [b, c] of botones) b.setAttribute("aria-pressed", String(c === categoria));
    aviso.textContent = `${n} de ${items.length} hitos` + (categoria ? ` · ${categoria}` : "");
  };
  for (const c of [null, ...categorias(ordenados)]) {
    const b = doc.createElement("button");
    b.setAttribute("type", "button");
    b.className = "lt-boton";
    b.textContent = c ?? "Todos";
    b.addEventListener("click", () => aplicar(c));
    filtros.append(b);
    botones.push([b, c]);
  }

  raiz.append(filtros, aviso, lista);
  aplicar(null);
  return raiz;
}
