"""Valida una tabla CSV o XLSX: filas, columnas, ausentes por columna y filas duplicadas. Solo lee.

Uso: python3 validar.py fichero.csv|fichero.xlsx [hoja]
Salida: JSON en stdout. Códigos: 0 correcto, 2 fichero ausente, 3 tabla no válida, 4 falta openpyxl (XLSX).
"""
import csv
import json
import sys
from collections import Counter
from pathlib import Path


def leer_csv(ruta):
    with open(ruta, newline="", encoding="utf-8") as f:
        return [fila for fila in csv.reader(f)]


def leer_xlsx(ruta, hoja=None):
    import openpyxl  # dependencia opcional: solo para .xlsx
    libro = openpyxl.load_workbook(ruta, read_only=True, data_only=True)   # data_only: valores guardados, no fórmulas
    ws = libro[hoja] if hoja else libro.worksheets[0]
    return [["" if v is None else str(v) for v in fila] for fila in ws.iter_rows(values_only=True)]


def validar(ruta, hoja=None):
    ruta = Path(ruta)
    datos = leer_xlsx(ruta, hoja) if ruta.suffix.lower() == ".xlsx" else leer_csv(ruta)
    if not datos:
        raise ValueError("fichero vacío")
    cabecera, filas = datos[0], [f for f in datos[1:] if any(c != "" for c in f)]
    if any(len(f) != len(cabecera) for f in filas):
        raise ValueError("filas con distinto número de columnas que la cabecera")
    ausentes = {c: sum(1 for f in filas if f[i] == "") for i, c in enumerate(cabecera)}
    repetidas = sum(n - 1 for n in Counter(map(tuple, filas)).values() if n > 1)
    return {"fichero": ruta.name, "filas": len(filas), "columnas": cabecera, "ausentes": ausentes, "duplicadas": repetidas}


if __name__ == "__main__":
    if len(sys.argv) not in (2, 3):
        print(__doc__, file=sys.stderr)
        sys.exit(1)
    ruta = Path(sys.argv[1])
    if not ruta.is_file():
        print(f"ERROR: no existe {ruta}", file=sys.stderr)
        sys.exit(2)
    try:
        print(json.dumps(validar(ruta, sys.argv[2] if len(sys.argv) == 3 else None), ensure_ascii=False, indent=2))
    except ImportError:
        print("ERROR: para leer .xlsx hace falta openpyxl (uv run --with openpyxl python validar.py …)", file=sys.stderr)
        sys.exit(4)
    except (ValueError, UnicodeDecodeError, csv.Error, KeyError) as e:
        print(f"ERROR: tabla no válida: {e}", file=sys.stderr)
        sys.exit(3)
