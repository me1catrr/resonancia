"""Versión Python de J2.1: resumen diario de un registro ambiental y huella de un fichero.

Equivale al ``run_all.jl`` de la página: lee el CSV, ignora los ausentes y resume por día.
"""
import hashlib

import pandas as pd


def resumen_diario(ruta):
    """DataFrame con ``fecha``, ``n_validas``, ``media_C`` y ``max_C`` por día."""
    df = pd.read_csv(ruta, parse_dates=["instante"])
    df["fecha"] = df["instante"].dt.date
    g = df.groupby("fecha")["temperatura_C"]
    return pd.DataFrame(
        {"n_validas": g.count(), "media_C": g.mean(), "max_C": g.max()}
    ).reset_index()


def huella(ruta):
    """SHA-256 de un fichero, en hexadecimal."""
    h = hashlib.sha256()
    with open(ruta, "rb") as f:
        for bloque in iter(lambda: f.read(65536), b""):
            h.update(bloque)
    return h.hexdigest()
