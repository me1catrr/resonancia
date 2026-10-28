# Estado de la vía J (Julia para ingeniería)

Última actualización: 2026-10-26 (fin de sesión).

## Formato adoptado
Unidades de 60, 90 o 120 min (plantilla de `CLAUDE.md`): objetivos, teoría en 4–5 píldoras, práctica
guiada con pestañas Julia/Python, «Pídeselo a Claude» con *Verifica*, ejercicios y «La doy por superada si…».
Cada unidad: `index.qmd`, `slides.qmd`, `fig/*.tex` y `.svg`, `python/` con su prueba y `_freeze/`.

## Avance
| Nivel | Estado |
|---|---|
| J1 (J1.1–J1.8) | redactado, `estado: borrador` |
| J2 | redactadas J2.1–J2.8 (J2.8 sin MLJ: modelos propios en `Resonancia.jl`) |
| J3 | redactadas J3.1–J3.5, J3.7, J3.8 y J3.9; **pendiente J3.6 (EDO, requiere `OrdinaryDiffEq`)** |

Todas con diapositivas, figuras TikZ, `_freeze/`, cuadro de historia con fuente, errores frecuentes y lecturas citadas
(J2 con espejo Python probado). `Resonancia.jl` está en 0.6.0 (clasificación, raíces, viga, sensibilidades, optimización y grafos).

## Orden previsto
J1 → J3.8, J3.3, J3.1–J3.2 (los necesita M3/M4) → J2 → resto de J3.

## Decisiones tomadas
- Pluto, Plots.jl, Revise y Unitful se mencionan, pero **no están en el entorno del curso**;
  sus bloques de código no se ejecutan.
- Entorno ampliado (2026-10-26, con aprobación): `FFTW` y `DSP` (J3.8). `Resonancia` 0.4.0 alineado en el Manifest.
- El tipo `Registro` vive en J1.8; se moverá a `Resonancia.jl` (con docstring y test) cuando lo usen otras páginas.
- Datos de los ejemplos: `datos/sinteticos/edificio-3-plantas` y `datos/sinteticos/curso-claude`.
- Convención de registro multicanal: matriz `N × c` (muestras × canales).

## Pendiente de decidir o revisar
- **MLJ (J2.8) — resuelto sin MLJ (2026-10-27):** `Pkg.add(["MLJ", "MLJDecisionTreeInterface", "DecisionTree", "MLJLinearModels", "NearestNeighborModels"])`
  **degrada** `CSV` 1.1.0 → 0.10.17 y `Parsers` 3.0.0 → 2.8.8 (retira `DataStrings` y `Durations`). No se aplicó.
  Decisión: J2.8 con k-NN, LDA y regresión logística propios; la unidad lo explica y dice qué cambiaría con MLJ.
- Falta añadir al entorno, para J3.6: `OrdinaryDiffEq` (decisión de 2026-10-27, en lugar de `DifferentialEquations`). Antes de `Pkg.add`, comprobar la versión que resuelve y que no degrada `CSV`/`Parsers`.
- J2 y el resto de J3 necesitarán paquetes que no están en `Project.toml` (Distributions, HypothesisTests, GLM, MLJ,
  Roots, Optim, DifferentialEquations, BenchmarkTools…). Ampliar el entorno solo con aprobación.
- Simulaciones interactivas (OJS) en J1: no incluidas; valorar en J2.4 y J3.
- La publicación en GitHub Pages solo se lanza con push a `main` (`.github/workflows/publish.yml`), no con la rama de trabajo.
- En el sandbox, `uv run` necesita `UV_CACHE_DIR` en un directorio temporal y `--offline`.
