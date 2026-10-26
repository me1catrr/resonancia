"""Versión Python de J1.6: leer los CSV del curso con pandas y resumirlos.

Equivale a ``CSV.read`` + ``DataFrame`` + ``skipmissing`` en Julia.
"""
import pandas as pd


def leer_acelerometro(ruta):
    """Lee un CSV de aceleraciones con separador ``;``. Devuelve un ``DataFrame``."""
    return pd.read_csv(ruta, sep=";")


def rms_por_canal(df, columnas):
    """RMS de cada columna indicada."""
    return {c: float((df[c] ** 2).mean() ** 0.5) for c in columnas}


def resumen_mantenimiento(ruta):
    """Número de órdenes, ausentes y costes medios (los ausentes se ignoran)."""
    df = pd.read_csv(ruta, parse_dates=["fecha_apertura"])
    correctivas = df[(df["tipo"] == "correctivo") & df["coste_eur"].notna()]
    return {
        "ordenes": len(df),
        "ausentes": int(df["coste_eur"].isna().sum()),
        "coste_medio": float(df["coste_eur"].mean()),
        "coste_medio_correctivo": float(correctivas["coste_eur"].mean()),
        "n_correctivas": int((df["tipo"] == "correctivo").sum()),
    }
