/* =============================================================================
 * ejercicios.js: ejercicios intercalados en el texto (autoevaluación)
 *
 * Lo inserta scripts/ejercicios.lua, en línea, solo en las páginas que tienen
 * ejercicios. Sin dependencias. Todo ocurre en el navegador: las respuestas y
 * el progreso se guardan en localStorage (nada sale del equipo del alumnado).
 *
 * Se escribe en Markdown (véase la guía en CLAUDE.md):
 *   ::: {.ejercicio tipo="numerico" id="m5-2-zeta" respuesta="0.2" tol="1%" unidad=""}
 *   Enunciado…
 *   ::: {.pista}  …  :::
 *   ::: {.solucion}  …  :::
 *   :::
 * Tipos: vf, opcion, numerico, abierta, programacion, investigacion, encuesta.
 *
 * La lógica de corrección (parseNumero, comprobarNumerico, …) es pura y se
 * prueba con recursos/js/ejercicios.test.mjs.
 * ========================================================================== */
(function () {
  "use strict";

  /* ------------------------------------------------------------------ */
  /* Lógica pura                                                         */
  /* ------------------------------------------------------------------ */

  /** Lee un número escrito a la española o a la inglesa: «0,0307», «3.07e-2»,
   *  «3,07·10^-2», «30,7 mm» (se ignora lo que siga al número). NaN si no hay. */
  function parseNumero(texto) {
    if (texto === null || texto === undefined) return NaN;
    let t = String(texto).trim().replace(/−/g, "-").replace(/\s+/g, "");
    // 3,07·10^-2 · 3.07x10^-2 · 3,07×10-2  →  3.07e-2
    t = t.replace(/[x×·*]10\^?\(?(-?\+?\d+)\)?/gi, "e$1");
    if (t.includes(",")) t = t.replace(/\./g, "").replace(",", ".");
    const m = t.match(/^[+-]?(\d+(\.\d*)?|\.\d+)(e[+-]?\d+)?/i);
    return m ? parseFloat(m[0]) : NaN;
  }

  /** Interpreta la tolerancia: «1%» (relativa), «0.01» o «abs:0.01» (absoluta). */
  function parseTolerancia(tol) {
    const t = String(tol === undefined || tol === null || tol === "" ? "1%" : tol).trim();
    if (t.endsWith("%")) return { tipo: "rel", valor: parseFloat(t) / 100 };
    return { tipo: "abs", valor: parseFloat(t.replace(/^abs:/, "")) };
  }

  /** ¿Es correcta la respuesta numérica? Devuelve {ok, valor, error}. */
  function comprobarNumerico(entrada, objetivo, tol) {
    const valor = parseNumero(entrada);
    if (!Number.isFinite(valor)) return { ok: false, valor, error: null, invalida: true };
    const o = typeof objetivo === "number" ? objetivo : parseNumero(objetivo);
    const t = parseTolerancia(tol);
    const dif = Math.abs(valor - o);
    const limite = t.tipo === "rel" && o !== 0 ? Math.abs(o) * t.valor : t.tipo === "rel" ? t.valor : t.valor;
    return { ok: dif <= limite, valor, error: o !== 0 ? dif / Math.abs(o) : dif, invalida: false };
  }

  /** Normaliza «V», «Verdadero», «cierto», «F», «falso» a "verdadero" | "falso". */
  function normalizaVF(x) {
    const t = String(x).trim().toLowerCase();
    if (["v", "verdadero", "cierto", "si", "sí", "true"].includes(t)) return "verdadero";
    if (["f", "falso", "no", "false"].includes(t)) return "falso";
    return t;
  }

  /** Compara conjuntos de letras para opción múltiple: «a,c» ≡ «c, a». */
  function mismasOpciones(elegidas, correctas) {
    const norm = (x) => Array.from(new Set(String(x).toLowerCase().split(/[,\s;]+/).filter(Boolean))).sort().join(",");
    return norm(elegidas) === norm(correctas);
  }

  const LETRAS = "abcdefghijklmnopqrstuvwxyz";

  /* ------------------------------------------------------------------ */
  /* Almacenamiento local (con tolerancia a que no exista)               */
  /* ------------------------------------------------------------------ */
  const PREFIJO = "resonancia:ej:" + (typeof location !== "undefined" ? location.pathname : "");

  function leer(id) {
    try {
      const v = localStorage.getItem(PREFIJO + ":" + id);
      return v ? JSON.parse(v) : null;
    } catch (e) { return null; }
  }
  function guardar(id, estado) {
    try { localStorage.setItem(PREFIJO + ":" + id, JSON.stringify(estado)); } catch (e) { /* sin almacenamiento */ }
  }
  function borrarTodo() {
    try {
      Object.keys(localStorage).filter((k) => k.startsWith(PREFIJO + ":")).forEach((k) => localStorage.removeItem(k));
    } catch (e) { /* nada */ }
  }
  function todos() {
    const out = {};
    try {
      Object.keys(localStorage).filter((k) => k.startsWith(PREFIJO + ":")).forEach((k) => {
        out[k.slice(PREFIJO.length + 1)] = JSON.parse(localStorage.getItem(k));
      });
    } catch (e) { /* nada */ }
    return out;
  }

  /* ------------------------------------------------------------------ */
  /* Capa DOM                                                            */
  /* ------------------------------------------------------------------ */
  const ETIQUETA = {
    vf: "Verdadero o falso", opcion: "Test", numerico: "Cálculo", abierta: "Respuesta abierta",
    programacion: "Programación", investigacion: "Investigación", encuesta: "Reflexión (no evaluada)",
  };
  const ICONO = { vf: "✓✗", opcion: "◉", numerico: "∑", abierta: "✎", programacion: "⌘", investigacion: "⌕", encuesta: "☰" };

  function el(tag, props, ...hijos) {
    const e = document.createElement(tag);
    if (props) for (const k of Object.keys(props)) {
      if (k === "class") e.className = props[k];
      else if (k === "text") e.textContent = props[k];
      else if (k.startsWith("on")) e.addEventListener(k.slice(2), props[k]);
      else e.setAttribute(k, props[k]);
    }
    hijos.flat().forEach((h) => h && e.append(h));
    return e;
  }

  function sacar(ej, clase) {
    const n = ej.querySelector(":scope > ." + clase);
    if (n) n.remove();
    return n;
  }

  function mensaje(zona, tipo, texto) {
    zona.className = "ej-feedback ej-" + tipo;
    zona.textContent = texto;
  }

  function construir(ej, indice) {
    const tipo = ej.dataset.tipo;
    if (!ETIQUETA[tipo]) return null;
    const id = ej.id || "ej-" + indice;
    ej.id = id;
    ej.classList.add("ej-activo");

    const pista = sacar(ej, "pista");
    const solucion = sacar(ej, "solucion");
    const opciones = sacar(ej, "opciones");
    const rubrica = sacar(ej, "rubrica");
    const criterios = sacar(ej, "criterios");

    const cab = el("div", { class: "ej-cabecera" },
      el("span", { class: "ej-icono", "aria-hidden": "true", text: ICONO[tipo] }),
      el("span", { class: "ej-tipo", text: "Ejercicio · " + ETIQUETA[tipo] }),
      el("span", { class: "ej-estado", "aria-live": "polite" }));
    ej.prepend(cab);

    const zona = el("div", { class: "ej-ui" });
    const fb = el("div", { class: "ej-feedback", role: "status", "aria-live": "polite" });
    const botones = el("div", { class: "ej-botones" });
    const estado = leer(id) || { estado: "pendiente", intentos: 0 };

    const marca = () => {
      const m = { correcto: "✔ Resuelto", hecho: "✔ Hecho", visto: "Solución vista", enviado: "Guardado", pendiente: "" }[estado.estado] || "";
      cab.querySelector(".ej-estado").textContent = m;
      ej.dataset.estado = estado.estado;
      guardar(id, estado);
      actualizarProgreso();
    };

    const revelar = (nodo) => { if (nodo) { nodo.classList.remove("ej-oculto"); nodo.hidden = false; } };
    [pista, solucion].forEach((n) => { if (n) { n.classList.add("ej-oculto"); n.hidden = true; } });

    const btn = (texto, fn, clase) => el("button", { type: "button", class: "ej-btn " + (clase || ""), onclick: fn, text: texto });

    const btnPista = pista ? btn("Pista", () => { revelar(pista); }) : null;
    const btnSolucion = solucion ? btn("Ver solución", () => {
      revelar(solucion);
      if (estado.estado === "pendiente") estado.estado = "visto";
      marca();
    }) : null;

    /* ---------- por tipo ---------- */
    let comprobar = null;
    let recoger = () => null;

    if (tipo === "vf") {
      const grupo = el("div", { role: "radiogroup", "aria-label": "Verdadero o falso", class: "ej-vf" });
      ["verdadero", "falso"].forEach((v) => {
        grupo.append(el("label", { class: "ej-opcion" },
          el("input", { type: "radio", name: id, value: v }), el("span", { text: v === "verdadero" ? "Verdadero" : "Falso" })));
      });
      zona.append(grupo);
      recoger = () => (zona.querySelector("input:checked") || {}).value || null;
      comprobar = () => {
        const r = recoger();
        if (!r) return mensaje(fb, "aviso", "Elige una opción.");
        estado.intentos++;
        if (r === normalizaVF(ej.dataset.respuesta)) { estado.estado = "correcto"; mensaje(fb, "ok", "Correcto."); revelar(solucion); }
        else { mensaje(fb, "mal", "No es correcto. Piénsalo otra vez o pide la pista."); }
        estado.respuesta = r; marca();
      };
    }

    if (tipo === "opcion") {
      const multiple = ej.dataset.multiple === "true";
      const items = opciones ? Array.from(opciones.querySelectorAll(":scope > ul > li, :scope > ol > li")) : [];
      const grupo = el("div", { role: multiple ? "group" : "radiogroup", class: "ej-opciones" });
      items.forEach((li, i) => {
        const l = LETRAS[i];
        const input = el("input", { type: multiple ? "checkbox" : "radio", name: id, value: l });
        const etiqueta = el("label", { class: "ej-opcion" }, input, el("span", { class: "ej-letra", text: l + ")" }), el("span", { class: "ej-texto" }));
        while (li.firstChild) etiqueta.querySelector(".ej-texto").append(li.firstChild);
        grupo.append(etiqueta);
      });
      zona.append(grupo);
      recoger = () => Array.from(zona.querySelectorAll("input:checked")).map((i) => i.value).join(",") || null;
      comprobar = () => {
        const r = recoger();
        if (!r) return mensaje(fb, "aviso", "Elige una opción.");
        estado.intentos++;
        if (mismasOpciones(r, ej.dataset.respuesta)) { estado.estado = "correcto"; mensaje(fb, "ok", "Correcto."); revelar(solucion); }
        else mensaje(fb, "mal", "No es correcto. Revisa el razonamiento.");
        estado.respuesta = r; marca();
      };
    }

    if (tipo === "numerico" || tipo === "programacion") {
      if (ej.dataset.respuesta !== undefined && ej.dataset.respuesta !== "") {
        const entrada = el("input", { type: "text", inputmode: "decimal", autocomplete: "off", class: "ej-entrada", "aria-label": "Tu resultado", placeholder: "Tu resultado" });
        zona.append(el("div", { class: "ej-numero" }, entrada, ej.dataset.unidad ? el("span", { class: "ej-unidad", text: ej.dataset.unidad }) : null));
        entrada.addEventListener("keydown", (e) => { if (e.key === "Enter") { e.preventDefault(); comprobar(); } });
        recoger = () => entrada.value.trim() || null;
        comprobar = () => {
          const r = recoger();
          if (!r) return mensaje(fb, "aviso", "Escribe un valor numérico.");
          const c = comprobarNumerico(r, ej.dataset.respuesta, ej.dataset.tol);
          if (c.invalida) return mensaje(fb, "aviso", "No entiendo ese número. Puedes escribir 0,031 o 3.1e-2.");
          estado.intentos++; estado.respuesta = r;
          if (c.ok) { estado.estado = "correcto"; mensaje(fb, "ok", "Correcto."); revelar(solucion); }
          else mensaje(fb, "mal", "Aún no. Revisa las unidades y los pasos (tolerancia " + (ej.dataset.tol || "1%") + ").");
          marca();
        };
        if (estado.respuesta) entrada.value = estado.respuesta;
      }
    }

    if (tipo === "abierta" || tipo === "investigacion" || tipo === "programacion" || tipo === "encuesta") {
      const necesitaTexto = tipo === "abierta" || tipo === "investigacion" || (tipo === "encuesta" && ej.dataset.texto === "true");
      if (necesitaTexto) {
        const ta = el("textarea", { class: "ej-texto-libre", rows: tipo === "investigacion" ? "6" : "4", "aria-label": "Tu respuesta", placeholder: "Escribe aquí tu respuesta (se guarda solo en este navegador)." });
        ta.value = estado.texto || "";
        ta.addEventListener("input", () => { estado.texto = ta.value; guardar(id, estado); });
        zona.append(ta);
      }
      const lista = rubrica || criterios;
      if (lista && tipo !== "encuesta") {
        const titulo = tipo === "investigacion" ? "Criterios (márcalos cuando los cumplas)" : "Autoevalúate: ¿tu respuesta incluye…?";
        const caja = el("fieldset", { class: "ej-rubrica" }, el("legend", { text: titulo }));
        const marcados = estado.rubrica || [];
        Array.from(lista.querySelectorAll("li")).forEach((li, i) => {
          const cb = el("input", { type: "checkbox", value: String(i) });
          cb.checked = marcados.includes(i);
          cb.addEventListener("change", () => {
            estado.rubrica = Array.from(caja.querySelectorAll("input:checked")).map((x) => Number(x.value));
            guardar(id, estado);
          });
          const l = el("label", { class: "ej-opcion" }, cb, el("span", { class: "ej-texto" }));
          while (li.firstChild) l.querySelector(".ej-texto").append(li.firstChild);
          caja.append(l);
        });
        zona.append(caja);
      }
      if (tipo !== "programacion" || !comprobar) {
        comprobar = () => {
          if (tipo === "encuesta") {
            const r = recoger();
            estado.estado = "enviado";
            mensaje(fb, "ok", "Guardado en este navegador. Puedes cambiarlo cuando quieras.");
            marca(); return;
          }
          const hechos = (estado.rubrica || []).length;
          const total = (lista ? lista.querySelectorAll("li").length : 0);
          if (total && hechos < total) return mensaje(fb, "aviso", "Marca todos los puntos cuando los cumplas, o mira la solución modelo.");
          estado.estado = "hecho"; mensaje(fb, "ok", "Hecho. Compara con la solución modelo si quieres."); marca();
        };
      }
    }

    if (tipo === "encuesta") {
      const items = opciones ? Array.from(opciones.querySelectorAll("li")) : [];
      if (items.length) {
        const grupo = el("div", { role: "radiogroup", class: "ej-opciones" });
        items.forEach((li, i) => {
          const input = el("input", { type: "radio", name: id, value: String(i) });
          input.checked = estado.respuesta === String(i);
          const l = el("label", { class: "ej-opcion" }, input, el("span", { class: "ej-texto" }));
          while (li.firstChild) l.querySelector(".ej-texto").append(li.firstChild);
          grupo.append(l);
        });
        zona.prepend(grupo);
        recoger = () => (zona.querySelector("input[type=radio]:checked") || {}).value || null;
        const previo = comprobar;
        comprobar = () => { const r = recoger(); estado.respuesta = r; previo(); };
      }
    }

    /* restaurar estado visual */
    if (estado.respuesta && (tipo === "vf" || tipo === "opcion")) {
      String(estado.respuesta).split(",").forEach((v) => {
        const i = zona.querySelector('input[value="' + v + '"]'); if (i) i.checked = true;
      });
    }

    if (comprobar) botones.append(btn(tipo === "encuesta" ? "Guardar" : tipo === "abierta" || tipo === "investigacion" ? "He terminado" : "Comprobar", comprobar, "ej-btn-principal"));
    if (btnPista) botones.append(btnPista);
    if (btnSolucion) botones.append(btnSolucion);
    botones.append(btn("Reiniciar", () => {
      estado.estado = "pendiente"; estado.intentos = 0; delete estado.respuesta; delete estado.rubrica; delete estado.texto;
      zona.querySelectorAll("input").forEach((i) => { if (i.type === "checkbox" || i.type === "radio") i.checked = false; else i.value = ""; });
      zona.querySelectorAll("textarea").forEach((t) => (t.value = ""));
      [pista, solucion].forEach((n) => { if (n) { n.classList.add("ej-oculto"); n.hidden = true; } });
      fb.className = "ej-feedback"; fb.textContent = ""; marca();
    }, "ej-btn-sec"));

    ej.append(zona, botones, fb);
    [pista, solucion].forEach((n) => { if (n) ej.append(n); });
    marca();
    return ej;
  }

  /* ---------- panel de progreso ---------- */
  let panel = null;
  function actualizarProgreso() {
    if (!panel) return;
    const lista = Array.from(document.querySelectorAll(".ejercicio.ej-activo"));
    const evaluables = lista.filter((e) => e.dataset.tipo !== "encuesta");
    const hechos = evaluables.filter((e) => ["correcto", "hecho"].includes(e.dataset.estado)).length;
    const vistos = evaluables.filter((e) => e.dataset.estado === "visto").length;
    panel.querySelector(".ej-resumen").textContent =
      "Tu progreso en esta unidad: " + hechos + " de " + evaluables.length + " ejercicios resueltos" + (vistos ? " (" + vistos + " con la solución vista)" : "") + ".";
    const barra = panel.querySelector("progress");
    barra.max = Math.max(evaluables.length, 1); barra.value = hechos;
  }

  function crearPanel(n) {
    panel = el("div", { class: "ej-progreso", role: "region", "aria-label": "Progreso de los ejercicios" },
      el("p", { class: "ej-resumen" }),
      el("progress", { max: "1", value: "0", "aria-hidden": "true" }),
      el("p", { class: "ej-nota", text: "Tus respuestas y tu progreso se guardan solo en este navegador. No se envían a ningún sitio." }),
      el("div", { class: "ej-botones" },
        el("button", { type: "button", class: "ej-btn ej-btn-sec", text: "Descargar mis respuestas", onclick: () => {
          const blob = new Blob([JSON.stringify({ pagina: location.pathname, fecha: new Date().toISOString(), respuestas: todos() }, null, 2)], { type: "application/json" });
          const a = el("a", { href: URL.createObjectURL(blob), download: "resonancia-respuestas.json" }); a.click();
        } }),
        el("button", { type: "button", class: "ej-btn ej-btn-sec", text: "Borrar mis respuestas", onclick: () => {
          if (confirm("¿Borrar todas tus respuestas y tu progreso en esta página?")) { borrarTodo(); location.reload(); }
        } })));
    const primero = document.querySelector(".ejercicio.ej-activo");
    const hueco = document.querySelector("#quarto-document-content h2, main h2");
    (hueco || primero).before(panel);
  }

  function iniciar() {
    const lista = Array.from(document.querySelectorAll(".ejercicio"));
    if (!lista.length) return;
    lista.forEach((e, i) => construir(e, i + 1));
    crearPanel(lista.length);
    actualizarProgreso();
  }

  if (typeof document !== "undefined") {
    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", iniciar);
    else iniciar();
  }

  if (typeof globalThis !== "undefined" && globalThis.__EJ_TEST__) {
    globalThis.__EJ_EXPORTS__ = { parseNumero, parseTolerancia, comprobarNumerico, normalizaVF, mismasOpciones };
  }
})();
