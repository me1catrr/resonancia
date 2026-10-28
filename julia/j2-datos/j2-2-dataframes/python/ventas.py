"""Versión Python de J2.2: limpieza de ventas, ciclo diario y huecos con pandas.

Equivale a ``unique``, ``groupby``/``combine`` y ``floor``+``groupby`` de DataFrames.jl.
"""
import pandas as pd


def ventas_limpias(ruta):
    """Lee el CSV de ventas y elimina las filas duplicadas exactas."""
    return pd.read_csv(ruta, parse_dates=["fecha"]).drop_duplicates().reset_index(drop=True)


def total_por_region(df):
    """Ventas totales por región, ignorando los ausentes (``sum`` salta los ``NaN``)."""
    return df.groupby("region")["ventas_eur"].sum()


def ciclo_diario(ruta):
    """Temperatura media por hora del día (0–23), ignorando los ausentes."""
    d = pd.read_csv(ruta, parse_dates=["instante"])
    return d.groupby(d["instante"].dt.hour)["temperatura_C"].mean()


def muestras_por_hora(ruta):
    """Número de muestras válidas de temperatura en cada hora natural."""
    d = pd.read_csv(ruta, parse_dates=["instante"]).set_index("instante")
    return d["temperatura_C"].resample("h").count()
