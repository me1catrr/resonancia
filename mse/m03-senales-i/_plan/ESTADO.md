# M03 — registro de continuidad

Documento de trabajo (no se publica: la carpeta empieza por «_»). Plan aprobado: `~/.claude/plans/pasted-content-id-5496-act-a-como-cozy-blanket.md`.

## Decisiones del responsable (31-10-2026)
- Página única larga (como M5–M7), con detalles en desplegables.
- M3.7 (ESP32) pasa a M8 como M8.8.
- Caso integrado solo con datos del proyecto (Palma del Río `set1`; variante Torroja GS4).
- `ejercicios.js` admite `.retro` (retroalimentación por opción).

## Hecho (31-10-2026, sin commits)
- `temario.yml`: M3 con `python: true`, `duracion` (93 + 132 = 225 min; 15 de descanso fuera) y `duracion_temas`; M3.7 → M8.8.
- `Resonancia.jl` 0.8.0: `muestreo.jl` (`descriptores_temporales`, `cuantizar`, `frecuencia_aparente`) y `espectro.jl` (`dft` con Bluestein, `periodograma`, `espectro_amplitud`, `potencia_bandas`, `psd_normalizada`, `anpsd`), con pruebas.
- Referencia común `referencia/senales.json` (`scripts/m03/generar_referencia.jl`); JS `recursos/js/senales.js` (+ pruebas) y Python `python/senales.py` (+ pytest, también contra SciPy).
- Extracto `torroja-puente/.../extractos/m01_z_300s_mg.csv` (`scripts/m03/preparar_extractos.jl`); `campana.meta.toml` actualizado.
- `styles.css`: cajas `.caso-real`, `.curiosidad`, `.reto`; `.laboratorio`, `.solo-pantalla`, `.solo-impresion`; distintivos de ruta; `.retro`.
- Página `index.qmd` (8 simulaciones, 3 diagnósticas, 8 comprobaciones de interpretación (una por simulación), 6 ejercicios breves y 1 a mano, test de salida de 5, 5 problemas, 5 cápsulas históricas, caso con rúbrica) y `slides.qmd`.
- Figuras TikZ: portada, cadena, cuantización, repetición.
- Bibliografía: 16 entradas nuevas (Crossref; Meijering y Davoodi leídos; tres columnas de Avitabile leídas en la recopilación de UMass Lowell).

## Ampliación de M3.1 y M3.2 (31-10-2026, a petición del responsable)
- Ruta reequilibrada (aprobada): M3.1 30 min, M3.2 30, M3.4 25, M3.5 35, caso 25; total 240. `temario.yml` y diapositivas al día.
- M3.1: taxonomía (`fig/taxonomia.tex`), tabla de tipos, energía frente a potencia, estacionariedad estricta, débil y ergódica, tres formas de no estacionariedad; Simulación 1 (galería de 11 tipos); apartado de ruido (definición relativa, aditivo y multiplicativo, colores, distribución, origen) con recuadro de ruido eléctrico (térmico, disparo, 1/f, red, interferencias, triboeléctrico, diafonía) y caso real; Simulación 3 (colores del ruido con red de 50 Hz); cápsula de Johnson y Nyquist (1928).
- M3.2: significado físico de cada descriptor, asimetría y pico a pico, N frente a N−1, figuras de lectura geométrica y «misma σ», tabla de valores de referencia; Simulación 4 (momentos a la vista, con la contribución de cada instante a la curtosis).
- `Resonancia.jl`: `descriptores_temporales` con `asimetria` y `pico_pico`; nueva `colorear` (ruido 1/f^α); espejo en JS y Python y referencia común ampliada.
- Simulaciones renumeradas (1–11). Bibliografía: `johnson1928`, `nyquist1928termico`, `schottky1918`.
- Render con Julia 1.12.3 (la del `Manifest.toml`): `QUARTO_JULIA=…/julia-1.12.3…/bin/julia`.

## Actividad de la LAV Madrid–Sevilla (rama `m3-lav`, 01-11-2026)
Encargo y diseño en `TRASPASO-LAV.md`; prototipo comprobado en `lav_prototipo.jl` (sus cifras se reproducen con la página).
- `index.qmd`: `### Actividad … {#lav}` (ampliación, 35 min) entre el caso integrado y «Pídeselo a Claude»: contexto y tabla de cinco obras (`@puentesferroviarios`), escenario sintético declarado como supuesto, cinco ejercicios numéricos a mano (`m3-lav-luz`, `-vres`, `-fs`, `-bits`, `-seg`), pasos en Julia (excitación y velocidad resonante, elección de la adquisición, señal, descriptores por tramos, PSD según la ventana, comprobación de la cuantificación), pestaña Python no ejecutable e interpretación abierta con rúbrica (`m3-lav-interpretacion`). Fila nueva en la ruta.
- Casos reales de los artículos: Sesia en M3.3 (`@chellini2008`), Guadiana en M3.1 (no estacionariedad a escala de días) y en M3.4 (filtrar antes de diezmar) (`@peeters2006guadiana`), y viñeta del correlograma en M3.6 (remite a M7; **sin fuente citada**, es descripción general).
- `Resonancia.jl`: nueva `aceleracion_1gdl` (en `edos.jl`, exportada, con docstring y prueba frente al escalón analítico). **No se ha subido la versión (sigue 0.8.0)**: se decide al fusionar con la rama de M7, que probablemente toca el mismo paquete (conflicto esperable en el `export` de `Resonancia.jl/src/Resonancia.jl`, línea de `respuesta_libre_1gdl…`).
- Python: `aceleracion_1gdl` en `python/senales.py` y su test en `python/test_senales.py` (valores de contraste sacados de Julia y solución analítica). **El pytest no se ha podido ejecutar en esta sesión** (el sandbox bloquea la descarga del entorno de `uv`); sí se ha comprobado que las fórmulas cerradas de Φ y Γ coinciden con la exponencial matricial. Ejecutar `uv run pytest` en `mse/m03-senales-i/python/` antes de fusionar.
- Datos del libro (longitudes, vanos, esquemas, 1992, ≈34 obras) tomados de `TRASPASO-LAV.md`; el libro no está en el repositorio. Las fichas `puentesferroviarios` (autoría, editorial, año) siguen incompletas.

## Hallazgos
- Ningún registro del curso muestra líneas de red: Palma, 0,6–2,1 veces el entorno a 50/100/150 Hz; Torroja cae 63–79 dB de 20–30 Hz a 48–50 Hz (compatible con un filtro antialiasing no documentado).
- Dos tonos a δ con ventana rectangular: con T = 1/δ solo se separan en el 36 % de las fases; con T ≥ 1,8/δ, siempre; con Hann, T ≈ 3/δ.
- Palma `set1`: cresta 13, curtosis 23, RMS por segundo ×45; el primer minuto tiene un tercio de la potencia de los 300 s.
- NeuroMIND no define ANPSD (la única coincidencia de búsqueda era un SVG); se usa la convención declarada (suma en banda común), coherente con la de Felber según Davoodi et al.
- M2.5, ejercicio `m2-5-duracion`: su solución dice que T = 1/Δf basta para «separar» dos modos; conviene matizarlo (pendiente de decisión del responsable).

## Pendiente
- Verificación en un teléfono real.
- Tesis de Felber (acceso bloqueado).
- M4 (ventanas, filtros, etc.) remite desde M3.
