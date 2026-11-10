# R5 · Notas de trabajo (no se publica)

Estado a 10-11-2026. La página está publicada con la ficha, el proyecto, el puente, la
instalación, el formato de los registros y la caja «Registros en reorganización».

## Pendiente

1. **Fotos de la instalación.** No están en la carpeta del proyecto BRIDGEXT. Cuando lleguen,
   con autor y fecha y autorizadas con CC BY 4.0:
   `datos/reales-publicables/mendez-nunez-puente/<AAAA-MM-DD>-instalacion/fotos/`
   con su `campana.meta.toml` y `mendez-nunez.meta.toml`. Hay que reducirlas a 1600 px,
   quitarles el EXIF y el GPS, y pasar `scripts/comprobar_datos.jl`. Después, sustituir la
   caja «Fotos de la instalación» por la galería `#fig-instalacion`.
2. **Plataforma de MOVE** (Deck Platform, la inicia el responsable). Una captura del panel
   muestra lo siguiente, sin confirmar todavía:
   - 5 vanos de 2100, 2500, 3500, 2500 y 2100. ¿En cm? Serían 127 m. Pilas P1–P4,
     sentido Motril.
   - Tablero de canto variable.
   - 8 marcas «Axel» (los 8 nodos de Zenodo), 3 inclinómetros («Tilt») y 2 sensores
     «Deck», uno con el código 1E9B3. La pasarela está junto a P1.

   Falta asociar cada marca a su código (89CAA, BBD22…) y sacar de allí la orientación de
   los ejes, la configuración de adquisición (eventos de 8192 muestras a 80 Hz: ¿por
   horario o por umbral?), los modelos de sensor y las fechas de alta y baja. Con eso:
   una figura TikZ propia con la planta de sensores (no la captura) y completar la ficha
   y «Qué no dicen estos datos».
3. **Correo a los compañeros.** Se redactó el 09-11-2026; lo envía el responsable. Pide
   fotos, la geometría, la planta de sensores, la configuración, la comparación MEMS
   frente a piezo, la temperatura, el conjunto VibroSC-DAE, la agrupación en Zenodo y
   las publicaciones con DOI.
4. **Fase 2, cuando se agrupen los registros de Zenodo.** Sustituir la caja «en
   reorganización» por la tabla de registros (nodo o grupo, periodo, DOI, tamaño). Añadir
   un `@dataset` por registro y los artículos ligados directamente a BRIDGEXT, con DOI.
   Rellenar las filas «DOI y publicaciones» y «Cómo citar». Sin infraestructura nueva.

## Regla propuesta para PULSO (sin aplicar)

`CLAUDE.md` de PULSO, cuando exista el repositorio:

```markdown
## Recursos de datos reales
Los casos reales (puentes, campañas, registros) tienen su ficha canónica en RESONANCIA
(https://me1catrr.github.io/resonancia/recursos/). PULSO no crea fichas, inventarios,
galerías ni copias de esos datos: cuando un capítulo usa un caso, enlaza a su unidad R
(por ejemplo, R5 para Méndez Núñez) y se centra en lo suyo: sensores, configuración y
adquisición. Se admiten ejemplos mínimos o resultados derivados, citando y enlazando el
recurso R. Si falta o está mal un metadato, se corrige en RESONANCIA, no aquí.
```

## Datos comprobados (09-11-2026)

- Comunidad Zenodo `ugr_bridges`: 243 registros, CC BY 4.0. 239 son de monitorización
  continua (~21 500 ficheros, ~3,8 GB); solo 94 tienen los 96 ficheros de una ventana
  completa.
- CSV de muestra (registro 10.5281/zenodo.13310160): cabecera
  `Device,X Acc (g),Y Acc (g),Z Acc (g)`, 8192 muestras (102,4 s a 80 Hz), sin columna de
  tiempo, media casi nula y escalón de 0,125 mg. La descripción en Zenodo dice
  «0,125/4096», que no coincide con el escalón.
