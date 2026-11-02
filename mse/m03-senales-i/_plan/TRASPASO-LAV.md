# Traspaso: actividad de la LAV Madrid–Sevilla en M3 (rama `m3-lav`)

Documento de trabajo (no se publica: la carpeta empieza por «_»). Lo escribe la sesión de M7 para que la sesión de M3 empiece sin contexto previo.

## Encargo del responsable
Crear en M3 una **actividad** sobre la línea de alta velocidad Madrid–Sevilla a partir de un capítulo de un libro de puentes ferroviarios (copia aportada por el responsable; **no entra en el repositorio** y no se copia texto ni figuras: resumen propio, cita con `@puentesferroviarios`). Después, un `quarto render` para ver el estado. Lo demás de este documento es el diseño ya acordado.

## Reparto
- Esta rama: solo `mse/m03-senales-i/` (y, si hace falta, `Resonancia.jl`).
- La sesión de M7 (rama aparte) toca `mse/m07-identificacion/` y, probablemente, `Resonancia.jl` (función de ajuste LSCF). **Conflicto probable: versión de `Resonancia.jl` y `Manifest.toml`.** Si añades funciones al paquete, no subas la versión sin avisar; se decide al fusionar.
- `recursos/bibliografia.bib` ya contiene las fichas nuevas (commit `3ed4a49`): `puentesferroviarios`, `chellini2008`, `peeters2006guadiana`, `peeters2004polymax`, `peeters2004procedure`, `peeters2004z24`, `heylen1997`.

## Diseño de la actividad (ampliación, 35 min, `### Actividad … {#lav}` antes de «Pídeselo a Claude»)
1. **Contexto, con palabras propias.** La línea nació para descongestionar el paso de Despeñaperros, con trazado nuevo y ancho UIC, y se llena de viaductos de hormigón. El catálogo da año de construcción 1992 para todas sus obras. Son unas treinta y cuatro.
2. **Tabla de cinco obras** (longitud, vanos y esquema, tomados del libro; la **luz media = longitud / vanos** es cálculo propio y supone vanos iguales): Guadalmez 798 m, 30, isostático → 26,6 m; Tajo 694 m, 17, isostático → 40,8 m; Ciudad Real 929 m, 33, isostático → 28,2 m; Guadiana 292 m, 6, hiperestático → 48,7 m; Churreletes 446 m, 11, hiperestático → 40,5 m.
3. **Escenario sintético, todo declarado como supuesto** (no son medidas de la línea ni del libro): vano de 26,6 m; modo de flexión de 4,0 Hz con ζ = 1,5 %; 11 cargas repetidas separadas 18 m; registro de 120 s a 200 Hz; paso del tren a los 40 s; ruido ambiental de 1 mg RMS; pico de 1,5 m/s² en el paso resonante.
4. **Pasos**: frecuencia de excitación v/d y velocidad resonante; elección de fs, duración, rango y bits; señal y RMS por segundo; descriptores y PSD por ventanas (ambiente, paso, todo) para ver que **la PSD de un transitorio depende de la ventana** (enlaza con el ejercicio `m3-1-tipo-camion`); interpretación con rúbrica.
5. **Código de referencia ya ejecutado y comprobado**: `lav_prototipo.jl` (misma carpeta). Usa nombres con prefijo `lav_` para no pisar `fs`, `x`, `d`, `t` del caso de Palma. La función `lav_modo` (respuesta exacta de un modo a una fuerza) es reutilizable: o se promueve a `Resonancia.jl` con docstring y test, o se declara local y se dice por qué.
6. **Falta la pestaña Python** (la convención del proyecto la pide): ponla en `python/` con un test, o deja anotado que queda pendiente.

## Cifras comprobadas en Julia (no las cambies sin recalcular)
| Cantidad | Valor |
|---|---|
| velocidad resonante f_n·d | 72,0 m/s = 259,2 km/h |
| frecuencia de excitación a 200 km/h | 3,09 Hz |
| 4.º armónico a la velocidad resonante | 16,0 Hz → fs mínima con margen 2,5 = 40 Hz |
| alias de 16 Hz muestreado a 25 Hz | 9,0 Hz |
| τ = 1/(ζ·ω_n) y anchura de media potencia 2ζ·f_n | 2,65 s y 0,12 Hz |
| Δf para 3 bins en esa anchura | 0,040 Hz → T = 25 s |
| pico, RMS fluctuante, cresta, curtosis (paso resonante) | 1,511 m/s², 0,1565 m/s², 9,7, 36,1 |
| pico, RMS fluctuante, cresta, curtosis (200 km/h) | 0,950 m/s², 0,0959 m/s², 9,9, 35,5 |
| ventana de ambiente (5–35 s): RMS fluct., cresta, curtosis | 0,0092 m/s², 3,4, 2,7 |
| ventana de paso (38–52 s): RMS fluct., cresta, curtosis | 0,4573 m/s², 3,3, 4,2 |
| pico de la PSD de Welch (nseg = 1024, Δf = 0,195 Hz): ambiente / paso / todo | 1,0e-4 / 0,72 / 0,067 (m/s²)²/Hz |
| bits con ±0,5 g para σ_e ≤ 0,1 mg (RMS ambiente 1 mg) | 12 bits (q = 0,244 mg, σ_e = 0,0705 mg); con 11 bits, σ_e = 0,141 mg |

Ejercicios previstos (respuesta, tolerancia): luz media del Guadalmez 26,6 m (1 %); velocidad resonante 259,2 km/h (1 %); fs mínima 40 Hz (0,5 %); bits mínimos 12 (abs:0.001); duración del segmento 25 s (1 %); una abierta con rúbrica.

## Casos reales de los artículos (callouts de unas pocas líneas; palabras propias)
- **M3.3, Sesia** (`@chellini2008`): rango de ±10 V para no saturar con el tren y 24 bits para no perder el ambiente; el artículo emula 16 bits redondeando los de 24. Cálculo propio: q = 20/2²⁴ V = 1,19 µV frente a 305 µV con 16 bits (razón 256, 48 dB). **La sensibilidad del sensor no consta**, así que no se convierte a g. Anécdota útil para M8: mezclar sensores capacitivos y piezoeléctricos dio un desfase de unos 10° a 3,6 Hz.
- **M3.4, Guadiana** (`@peeters2006guadiana`): registrado a 100 Hz, con modos esperados por debajo de 3 Hz; se filtra paso bajo y se diezma a 10 Hz. Lección: el filtro va **antes** de reducir fs.
- **M3.1, Guadiana**: 28 ensayos de 21 min a lo largo de dos días, con viento medio de 2, 9 y 14 m/s; cambió el nivel y también el «color» de la excitación, y un modo global de ~0,8 Hz identificado al principio desaparece después. Ejemplo de no estacionariedad a escala de días.
- **M3.6**: una viñeta sobre otros estimadores (correlograma con ventana exponencial en OMA, remite a M7).

## Avisos
- Hay que renderizar con `QUARTO_JULIA` apuntando a Julia 1.12.3 (la del `Manifest.toml`).
- No se publica nada ni se hace `push` sin petición explícita.
- `ESTADO.md` de esta carpeta aún dice «sin commits»; actualízalo al terminar.
