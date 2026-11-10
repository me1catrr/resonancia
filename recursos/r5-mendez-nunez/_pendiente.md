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
2. **Plataforma de MOVE** (Deck Platform; la sesión la inicia el responsable). Revisada
   el 10-11-2026, solo lectura. Ya está en la página: geometría, planta de sensores
   (`fig/planta-sensores.tex`), configuración de los acelerómetros y fases. Notas:
   - La «pasarela junto a P1» de la nota anterior era el *gateway*.
   - Asignación de códigos a posiciones: deducida de las etiquetas del plano del panel,
     que están desplazadas a la derecha de los puntos verdes del dibujo de fondo
     (centros de vano). Confirmarla con quien hizo la instalación.
   - Bordes A (arriba en el plano, rótulo «Motril») y B: falta saber cuál es el norte.
   - Configuración Axel (versión 3.0): sync, cadencia 1 h, 80 Hz, 0,125 mg / 4096 mg-pp,
     umbral de activación 50 mg (no aplica en sync), alarma por correo 256 mg-pp (BBD22
     sin alarma). Deck (versión 2.0): 0,012 mm / 3 mm-pp, umbral 0,576 mm.
     Inclinómetros: cadencia 2 min, compensación de offset hecha, posición por vano vacía.
   - Últimas transmisiones (formato día/mes, por confirmar): Deck 12-04-2024 y
     08-05-2024; Axel entre 10-08-2025 y 10-09-2025; inclinómetros y gateway
     AC…20:32 activos hoy; el otro gateway, parado desde el 25-09-2023.
   - Ejes: Z es el vertical (el que más vibra en el evento de 89CAA). X/Y sin documentar.
   - En la plataforma hay, por evento, temperatura del nodo y valor pico a pico, y
     «Download Summary.csv». No se ha descargado nada. No publicar cifras medidas
     (frecuencias, temperaturas, picos) hasta que se reorganice Zenodo.
   - No publicar: URL de la plataforma, usuario, MAC de los gateways ni umbrales de alarma.

   Falta: modelos comerciales de cada sensor, orientación norte/sur y de los ejes X/Y,
   y si se publicarán los datos posteriores a Zenodo (acelerómetros hasta septiembre de
   2025) y la serie de los inclinómetros, que siguen midiendo.
3. **Correo a los compañeros.** Se redactó el 09-11-2026; lo envía el responsable. Pide
   fotos, la geometría, la planta de sensores, la configuración, la comparación MEMS
   frente a piezo, la temperatura, el conjunto VibroSC-DAE, la agrupación en Zenodo y
   las publicaciones con DOI. Si aún no ha salido, añadir: confirmar la planta de
   `fig/planta-sensores.svg`, el norte, los ejes X/Y, los modelos de sensor, los datos de
   2025, las temperaturas por evento y la serie de los inclinómetros.
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
