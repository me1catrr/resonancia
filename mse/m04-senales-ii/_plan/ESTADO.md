# M04 — registro de continuidad

Documento de trabajo (no se publica: la carpeta empieza por «_»). Sigue el esquema de [M3](../../m03-senales-i/_plan/ESTADO.md).

**Alcance de esta rama.** El worktree `.claude/worktrees/m4-senales-ii` (rama `m4-senales-ii`, sesión «Worktree M4») trabaja **solo** en M4. No se edita M3 (rama `m3-lav`) ni M7 (rama `m7-polymax`). Los ficheros compartidos (`temario.yml`, `Resonancia.jl/Project.toml` y `Manifest.toml`, `recursos/bibliografia.bib`, `styles.css`) se tocan lo mínimo y de forma aditiva, para facilitar la fusión.

## Decisiones del responsable (01-11-2026)
- Esquema de M3: página única larga, `engine: julia`, Julia primero y espejo Python (`python: true`), simulaciones OJS con figura estática, caso integrado con rúbrica, test de salida, problemas, «Pídeselo a Claude», diapositivas.
- Ruta de 240 min (225 de trabajo + 15 de descanso). Fuera de la ruta obligatoria (ampliación): *wavelets*, el ruido propio del sensor en profundidad y los problemas numéricos.
- Trabajo por fases, con revisión del responsable tema a tema.

## Plan de fases
1. **Cimientos — HECHA (01-11-2026).** `temario.yml`, este registro, `Resonancia.jl` 0.10.0 (0.9.0 en `main` es la de M7) con docstring y test, referencia común `referencia/procesado.json` (generada por `scripts/m04/generar_referencia.jl`), módulo JS `recursos/js/procesado.js` (13 pruebas, con Node y con Deno) y espejo Python `python/procesado.py` (30 pruebas con pytest, también contra SciPy). Las tres implementaciones coinciden con Julia (≤ 1e-9) en: ventanas, tendencia, remuestreo, integración, SNR, espectros cruzados, H1/H2, espectrograma, Butterworth, FIR, filtrado causal y de fase cero y diezmado.
2. **Redacción** (en curso), un tema cada vez, con ejercicios intercalados y simulaciones.
   - **Hecho (01–02-11-2026): la redacción está COMPLETA.** Cabecera, ruta de 240 min, notación y fuentes; reto inicial (Torroja integrado dos veces: deriva de 1,17 m); M4.1 (ventanas; Simulaciones 1–3), M4.2 (filtros; 4–5), M4.3 (preprocesado; 6), M4.4 (integración, con vuelta al reto; 7), M4.5 (SNR y ruido; 8), M4.6 (H1/H2 y coherencia con el edificio de tres plantas; 9), M4.7 (espectrograma y wavelets; 10); caso integrado con Palma del Río (pestañas Julia y Python), test de salida (5), problemas numéricos (5), «Pídeselo a Claude», «La doy por superada si…» y diapositivas. 38 figuras, 24 tablas, 49 ejercicios, 10 simulaciones.
   - **Pendiente (no es redacción):** revisión del responsable tema a tema; `estado` de la cabecera sigue en `borrador` (decide el responsable si pasa a `revisado`); pruebas de navegador sin ejecutar (véase más abajo); comprobar en un teléfono real; confirmar licencia y coautoría del capítulo de NeuroMIND; leer el contenido de las referencias solo comprobadas en Crossref.
3. **Cierre.** Figuras TikZ (portada, cadena de preprocesado, diagrama de bloques de H1/H2), diapositivas, bibliografía, `quarto render` con `_freeze/`, pruebas de navegador, `estado` de la cabecera.

## Funciones de Resonancia.jl 0.10.0 (antes 0.9.0 en esta rama; `main` usó 0.9.0 para las de M7)
**Hecho (01-11-2026, tests en verde):**
- `ventanas.jl`: `perdida_escalonamiento`, `ancho_banda_3db`, `nivel_lobulo_lateral`, `correlacion_solape`, `varianza_welch`. Ya existían `ventana`, `ganancia_coherente` y `ancho_banda_ruido` (ENBW).
- `preprocesado.jl`: `quitar_tendencia(x, grado)` (grado 0 = offset) e `interpolar_uniforme(t, x, fs)` (remuestreo a rejilla uniforme, marca los huecos).
- `integracion.jl`: `integrar_trapecio`, `integrar_frecuencia(x, fs; fcorte, orden)` (aceleración → velocidad → desplazamiento, descartando por debajo de `fcorte`), `snr_db`, `snr_banda`, `rms_ruido_banda`.
- `cruzado.jl`: `espectros_cruzados`, `coherencia`, `frf_h1`, `frf_h2`, `estimar_frf` (convención `Gxy = conj(X)·Y`, `H1 = Gxy/Gxx`, `H2 = Gyy/conj(Gxy)`, `H1/H2 = γ²`) y `espectrograma` (su promedio temporal es `psd_welch`).
- `filtros.jl`: tipos `FIR` e `IIR` (cascada de secciones de segundo orden); `filtro_fir` (método de la ventana: pasabajos, pasaaltos, pasabanda, rechazabanda), `filtro_butterworth` (bilineal con *prewarping*, los mismos cuatro tipos), `respuesta_frecuencia`, `retardo_grupo` (analítico), `filtrar` (causal; `compensar=true` en FIR), `filtrar_fase_cero` (adelante-atrás con reflexión impar y estado estacionario) y `diezmar` (antialiasing FIR de fase cero). Sin dependencias.
- `wavelets.jl`: `cwt_morlet(x, fs, frecuencias; w0=6)` (módulo de la transformada wavelet continua de Morlet por FFT; amplitud local; espejo Python).
- `psd_welch` admite `ventana=` (por defecto `:hann`, sin cambiar los resultados anteriores).
- Valores de referencia comprobados (N = 256, ventanas periódicas): pérdida por escalonamiento 3,92 / 1,42 / 1,75 / 1,10 / 0,01 dB y lóbulo lateral −13,3 / −31,5 / −42,7 / −58,1 / < −80 dB para rectangular, Hann, Hamming, Blackman y flat-top. El 1,78 dB de Hamming de la bibliografía clásica corresponde a otra definición de la ventana.

**Decisión:** la detección de huecos, tramos planos y atípicos (Hampel, MAD) es limpieza de datos y ya está en J2.3 (con código propio de la página). M4.3 la enlaza y solo trata lo propio de la señal: offset, tendencia, remuestreo y el efecto espectral de huecos y picos. No se duplica en el paquete.

**Pendiente en el paquete:**
- Wavelets (solo introducción, ampliación): decidir si hace falta función (p. ej. la transformada continua con el *wavelet* de Morlet) o basta una simulación.
- Ya existían y se reutilizan: `ventana`, `psd_welch`, `buscar_picos`, `correlacion_cruzada`, `hilbert_analitica`.

## Verificación de los filtros (01-11-2026)
`scripts/m04/comprobar_filtros_dsp.jl` (entorno del curso, que sí tiene DSP.jl; Resonancia.jl no lo necesita):
- `filtro_butterworth` frente a `digitalfilter(..., Butterworth(n))` + `freqresp`: 640 diseños (4 tipos, orden 1–8, 4 frecuencias de muestreo, 5 bandas), diferencia máxima en la respuesta compleja 1,5·10⁻¹².
- `filtrar` frente a `filt`: 1·10⁻¹⁴. `filtrar_fase_cero` frente a `filtfilt` en el interior del registro: 7·10⁻⁹ (los extremos difieren a propósito: otras condiciones iniciales, véase Gustafsson, 1996).
- `filtro_fir` frente a `FIRWindow` (Hamming): 192 diseños, coeficientes y respuesta idénticos a 2·10⁻¹³ **salvo el signo en 16 pasaaltos de 51 coeficientes**: DSP.jl normaliza con la respuesta compleja y, si el retardo (ntaps−1)/2 es impar, invierte la polaridad. `filtro_fir` coincide con SciPy (`firwin`, comprobado con el entorno del árbol principal: 51 coeficientes, suma −0,0024; 101, 0,0015). Es una peculiaridad de DSP.jl, no de nuestro diseño; conviene decirlo en M4.2 si se usa `FIRWindow`.
- Corte efectivo con fase cero: en `filtfilt` la respuesta es |H|² (−6,02 dB en `fc`) y el punto de −3 dB queda en `(√2−1)^(1/2N)·fc` (≈ 0,896 `fc` para N = 4 en un pasabajos). El capítulo de NeuroMIND no lo explicita (solo habla del orden efectivo). Documentado y probado.
- Entorno: dentro del sandbox, `uv run` no puede reconstruir el entorno de un worktree (sin `.venv`, red cerrada); para pruebas con SciPy se usa `/Users/rafa/Proyectos/resonancia/.venv/bin/python -I`.

## Bibliografía añadida (01-11-2026, Crossref; contenido no leído → «parcial»)
`butterworth1930` (sin DOI, cita habitual y maqueta de NeuroMIND), `cheveigne2019`, `widmann2015` (lecturas esenciales del capítulo de NeuroMIND, escritas para electrofisiología pero generales en filtrado) y `gustafsson1996` (condiciones iniciales del filtrado adelante-atrás). El DOI de Gustafsson que se anotó primero era de otro artículo: se corrigió al verificarlo.

## Material de NeuroMIND (consultado el 01-11-2026)
Fuente: `~/Desktop/Typst_template/NeuroMIND · Capítulo 6 Filtrado — propuesta editorial.pdf` (maqueta de 4 páginas del capítulo «Filtrado», de Castro Triguero y Galvao Carmona, IMIBIC · UCO). El proyecto Quarto de NeuroMIND, con el resto del capítulo y sus scripts, **no está en este equipo**.
- **Usado:** los valores numéricos de la Tabla 6.1 (paso alto Butterworth de orden 4, fc = 0,5 Hz, fs = 500 Hz: ganancia y fase con una y dos pasadas, contrastados allí con `freqresp` de DSP.jl) como referencia de prueba de `filtro_butterworth`; coinciden con nuestra implementación en ganancia (±0,006 dB) y fase (±0,05°). También las ideas didácticas: orden de diseño frente a orden efectivo, `filt` frente a `filtfilt` (|H|², no para tiempo real), qué significa realmente la frecuencia de corte, polos en el semicírculo y *prewarping*, y la cascada con orden fijo de etapas.
- **Autorización del responsable (01-11-2026):** reutilizar todo lo posible, adaptado y con rigor científico. La reutilización incluye el texto y las figuras sintéticas del capítulo, rehechos para estructuras y citando la fuente.
- **No usado y no reutilizable sin más:** (1) las figuras 6.18 y 6.20 y la tabla 6.6 son EEG real de un participante de la cohorte (`sub-M05`): **no publicables**; (2) las tres fotografías de la carpeta (libros y revistas publicados, solo inspiración de diseño): de terceros y con copyright. Queda por confirmar con el responsable la compatibilidad de la licencia de NeuroMIND con CC BY-SA 4.0 y el permiso de la coautoría (A. Galvao Carmona); entretanto, el texto se redacta con palabras propias y las figuras se rehacen (TikZ/Makie) con señales de estructuras, citando el capítulo.
- El capítulo trabaja con EEG (µV, 500 Hz); aquí los ejemplos son vibraciones de estructuras (Torroja a 100 Hz, Palma a 512 Hz).

## Cómo ejecutar las pruebas
- Julia: `cd Resonancia.jl && julia --project=. -e 'using Pkg; Pkg.test()'`.
- JS: `deno test --no-check --allow-read recursos/js/` (o `node --test recursos/js/procesado.test.mjs`).
- Python: `uv run pytest mse/m04-senales-ii/python`. En un worktree, dentro del sandbox, `uv run` no puede reconstruir el entorno (sin `.venv`, red cerrada): usar `/Users/rafa/Proyectos/resonancia/.venv/bin/python -I -m pytest mse/m04-senales-ii/python`.
- Regenerar la referencia tras cambiar el paquete: `julia --project=. scripts/m04/generar_referencia.jl` (y volver a pasar las pruebas de JS y Python).
- Comprobación cruzada con DSP.jl: `julia --project=. scripts/m04/comprobar_filtros_dsp.jl`.

## Verificación de las simulaciones (01-11-2026)
- La **lógica** de las celdas OJS de las Simulaciones 1–5 se ha comprobado en Node con los mismos módulos (`procesado.js`, `senales.js`) y criterios, contra las cifras de Julia: los 10 casos de la Simulación 2, la coincidencia de K y de la desviación teórica y medida en la 3, los cuatro tipos y las dos familias de la 4. Los scripts de comprobación están en el scratchpad de la sesión, no en el repositorio.
- **Pendiente: pruebas de navegador.** `pruebas/web/test_m04.py` está escrito (misma plantilla que `test_m03.py`) pero **no se ha podido ejecutar**: Chromium no arranca dentro del sandbox (`bootstrap_check_in … Permission denied`) y la ejecución fuera del sandbox fue denegada. Hay que lanzarla a mano: `/Users/rafa/Proyectos/resonancia/.venv/bin/python -I -m pytest pruebas/web/test_m04.py` tras `quarto render mse/m04-senales-ii/index.qmd`. Desde el 02-11-2026 el fichero incluye pruebas para las Simulaciones 4–10, escritas con las mismas convenciones pero **sin ejecutar** (mismo motivo): es lo primero que hay que lanzar antes de fusionar.
- **Hallazgo de rigor (Simulación 5):** la correlación cruzada de una oscilación de banda estrecha mide el desfase de la portadora módulo un periodo (303 ms a 3,3 Hz) y daba «5 ms» con un retardo de grupo de 101 ms; la de las envolventes da +35 ms con fase cero por la propia deformación de la envolvente. Se muestra el **retardo de grupo exacto** (`retardo_grupo`) y se explica por qué no se mide por correlación.
- **Hallazgo de rigor (Simulación 2):** el criterio «sobresale del espectro del fuerte solo, punto a punto» es un artefacto cuando el tono débil cae en un nulo de la fuga (ventana rectangular a distancias enteras en bins): se comparan los **máximos** en ±0,5 bins. A 6 bins la fuga es −24 (rectangular), −43 (Hamming), −54 (Hann), −63 (Blackman) y −93 dB (flat-top); a δ = 4 la flat-top deja de ver el débil y gana Blackman.

## Hallazgos de rigor de la redacción (02-11-2026)
- **Sesgo de resolución (M4.6):** con el edificio de tres plantas **sin ruido**, la coherencia en los tres modos es 0,22 / 0,45 / 0,78 con segmentos de 1024 (bins de 0,098 Hz frente a un pico de 0,022 Hz) y 0,94 / 0,99 / 1,00 con 16 384. Una coherencia baja en un pico no siempre es ruido. Regla práctica del experimento: Δf ≲ ancho del pico / 4.
- **FRF verdadera del sistema muestreado:** no es la continua −ω²/(ω0²−ω²+2iζω0ω) ni esta por el retenedor de orden cero: la aceleración muestreada incluye la transmisión directa en el inicio de cada intervalo. Se toma la DFT de su respuesta impulsional (decae del todo).
- **Constante de integración (M4.4):** el trapecio parte de v = 0, pero un modo de amplitud A tiene velocidad media A/ω ≠ 0 y da una rampa A·t/ω (0,24 m en un minuto con A = 0,05 m/s² a 2 Hz), sin offset ni ruido. Es la tercera fuente de deriva, junto con el offset y las componentes lentas.
- **Ruido en la Simulación 7:** con 0,01 m/s² de ruido blanco el trapecio ya da 229 mm de error sin ninguna deriva; se bajó a 0,001.
- **`std` de Julia y NumPy:** `Statistics.std` divide por N−1 y NumPy por N; la discrepancia de 2,6·10⁻⁵ entre `caso.py` y Julia era exactamente √(N/(N−1))−1. `caso.py` usa `ddof=1`.
- **Pico espurio frente a evento (caso Palma):** el pico máximo de `set1` (213,9 s) tiene vecinas continuas (−1,4 … −2,4 … −2,1): es un evento físico, no una muestra mala. Se conserva.
- **Corte efectivo del pasabanda con fase cero:** el diseño de 0,5–25 Hz a 64 Hz queda en 0,56–24,3 Hz de −3 dB efectivos.
- **Interpolación lineal en el punto medio:** amplitud × cos(πf/fs) (identidad trigonométrica exacta; 29 % menos a fs/4). Una medida por picos de muestras daba un valor falso.
- **Carga de la clase:** hay 39 ejercicios intercalados y 10 simulaciones, más de lo que cabe en 4 h (M3 tenía unos 18 y 11). La ruta de 240 min es el plan de clase; el resto es trabajo autónomo. Está declarado en la página y las duraciones del `temario.yml` (lectura 80 + práctica 145) salen del recuento de palabras y de la ruta.

## Datos (comprobado el 01-11-2026)
- **Registros reales:** Torroja (100 Hz, vertical, g) y Palma del Río (512 Hz, g), los de M3. Sirven para preprocesado, integración, ruido y espectrograma.
- **H1/H2 no se puede hacer con datos reales del curso:** ningún registro tiene entrada medida (Palma `2014-06-19-modal` solo trae fotos; el edificio sintético solo guarda aceleraciones). Se genera en la página un par excitación-respuesta con `edificio_tres_plantas` (semilla fija) y se valida contra la FRF teórica calculada con M, C y K.

## Pendiente
- **Antes de fusionar con `main`:** lanzar a mano `pruebas/web/test_m04.py` (Chromium no arranca en el sandbox) tras `quarto render mse/m04-senales-ii/index.qmd`; revisar la página en un teléfono real.
- **Del responsable:** revisar M4.1–M4.7 y el caso; decidir si `estado` pasa de `borrador` a `revisado`; confirmar licencia y coautoría (A. Galvao Carmona) del capítulo de filtrado de NeuroMIND, en el que se inspira M4.2; leer el contenido de Butterworth (1930), de Cheveigné y Nelken, Widmann et al. y Gustafsson, de los que solo se han comprobado los datos bibliográficos.
- **Fuera de esta rama:** las remisiones desde M3 («Qué queda para M4», que sigue hablando de «en M4 se estudian…») y el ejercicio `m2-5-duracion` se tratan en `m3-lav`. Si M3 pasa a enlazar a anchors concretos de M4, usar `#m4-1` … `#m4-7`, `#caso`, `#test-salida`, `#problemas`, `#pideselo` y `#superada`.
- **Posibles mejoras, no necesarias:** JS para `cwt_morlet` (solo hay Julia y Python); mover las funciones de la Simulación 6 (sustitución del pico) al paquete si otra unidad las necesita; reducir el número de ejercicios intercalados si se quiere ajustar a la clase.
