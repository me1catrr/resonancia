"""Genera un informe Quarto (.qmd, sin código ejecutable) con el resultado de validar.py.

Uso: python3 informe.py validacion.json informe.qmd
El informe solo contiene texto y una tabla; se renderiza después con `quarto render informe.qmd`.
"""
import json
import sys
from pathlib import Path


def construir(v):
    filas = "\n".join(f"| {c} | {n} |" for c, n in v["ausentes"].items())
    total_aus = sum(v["ausentes"].values())
    return f"""---
title: "Validación de {v['fichero']}"
lang: es
format:
  html:
    embed-resources: true
---

## Resumen

El fichero `{v['fichero']}` tiene **{v['filas']} filas** y {len(v['columnas'])} columnas
({', '.join(v['columnas'])}). Se han encontrado **{total_aus} valores ausentes** y
**{v['duplicadas']} filas duplicadas**.

## Ausentes por columna {{#tbl-ausentes}}

| Columna | Ausentes |
|---|---|
{filas}

: Valores ausentes por columna. {{#tbl-ausentes}}

## Qué no se ha comprobado

Este informe solo cuenta ausentes y duplicados exactos. **No** valida rangos, unidades ni formatos de fecha.
"""


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        sys.exit(1)
    v = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    Path(sys.argv[2]).write_text(construir(v), encoding="utf-8")
    print(f"Escrito {sys.argv[2]}")
