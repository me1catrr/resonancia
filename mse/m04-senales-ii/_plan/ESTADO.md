# M04 — registro de continuidad

Documento de trabajo (no se publica: la carpeta empieza por «_»). Sigue el esquema de [M3](../../m03-senales-i/_plan/ESTADO.md).

**Alcance de esta rama.** El worktree `.claude/worktrees/m4-senales-ii` (rama `m4-senales-ii`, sesión «Worktree M4») trabaja **solo** en M4. No se edita M3 (rama `m3-lav`) ni M7 (rama `m7-polymax`). Los ficheros compartidos (`temario.yml`, `Resonancia.jl/Project.toml` y `Manifest.toml`, `recursos/bibliografia.bib`, `styles.css`) se tocan lo mínimo y de forma aditiva, para facilitar la fusión.

## Decisiones del responsable (01-11-2026)
- Esquema de M3: página única larga, `engine: julia`, Julia primero y espejo Python (`python: true`), simulaciones OJS con figura estática, caso integrado con rúbrica, test de salida, problemas, «Pídeselo a Claude», diapositivas.
- Ruta de 240 min (225 de trabajo + 15 de descanso). Fuera de la ruta obligatoria (ampliación): *wavelets*, el ruido propio del sensor en profundidad y los problemas numéricos.
- Trabajo por fases, con revisión del responsable tema a tema.

## Plan de fases
1. **Cimientos.** `temario.yml` (hecho), este registro (hecho), `Resonancia.jl` 0.9.0 con docstring y test, referencia común `referencia/*.json` (generada desde Julia), módulo JS con pruebas y espejo Python con pytest (y contraste con SciPy).
2. **Redacción**, un tema cada vez, con ejercicios intercalados y simulaciones: M4.1 → M4.7, reto inicial, caso integrado, test de salida, problemas.
3. **Cierre.** Figuras TikZ (portada, cadena de preprocesado, diagrama de bloques de H1/H2), diapositivas, bibliografía, `quarto render` con `_freeze/`, pruebas de navegador, `estado` de la cabecera.

## Funciones de Resonancia.jl 0.9.0
**Hecho (01-11-2026, tests en verde):**
- `ventanas.jl`: `perdida_escalonamiento`, `ancho_banda_3db`, `nivel_lobulo_lateral`, `correlacion_solape`, `varianza_welch`. Ya existían `ventana`, `ganancia_coherente` y `ancho_banda_ruido` (ENBW).
- `preprocesado.jl`: `quitar_tendencia(x, grado)` (grado 0 = offset) e `interpolar_uniforme(t, x, fs)` (remuestreo a rejilla uniforme, marca los huecos).
- `integracion.jl`: `integrar_trapecio`, `integrar_frecuencia(x, fs; fcorte, orden)` (aceleración → velocidad → desplazamiento, descartando por debajo de `fcorte`), `snr_db`, `snr_banda`, `rms_ruido_banda`.
- `cruzado.jl`: `espectros_cruzados`, `coherencia`, `frf_h1`, `frf_h2`, `estimar_frf` (convención `Gxy = conj(X)·Y`, `H1 = Gxy/Gxx`, `H2 = Gyy/conj(Gxy)`, `H1/H2 = γ²`) y `espectrograma` (su promedio temporal es `psd_welch`).
- `filtros.jl`: tipos `FIR` e `IIR` (cascada de secciones de segundo orden); `filtro_fir` (método de la ventana: pasabajos, pasaaltos, pasabanda, rechazabanda), `filtro_butterworth` (bilineal con *prewarping*, los mismos cuatro tipos), `respuesta_frecuencia`, `retardo_grupo` (analítico), `filtrar` (causal; `compensar=true` en FIR), `filtrar_fase_cero` (adelante-atrás con reflexión impar y estado estacionario) y `diezmar` (antialiasing FIR de fase cero). Sin dependencias.
- `psd_welch` admite `ventana=` (por defecto `:hann`, sin cambiar los resultados anteriores).
- Valores de referencia comprobados (N = 256, ventanas periódicas): pérdida por escalonamiento 3,92 / 1,42 / 1,75 / 1,10 / 0,01 dB y lóbulo lateral −13,3 / −31,5 / −42,7 / −58,1 / < −80 dB para rectangular, Hann, Hamming, Blackman y flat-top. El 1,78 dB de Hamming de la bibliografía clásica corresponde a otra definición de la ventana.

**Decisión:** la detección de huecos, tramos planos y atípicos (Hampel, MAD) es limpieza de datos y ya está en J2.3 (con código propio de la página). M4.3 la enlaza y solo trata lo propio de la señal: offset, tendencia, remuestreo y el efecto espectral de huecos y picos. No se duplica en el paquete.

**Pendiente en el paquete:**
- Wavelets (solo introducción, ampliación): decidir si hace falta función (p. ej. la transformada continua con el *wavelet* de Morlet) o basta una simulación.
- Ya existían y se reutilizan: `ventana`, `psd_welch`, `buscar_picos`, `correlacion_cruzada`, `hilbert_analitica`.

## Material de NeuroMIND (consultado el 01-11-2026)
Fuente: `~/Desktop/Typst_template/NeuroMIND · Capítulo 6 Filtrado — propuesta editorial.pdf` (maqueta de 4 páginas del capítulo «Filtrado», de Castro Triguero y Galvao Carmona, IMIBIC · UCO). El proyecto Quarto de NeuroMIND, con el resto del capítulo y sus scripts, **no está en este equipo**.
- **Usado:** los valores numéricos de la Tabla 6.1 (paso alto Butterworth de orden 4, fc = 0,5 Hz, fs = 500 Hz: ganancia y fase con una y dos pasadas, contrastados allí con `freqresp` de DSP.jl) como referencia de prueba de `filtro_butterworth`; coinciden con nuestra implementación en ganancia (±0,006 dB) y fase (±0,05°). También las ideas didácticas: orden de diseño frente a orden efectivo, `filt` frente a `filtfilt` (|H|², no para tiempo real), qué significa realmente la frecuencia de corte, polos en el semicírculo y *prewarping*, y la cascada con orden fijo de etapas.
- **No usado y no reutilizable sin más:** (1) las figuras 6.18 y 6.20 y la tabla 6.6 son EEG real de un participante de la cohorte (`sub-M05`): **no publicables**; (2) el texto y las imágenes del capítulo: antes de reutilizarlos hay que confirmar la licencia y el permiso de la coautoría (A. Galvao Carmona) y su compatibilidad con CC BY-SA 4.0. Mientras tanto se redacta con palabras propias y las figuras se rehacen (TikZ/Makie) con señales de estructuras.
- El capítulo trabaja con EEG (µV, 500 Hz); aquí los ejemplos son vibraciones de estructuras (Torroja a 100 Hz, Palma a 512 Hz).

## Datos (comprobado el 01-11-2026)
- **Registros reales:** Torroja (100 Hz, vertical, g) y Palma del Río (512 Hz, g), los de M3. Sirven para preprocesado, integración, ruido y espectrograma.
- **H1/H2 no se puede hacer con datos reales del curso:** ningún registro tiene entrada medida (Palma `2014-06-19-modal` solo trae fotos; el edificio sintético solo guarda aceleraciones). Se genera en la página un par excitación-respuesta con `edificio_tres_plantas` (semilla fija) y se valida contra la FRF teórica calculada con M, C y K.

## Pendiente
- Todo lo anterior salvo `temario.yml` y este registro.
- Las duraciones por tema de `temario.yml` son una reserva inicial (95 + 130 min, igual que M3); se revisan al terminar la redacción.
- Remisiones desde M3 (recuadro «Qué queda para M4») y el ejercicio `m2-5-duracion`: se tratan en la rama `m3-lav`, no aquí.
