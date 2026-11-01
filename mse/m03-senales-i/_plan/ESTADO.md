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
- `Resonancia.jl`: nueva `aceleracion_1gdl` (en `edos.jl`, exportada, con docstring y prueba frente al escalón analítico). **Versión decidida al fusionar con la rama de M7: 0.9.0** (suma esta función y los módulos `lscf`, `fdd`, `ssicov` y `semiespectro` de M7). El conflicto previsto en el `export` no llegó a producirse: solo chocó el informe generado de la bibliografía, que se regeneró.
- Python: `aceleracion_1gdl` en `python/senales.py` y su test en `python/test_senales.py` (valores de contraste sacados de Julia y solución analítica). Pytest ejecutado desde `mse/m03-senales-i/python/` con el `.venv` del repositorio: 10 pruebas pasan (01-11-2026). Ojo: `uv run pytest` desde la raíz **falla en la recolección** porque `claude/c5-programar/_ejemplo/python/test_senales.py` tiene el mismo nombre de fichero (choque de módulos de pytest); no es un fallo de M3. Hay que ejecutarlo en la carpeta de la unidad, o dar nombres únicos / usar `--import-mode=importlib`.
- Datos del libro (longitudes, vanos, esquemas, 1992, ≈34 obras) tomados de `TRASPASO-LAV.md`; el libro no está en el repositorio. La ficha `puentesferroviarios` se completó el 01-11-2026 con la ficha de Casa del Libro (García Mateo, Doce Calles, 2004, ISBN 978-84-9744-036-3, título «Inventario de puentes ferroviarios de España»); falta cotejarla con la portada, y la copia parcial llevaba un título distinto («Puentes ferroviarios de España»).

## Revisión final M3/M8 (rama `worktree-m3-revision`, 01-11-2026)
Plan aprobado en `~/.claude/plans/bubbly-seeking-token.md`. **Principio: M3 = comprender la señal; M8 = comprender la medición.**
- **Estructura.** Sesión de 240 min (225 + 15 de descanso) con tres distintivos: esencial ●, laboratorio ◆, profundización ○ (CSS en `styles.css`; profundización en recuadros plegados). Tabla de ruta nueva: reto 10, M3.1 30, M3.2 25, M3.3 20, M3.4 30, descanso 15, M3.5 30, M3.6 30, caso 40, test 10. `temario.yml` al día (M3 70+155; M8 `requiere: [M3]` y duración provisional).
- **Simulaciones (12 → 10).** Fundidas las antiguas 6 y 7 en la nueva **Simulación 5, «Cadena de adquisición»** (partes A y B; usa `sumaTonos` y `gananciaButterworth` de `senales.js`); eliminada la antigua 5 (su figura estática pasa a figura de texto `fig-mismo-rms`); la ANPSD pasa a ser la Simulación 10, con versión estática. Esenciales: 2, 4, 5, 6, 8, 9. Laboratorios: 1, 3, 7, 10. Numeración final por orden de aparición.
- **M3 → M8.** Salen de M3 y viven en M8.1/M8.3: cadena completa, tabla de «rango», ejemplo de ±2 g, ejercicios `m3-1-termico`, `m3-3-paso`, `m3-3-interpretacion`, `m3-prob-cuantificacion`, caso Sesia, historia Johnson–Nyquist y el detalle del ruido eléctrico. En M3 queda `fig/cadenas` (comparación analógica/digital a nivel de bloques) y ejercicios nuevos `m3-3-q`, `m3-3-snr` e `m3-3-interpretacion-cadena`. Los ids antiguos pierden el progreso de `localStorage`.
- **Correcciones científicas.** Definición de estacionariedad (procesos aleatorios; el sentido práctico para señales deterministas, aparte); aviso sobre la PSD de Welch en señales no estacionarias; nota sobre cuadrado medio frente a potencia mecánica; líneas de red y Nyquist en Torroja (la ausencia de línea a 50 Hz **no prueba** nada con fs = 100 Hz); retro del diagnóstico del RMS; regla de separación de tonos unificada (≥ 1,8/δ, en la práctica 2/δ).
- **Caso Palma del Río = investigación guiada.** Hipótesis H1–H3 con criterios previos y referencia estacionaria simulada (13 modos FDD, ζ = 1,5 %, 200 realizaciones, semilla 2026: máx/mediana p99 = 1,51; primer minuto/total entre 0,92 y 1,07). Resultado: H1 y H3 sostenidas para `set1`, **pero el control `set2` (sin tráfico) también las cumple** (4,0 y 2,81), así que no se atribuye al tráfico; H2 indeterminada (4 de 8, azar ≈ 2,5).
- **Laboratorio de la LAV.** El barrido de velocidades **refuta** que la respuesta máxima esté en v = f_n·d: el máximo está hacia 130 km/h (la mitad), porque con L/d = 1,48 ≈ 1,5 se cancela la resonancia del primer armónico; con d = 14 o 22 m el máximo vuelve a v = f_n·d (202 y 320 km/h). Es un resultado del escenario sintético, no de la línea real. Corregido también el uso de «segmentos de 25 s» (solo para el ambiente; el paso es un transitorio de ≈ 3 s).
- **JS/Python.** Paridad: redondeo del paso de Welch al par, `cuantizar` exige bits enteros, `coma` sin «-0,00», `psd_welch` de Python valida `solape`; más pruebas (JS 84, Python 16). Welch en Julia exige `nseg` potencia de 2 y JS/Python no: documentado y probado, no restringido.
- **M8.** `mse/m08-adquisicion/`: M8.1 y M8.3 redactados con figuras TikZ y 19 ejercicios comprobados en Julia; M8.2 y M8.4–M8.8, esqueleto «pendiente». Siete fuentes nuevas (`keywords = sensores`) con `verificado` honesto: PCB TN-17 y Endevco TP 326 leídas enteras; las demás, parciales o comerciales. **Sin verificar:** MT-003 de Analog Devices (ENOB se cita desde Wikipedia), hoja del ADXL355 (Occhipinti et al. dan 22,5 y 25 µg/√Hz de forma incoherente), contramedidas de EMI/red/diafonía e instalación (marcadas «sin fuente»).
- **Pruebas.** `pruebas/web/test_m03.py` adaptado (10 pruebas, pasan); M8 añadido a enlaces, accesibilidad y vista. Chromium no arranca dentro del sandbox: se ejecutaron fuera de él.
- **Pendiente.** Comprobar en un teléfono real; M2.5 `m2-5-duracion` (decisión tuya); revisar la sensación de la duración con una lectura cronometrada; retitular M8.3/M8.5 si se quiere reflejar «selección» e «I²C» (no se ha tocado `temario.yml` más allá de duración y `requiere`); `transformada-z/index.qmd:346` dice «tema de M3 y M8» y debería decir M4.2.

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
