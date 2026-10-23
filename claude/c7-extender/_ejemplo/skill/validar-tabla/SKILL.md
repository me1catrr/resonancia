---
name: validar-tabla
description: Valida una tabla de datos en CSV o Excel (filas, columnas, ausentes por columna, filas duplicadas) y genera un informe Quarto con el resultado, sin modificar el fichero. Úsala cuando el usuario pida revisar la calidad de unos indicadores antes de analizarlos.
argument-hint: [ruta/al/fichero.csv|xlsx]
---

Valida `$ARGUMENTS` **sin modificar el fichero original**.

1. Ejecuta `python3 ${CLAUDE_SKILL_DIR}/scripts/validar.py $ARGUMENTS > validacion.json`.
   Para `.xlsx` hace falta `openpyxl`: `uv run --with openpyxl python …`.
2. Si el script termina con código distinto de 0, explica el error y **no continúes**.
3. Ejecuta `python3 ${CLAUDE_SKILL_DIR}/scripts/informe.py validacion.json informe-validacion.qmd`.
4. Resume en una tabla: filas, columnas, ausentes por columna y duplicadas, y señala qué
   incidencias afectarían a un análisis. **No apliques ninguna corrección.**
5. Ofrece renderizar con `quarto render informe-validacion.qmd`, pero **no lo hagas sin que lo pida**.
6. Indica qué no has comprobado (rangos, unidades, formatos de fecha).

No abras ficheros fuera de la ruta indicada.
