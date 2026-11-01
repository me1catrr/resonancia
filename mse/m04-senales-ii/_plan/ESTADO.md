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

## Funciones candidatas de Resonancia.jl 0.9.0
- Ventanas: propiedades (ENBW, ganancia coherente, pérdida por escalonamiento, solape correlacionado). Ya existe `ventana`.
- Preprocesado: quitar offset y tendencia, rellenar huecos, detectar picos espurios, remuestreo.
- Integración: temporal y en el dominio de la frecuencia, con frecuencia de corte.
- Ruido: SNR en banda.
- Espectros cruzados: densidad espectral cruzada, coherencia, `H1` y `H2`.
- Tiempo-frecuencia: espectrograma.
- Ya existen y se reutilizan: `ventana`, `psd_welch`, `buscar_picos`, `correlacion_cruzada`, `hilbert_analitica`.

## Datos (comprobado el 01-11-2026)
- **Registros reales:** Torroja (100 Hz, vertical, g) y Palma del Río (512 Hz, g), los de M3. Sirven para preprocesado, integración, ruido y espectrograma.
- **H1/H2 no se puede hacer con datos reales del curso:** ningún registro tiene entrada medida (Palma `2014-06-19-modal` solo trae fotos; el edificio sintético solo guarda aceleraciones). Se genera en la página un par excitación-respuesta con `edificio_tres_plantas` (semilla fija) y se valida contra la FRF teórica calculada con M, C y K.

## Pendiente
- Todo lo anterior salvo `temario.yml` y este registro.
- Las duraciones por tema de `temario.yml` son una reserva inicial (95 + 130 min, igual que M3); se revisan al terminar la redacción.
- Remisiones desde M3 (recuadro «Qué queda para M4») y el ejercicio `m2-5-duracion`: se tratan en la rama `m3-lav`, no aquí.
