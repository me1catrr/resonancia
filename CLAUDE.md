# Resonancia — instrucciones para Claude Code

## Qué es este proyecto
Web de autoformación en Quarto: *Vibraciones, señales y monitorización
estructural con Claude Code*. Responsable único: Rafael Castro Triguero
(GitHub `me1catrr`). Se publica en https://me1catrr.github.io/resonancia/.

Cuatro vías y recursos:
- **M** (`mse/`): Monitorización de la Salud Estructural, una unidad por sesión (M0–M12).
- **J** (`julia/`): Julia para ingeniería, tres niveles (J1, J2, J3).
- **C** (`claude/`): Claude y Claude Code (C0–C9).
- **L** (`labs/`): laboratorios; L1–L8 = prácticas oficiales P1–P8; PG = proyecto globalizador.
- **R** (`recursos/`): datos, Resonancia.jl, chuletas, glosario, bibliografía, mapa.

Regla de reparto: el concepto se explica en M, su implementación en J y su
uso asistido con Claude en L. No duplicar contenidos entre vías: enlazar.

## Fuente de verdad
`temario.yml` define identificadores, títulos, carpetas, prerrequisitos,
perfiles y temas de todas las unidades. No inventes unidades ni
identificadores. Si algo falta o cambia, propón primero el cambio en
`temario.yml` y espera aprobación.

## Convenciones de contenido
- Español de España. Término técnico inglés entre paréntesis la primera vez.
- Unidades SI. Notación: f (Hz), ω (rad/s), ζ (amortiguamiento), M, C, K.
- Julia primero. Pestaña Python paralela solo en unidades con `python: true`.
  Excepciones declaradas: L5 (C/C++ y Python) y L8 (Python).
- Toda página que ejecute Julia lleva `engine: julia` en su cabecera.
  Nunca uses Jupyter ni IJulia.
- El código Python de las pestañas no se ejecuta en la web: su versión
  probada vive en la carpeta `python/` de la unidad, con test pytest.
- Figuras con CairoMakie. Datos aleatorios siempre con semilla fija.
- No reproduzcas texto de libros ni de fuentes con copyright: redacta con
  palabras propias y cita con `recursos/bibliografia.bib`.

## Plantilla de unidad (orden fijo de secciones)
1. Objetivos y prerrequisitos
2. Teoría breve
3. Práctica guiada (pestañas Julia/Python cuando proceda)
4. «Pídeselo a Claude»: `.callout-tip` con el prompt y un apartado *Verifica*
5. Ejercicios
6. «La doy por superada si…»
Diapositivas: `slides.qmd` (reveal.js) en la misma carpeta de la unidad.

## Metadatos obligatorios en la cabecera de cada unidad
`id`, `title`, `via`, `requiere`, `perfil`, `estado` (borrador | revisado |
publicado), y cuando proceda `sesion`, `practica` y `verificado`
(versiones de Claude Code y Julia con las que se comprobó; obligatorio en la vía C).

## Código y entornos
- Un único entorno Julia en la raíz (`Project.toml` + `Manifest.toml`).
- `Resonancia.jl/` es un paquete local incorporado con `Pkg.develop`.
  Toda función reutilizable va al paquete con docstring y test; no copies
  funciones entre páginas.
- Python: entorno gestionado con `uv` (`pyproject.toml`). No uses conda.
- `_freeze/`: toda página con código Julia (`engine: julia`) se commitea junto
  con su `_freeze/`. Tras editarla, `quarto render <fichero>` y, en el mismo
  commit, la página y los ficheros que cambien en `_freeze/`. La publicación en
  GitHub Actions no tiene Julia y lee `_freeze/`: si falta o está desactualizado,
  la publicación falla. No ignores `_freeze/` en `.gitignore`.

## Figuras, cajas y bibliografía
- **Reparto de figuras.** TikZ para mecánica, esquemas geométricos, diagramas de
  bloques y enunciados de ejercicios; Makie u OJS (con deslizadores) para datos y
  simulaciones; FigureLabs solo para ilustraciones conceptuales, tras comprobar
  sus condiciones de uso. Nada de capturas de páginas como sustituto del texto.
- **TikZ.** Fuente `fig/nombre.tex` (`\documentclass[tikz,border=4pt]{standalone}` y
  `\usepackage{resonancia}`, estilo en `recursos/tikz/resonancia.sty`). Se compila con
  `julia --project=. scripts/compilar_tikz.jl` y se commitean el `.tex` y el `.svg`
  (la publicación no tiene LaTeX). `--comprobar` detecta SVG ausentes o desactualizados.
- **Figuras en la página.** Pie, `{#fig-…}` y `fig-alt` obligatorios. Las simulaciones
  interactivas se rotulan «Simulación n» (para no chocar con «Figura n»).
- **Cajas** (`styles.css`): `{#def-…}` definición, `{#thm-…}`/`{#prp-…}` resultado,
  `{#exm-…}` ejemplo resuelto, `.callout-note .demostracion collapse="true"`
  demostración plegable, `.callout-tip .idea-clave` idea clave, `.callout-warning`
  errores frecuentes. El color nunca es la única señal.
- **Bibliografía.** Una sola fuente, `recursos/bibliografia.bib`, con `keywords`
  (grupo) y `verificado` (`sí:`, `parcial:` o `no:` + cómo). Las páginas que citan llevan
  `citation-location: margin` en su cabecera (no ponerlo a nivel de proyecto: rompe el
  render de las páginas sin citas). R5 se regenera con
  `julia --project=. scripts/generar_bibliografia.jl` (`--comprobar` para verificar).
- **Historia y noticias.** `::: {.callout-note .historia icon=false title="Un poco de historia: …"}`
  y `.noticia` (`title="En las noticias: …"`). Solo hechos comprobados en una fuente que se
  enlaza (con fecha de consulta); si hay discrepancia entre fuentes, se dice. Nada de
  copiar texto ajeno: resumen propio y enlace.
- **Portada de cada unidad.** `fig/portada.tex` (TikZ, 12×3.6 cm) y, justo bajo la cabecera,
  `![](fig/portada.svg){.portada fig-alt="…"}`.
- **Referencias al final.** Además del margen, `scripts/referencias.lua` añade la lista
  «Referencias» al final de las páginas con citas al margen.
- **Licencias.** El contenido va bajo CC BY-SA 4.0. No copies texto, figuras ni capturas
  de cursos o documentación de Anthropic (AI Fluency es CC BY-NC-SA, incompatible):
  redacta con palabras propias, cita y enlaza.

## Ejercicios intercalados
Tras cada apartado de teoría, 1–3 ejercicios de autoevaluación en Markdown:
`::: {.ejercicio tipo="…" id="mX-Y-nombre" respuesta="…" tol="1%" unidad="…"}` con
hijos opcionales `.pista`, `.solucion`, `.opciones` (lista), `.rubrica` y `.criterios`
(listas de autoevaluación). Tipos: `vf`, `opcion` (`multiple="true"`), `numerico`,
`abierta`, `programacion` (con `respuesta` si hay resultado numérico), `investigacion`
(casos reales e históricos, con criterios de verificación como en C0.2) y `encuesta`
(reflexión no evaluada). El filtro `scripts/ejercicios.lua` y `recursos/js/ejercicios.js`
los activan; todo ocurre en el navegador y se guarda en `localStorage`, nada se envía
(coherente con C0.4). Toda respuesta numérica se comprueba antes en Julia. Pruebas:
`deno test --no-check --allow-read recursos/js/` con el Deno de Quarto.

## Datos
- `datos/sinteticos/`: en git, públicos.
- `datos/reales-publicables/`: solo con permiso confirmado.
- `datos/privados/`: NUNCA lo leas, listes, copies ni menciones su contenido.
- Cada conjunto de datos lleva una ficha `.meta.toml` (origen, sensor, fs,
  unidades, licencia, publicable).

## Apuntes de consulta (solo locales)
- Los PDF de referencia están en `docs/`, dentro de la raíz del proyecto:
  `/Users/rafamacstudio/Proyectos/resonancia/docs`. Es una carpeta local ignorada
  por Git, no documentación pública.
- Consulta únicamente los documentos necesarios cuando el usuario lo solicite;
  pide autorización de acceso si corresponde. No se conceden permisos generales
  de lectura de otras carpetas por esta configuración.
- Cita el título del documento y la página. No añadas enlaces de descarga,
  enlaces `file://` ni rutas locales a los PDF en las páginas publicadas.
- No copies los PDF ni extraigas su contenido a carpetas públicas, `_site/` o
  `_freeze/`, ni crees enlaces simbólicos hacia ellos fuera de `docs/`.
  Redacta con palabras propias y respeta los derechos de las fuentes.
- No añadas esta carpeta como entrada o recurso de Quarto ni uses `git add -f`
  para incluirla. La compilación y la publicación deben funcionar sin ella.
- `_quarto.yml` excluye `docs/**`; `scripts/no_publicar_docs.ts` comprueba tras
  el render que no exista `docs/` en la salida web. Si falla, retira el enlace
  o recurso que provoca la copia y vuelve a compilar; no desactives el control.
  No protege copias manuales en otras rutas ni documentos ya publicados.

## Forma de trabajar
- Antes de cambios que afecten a varios ficheros, presenta un plan y espera aprobación.
- Tras editar una página, compruébala con `quarto render <fichero>`.
- Nunca ejecutes `git push`, `quarto publish`, `gh repo create` ni cambies
  la configuración de GitHub sin petición explícita.
- Commits pequeños, mensaje en español en imperativo: «Añade unidad M3».

## Configuración de Claude Code (`.claude/settings.json`)
Versionada: vale para el responsable y para el alumnado.
- **Sin preguntar**: `julia --project=.`, `quarto render` y `preview`,
  `git status/diff/log/show/add/commit`, `gh run list/view`, `uv run`.
- **Siempre pregunta**: `git push`, `quarto publish`, los comandos `gh` que
  modifican GitHub, el git destructivo (`restore`, `reset --hard`, `clean`,
  `checkout -- / .`, `branch -D`, `stash drop/clear`, `rebase`) y añadir, quitar
  o actualizar paquetes de Julia (`Pkg.add/rm/up…`) o de Python (`uv add/remove/sync…`).
- **Bloqueado**: leer, listar o buscar en `datos/privados/` (reglas de permisos,
  hook `.claude/hooks/bloquear-datos-privados.sh` y sandbox), `rm -rf`, los
  ficheros `.env` y las credenciales (`~/.ssh`, `~/.aws`, tokens de `gh`…).
- **Sandbox**: activo. Los comandos escriben en el proyecto, en el depot de Julia
  (`~/.julia/…`) y en la caché de Quarto; el resto del equipo es de solo lectura.
- **Límites**: las reglas de Bash comparan texto y se pueden esquivar
  (`git -C . push`, `sh -c '…'`, un script que llame a `Pkg.add`); la defensa de
  fondo es el sandbox. En Windows nativo no hay sandbox: usa WSL2. Pendiente de
  probar en Windows: reglas `PowerShell(...)` y variante `.ps1` del hook.
- Ajustes personales en `.claude/settings.local.json` (ignorado por git). Las
  reglas `allow` del proyecto solo se activan tras aceptar el diálogo de
  confianza de la carpeta.

## Comandos útiles
- Vista previa: `quarto preview`
- Compilar una página: `quarto render mse/m03-senales-i/index.qmd`
- Julia del proyecto: `julia --project=.`
