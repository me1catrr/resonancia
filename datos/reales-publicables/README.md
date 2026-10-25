# Datos reales publicables

Mediciones reales en puentes que se publican con la licencia **CC BY 4.0**. Al usarlas hay que citar el artículo asociado a cada estructura.

| Estructura | Carpeta | Artículo que hay que citar |
|---|---|---|
| Puente de Eduardo Torroja | [`torroja-puente/`](torroja-puente/) | Pachón, P., Castro, R., García-Macías, E., Compán, V. y Puertas, E. (2018). *E. Torroja's bridge: Tailored experimental setup for SHM of a historical bridge with a reduced number of sensors*. Engineering Structures, 162, 11–21. <https://doi.org/10.1016/j.engstruct.2018.02.035> |
| Puente de Palma del Río | [`palma-del-rio-puente/`](palma-del-rio-puente/) | Infantes, M., Castro-Triguero, R., Sola-Guirado, R. R., Bullejos, D. y Friswell, M. I. (2022). *A feasibility study on piezoelectric energy harvesting from the operational vibration of a highway bridge*. Advances in Structural Engineering, 26(2), 205–217. <https://doi.org/10.1177/13694332221120129> |

## Organización

```text
<estructura>/<AAAA-MM-DD>-<campaña>/
├── crudos/      registros tal como salieron del equipo (o su tramo inicial)
├── extractos/   tramos recortados de registros más largos
├── docs/        notas de ensayo
├── modos/       animaciones de formas modales (Torroja)
├── fotos/       selección, reducida a 1600 px y sin metadatos EXIF
└── campana.meta.toml   ficha: origen, sensor, fs, unidades, licencia
```

Cada estructura tiene además su ficha (`torroja.meta.toml`, `palma.meta.toml`). Nombres sin espacios ni acentos.

## Qué se publica y qué no

- Se publica lo que pesa menos de 50 MB por fichero, para no pasar de los límites de GitHub.
- De los registros largos solo está el **tramo inicial** (indicado en cada ficha). Los registros completos se publicarán en Zenodo con DOI (pendiente).
- No se publican informes, cuadernos de campo ni documentos Word: solo se usa la información que contienen.
- No se publican los canales de los captadores piezoeléctricos (*energy harvesters*) de Palma del Río.
- Las fotos son de autoría propia (Rafael Castro Triguero), una selección sin personas identificables.

## Comprobación

`julia --project=. scripts/comprobar_datos.jl` verifica fichas, tamaño, formatos y metadatos de las fotos.
