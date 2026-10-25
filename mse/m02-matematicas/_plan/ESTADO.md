# M02 — registro de continuidad

Documento de trabajo (no se publica: la carpeta empieza por «_»). El plan aprobado está en `~/.claude/plans/pasted-content-id-471d-prompt-idempotent-cookie.md`; aquí se anota lo hecho y lo que sigue.

## Decisiones del responsable (25-10-2026)
- Estructura: portada `index.qmd` + una página por apartado, sin nuevos `id` en `temario.yml` (como las subpáginas de R1).
- `temario.yml`: subtemas M2.1.1–M2.1.7 y `python: true` en M2 (aplicado).
- Dependencias: solo SciPy en Python (con `uv add` y confirmación); Julia sin paquetes nuevos.
- FigureLabs: hasta 12 imágenes, solo conceptuales, por lotes y con inventario previo.

## Hecho
- **Fase 0** (auditoría y plan) aprobada el 25-10-2026.
- `temario.yml`: subtemas M2.1.1–M2.1.7 y `python: true`; `generar_estructura.jl` ordena por clave completa (`--comprobar`: 64 unidades correctas).
- **Fase 1 (matrices) — cerrada, sin publicar:**
  - `Resonancia.jl` 0.2.0: Toeplitz, Hankel, trayectoria, SSA, circulantes, convolución circular (directa y FFT), Vandermonde, autocorrelación, Yule–Walker, Levinson–Durbin, cadena de masas y muelles, edificio de cortante, modos propios, MAC, ERA, observabilidad y controlabilidad. Pruebas en `Resonancia.jl/test/runtests.jl` (todas pasan).
  - `recursos/js/matematicas.js` (+ `.test.mjs`): álgebra, Jacobi, SVD, FFT, estructuradas, AR, modos, MAC. 16 pruebas contra Julia; suite JS completa: 59.
  - Python: `mse/m02-matematicas/python/matrices.py` + `test_matrices.py` (11 pruebas, SciPy 1.18.1 añadido con `uv add`).
  - Referencia común Julia↔JS↔Python: `referencia/matrices.json`, generada por `scripts/m02/generar_referencia.jl`.
  - Bibliografía: 18 entradas nuevas (grupos `matematicas` e `identificacion`), cotejadas con Crossref; libros con `verificado: parcial`.
  - Figuras TikZ en `matrices/fig/`: portada, transformación (SVD), patrones, condicionamiento, cadena.
  - Página `matrices/index.qmd` (≈1 100 líneas): M2.1.1–M2.1.7, 4 laboratorios OJS (condicionamiento, Toeplitz/AR, Hankel/SSA, circulantes), 27 ejercicios, cápsulas históricas con fuentes leídas (Stewart, Gray).
  - `pruebas/web/test_m02_matrices.py`: 5 pruebas de navegador (laboratorios sin errores y reactivos).
  - `styles.css`: regla de desplazamiento interno de las ecuaciones destacadas anchas (sin desbordamiento a 390 px).
- Comprobaciones al cerrar la fase: render completo sin ejecutar celdas (`_freeze` al día), `compilar_tikz --comprobar` (37 figuras), `generar_bibliografia --comprobar`, `comprobar_datos`, enlaces y accesibilidad (33 pruebas).

## Pendiente de la Fase 1 (decidir)
- Laboratorios L1 «explorador de matrices estructuradas» y los de SVD/modos se hacen en las fases siguientes (L1 se integra con la SVD, L3 y L6).
- Cápsula histórica de Hankel: no hay fuente primaria leída; se ha evitado afirmar fechas.
- FigureLabs: aún no se ha generado ninguna imagen (0 de 12). El inventario del primer lote se propone para la Fase 2.
- `slides.qmd` de M02 sigue siendo un esqueleto.
- Verificar la voz y el diseño en un teléfono real (solo se ha probado con Chromium a 390 px).

## Siguiente (Fase 2)
`valores-propios/`, `svd/`, `laplace/`, `espacio-estados/`, `transformada-z/` y el caso transversal `edificio/` con datos sintéticos y escenarios A, B y C; laboratorios L3 (modos de masas y muelles) y L6 (SVD).
