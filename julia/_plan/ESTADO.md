# Estado de la vía J (Julia para ingeniería)

Última actualización: 2026-10-26.

## Formato adoptado
Unidades de 60, 90 o 120 min (plantilla de `CLAUDE.md`): objetivos, teoría en 4–5 píldoras, práctica
guiada con pestañas Julia/Python, «Pídeselo a Claude» con *Verifica*, ejercicios y «La doy por superada si…».
Cada unidad: `index.qmd`, `slides.qmd`, `fig/*.tex` y `.svg`, `python/` con su prueba y `_freeze/`.

## Avance
| Nivel | Estado |
|---|---|
| J1 (J1.1–J1.8) | redactado, `estado: borrador` (pendiente de revisión) |
| J2 (J2.1–J2.8) | esqueletos |
| J3 (J3.1–J3.9) | esqueletos |

## Orden previsto
J1 → J3.8, J3.3, J3.1–J3.2 (los necesita M3/M4) → J2 → resto de J3.

## Decisiones tomadas
- Pluto, Plots.jl, Revise y Unitful se mencionan, pero **no están en el entorno del curso**
  (no se ha ejecutado ningún `Pkg.add`); sus bloques de código no se ejecutan.
- El tipo `Registro` vive en J1.8; se moverá a `Resonancia.jl` (con docstring y test) cuando lo usen otras páginas.
- Datos de los ejemplos: `datos/sinteticos/edificio-3-plantas` y `datos/sinteticos/curso-claude`.
- Convención de registro multicanal: matriz `N × c` (muestras × canales).

## Pendiente de decidir o revisar
- Manifest.toml fija `Resonancia 0.2.0` y el paquete local es `0.4.0` (J1.2 muestra la versión cargada, 0.4.0).
  Se resolvería con un `Pkg.resolve()` (cambia el entorno: requiere aprobación).
- J2 y J3 necesitarán paquetes que no están en `Project.toml` (Distributions, HypothesisTests, GLM, MLJ,
  DSP, FFTW, Roots, Optim, DifferentialEquations…). Ampliar el entorno solo con aprobación.
- Simulaciones interactivas (OJS) en J1: no incluidas; valorar en J2.4 y J3.
- En el sandbox, `uv run` necesita `UV_CACHE_DIR` en un directorio temporal y `--offline`.
