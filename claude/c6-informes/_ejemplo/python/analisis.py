"""Análisis de los casos A-E de la vía C con pandas y numpy (datos sintéticos).

Equivale a ``julia/analisis.jl``. Uso: ``uv run python analisis.py`` desde esta carpeta.
"""
from pathlib import Path

import numpy as np
import pandas as pd

DATOS = Path(__file__).resolve().parents[4] / "datos" / "sinteticos" / "curso-claude"


def cargar(nombre, **kw):
    return pd.read_csv(DATOS / nombre, **kw)


def validar_ventas(df):
    """Recuento de filas, duplicadas y ventas ausentes."""
    return {"filas": len(df), "duplicadas": int(df.duplicated().sum()), "ausentes": int(df["ventas_eur"].isna().sum())}


def ventas_por_region(df):
    """Totales de ventas por región ignorando duplicados y ausentes."""
    limpio = df.drop_duplicates().dropna(subset=["ventas_eur"])
    return (limpio.groupby("region", sort=False)["ventas_eur"].agg(total_eur="sum", meses="count").reset_index())


def parsear_fechas(serie):
    """Fechas ISO o dd/mm/aaaa; las que no se reconocen quedan como NaT."""
    iso = pd.to_datetime(serie, format="%Y-%m-%d", errors="coerce")
    esp = pd.to_datetime(serie, format="%d/%m/%Y", errors="coerce")
    return iso.fillna(esp)


def huecos(v):
    """Pares (primero, último) de índices desde 1 de cada hueco de valores ausentes."""
    ausente = pd.isna(np.asarray(v, dtype=float))
    res, i, n = [], 0, len(ausente)
    while i < n:
        if ausente[i]:
            j = i
            while j + 1 < n and ausente[j + 1]:
                j += 1
            res.append((i + 1, j + 1))
            i = j + 1
        else:
            i += 1
    return res


def espectro(x, fs):
    """Espectro de amplitud de un solo lado con ventana de Hann (misma normalización que Julia)."""
    x = np.asarray(x, dtype=float)
    n = len(x)
    v = 0.5 - 0.5 * np.cos(2 * np.pi * np.arange(n) / n)
    y = np.fft.rfft((x - x.mean()) * v)
    return np.arange(n // 2 + 1) * fs / n, np.abs(y) * 2 / v.sum()


if __name__ == "__main__":
    a = cargar("a_ventas.csv")
    print("A", validar_ventas(a))
    print(ventas_por_region(a))
    b = cargar("b_absentismo.csv")
    f = parsear_fechas(b["fecha"])
    print("B filas", len(b), "dd/mm/aaaa", int(b["fecha"].str.contains("/").sum()), "no reconocidas", int(f.isna().sum()), "dias", int(b["dias_ausencia"].sum()))
    c = cargar("c_mantenimiento.csv")
    print(c.groupby("tipo").agg(ordenes=("orden", "count"), horas=("horas_parada", "sum"), coste=("coste_eur", "sum")))
    d = cargar("d_ambiental.csv")
    print("D huecos", huecos(d["temperatura_C"]), "media", round(d["temperatura_C"].mean(), 2))
    e = cargar("e_vibracion.csv")
    fr, A = espectro(e["aceleracion_m_s2"], 200.0)
    i = int(np.argmax(A))
    print("E pico", round(fr[i], 3), round(A[i], 4))
