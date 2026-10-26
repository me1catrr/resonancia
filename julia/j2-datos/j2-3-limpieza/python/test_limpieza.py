"""Pruebas de limpieza.py frente a los valores de Julia (página J2.3).

Ejecutar desde la raíz: ``uv run pytest julia/j2-datos/j2-3-limpieza/python``
"""
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

import limpieza as lp

RAIZ = Path(__file__).resolve().parents[4]
CSV = RAIZ / "datos" / "sinteticos" / "curso-claude" / "e_vibracion.csv"


@pytest.fixture(scope="module")
def datos():
    x0 = pd.read_csv(CSV)["aceleracion_m_s2"].to_numpy()
    return x0, lp.inyectar_defectos(x0)


def test_rango_fisico_encuentra_los_seis_picos(datos):
    x0, x = datos
    assert len(lp.fuera_de_rango(x0, 3.0)) == 0
    assert list(lp.fuera_de_rango(x, 3.0) + 1) == lp.POSICIONES_PICOS


def test_zscore_robusto_da_falsos_positivos(datos):
    _, x = datos
    z = lp.z_mad(x)
    assert int((np.abs(z) > 8).sum()) == 13
    assert int((np.abs(z) > 5).sum()) == 81


def test_hampel_frente_a_julia(datos):
    _, x = datos
    h = lp.hampel(x)
    assert len(h) == 27
    assert set(p - 1 for p in lp.POSICIONES_PICOS) <= set(h)


def test_tramo_plano(datos):
    x0, x = datos
    assert lp.tramos_planos(x) == [(1499, 1538)]
    assert lp.tramos_planos(x0) == []


def test_salto_de_nivel(datos):
    _, x = datos
    k, d = lp.salto_por_medianas(x)
    assert k == 15                       # ventana 16 (desde 1), a partir de la muestra 3001
    assert d == pytest.approx(0.346, abs=5e-4)
