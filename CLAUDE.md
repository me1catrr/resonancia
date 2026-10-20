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

## Datos
- `datos/sinteticos/`: en git, públicos.
- `datos/reales-publicables/`: solo con permiso confirmado.
- `datos/privados/`: NUNCA lo leas, listes, copies ni menciones su contenido.
- Cada conjunto de datos lleva una ficha `.meta.toml` (origen, sensor, fs,
  unidades, licencia, publicable).

## Forma de trabajar
- Antes de cambios que afecten a varios ficheros, presenta un plan y espera aprobación.
- Tras editar una página, compruébala con `quarto render <fichero>`.
- Nunca ejecutes `git push`, `quarto publish`, `gh repo create` ni cambies
  la configuración de GitHub sin petición explícita.
- Commits pequeños, mensaje en español en imperativo: «Añade unidad M3».

## Comandos útiles
- Vista previa: `quarto preview`
- Compilar una página: `quarto render mse/m03-senales-i/index.qmd`
- Julia del proyecto: `julia --project=.`
