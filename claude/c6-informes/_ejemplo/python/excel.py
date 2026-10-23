"""Leer y escribir Excel con pandas y openpyxl (caso A). Equivale a julia/excel.jl."""
import pandas as pd

import analisis as an


def escribir_libro(ruta, df):
    """Libro con una hoja «resumen» (totales por región) y otra «validacion»."""
    val = pd.DataFrame([an.validar_ventas(df)])
    with pd.ExcelWriter(ruta, engine="openpyxl") as w:
        an.ventas_por_region(df).to_excel(w, sheet_name="resumen", index=False)
        val.to_excel(w, sheet_name="validacion", index=False)
    return ruta


def leer_hoja(ruta, hoja):
    return pd.read_excel(ruta, sheet_name=hoja, engine="openpyxl")
