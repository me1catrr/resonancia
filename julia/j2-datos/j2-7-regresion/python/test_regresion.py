"""Pruebas de regresion.py: recuperación de parámetros e identidades algebraicas (página J2.7).

Ejecutar desde la raíz: ``uv run pytest julia/j2-datos/j2-7-regresion/python``
"""
import numpy as np
import pytest
from scipy import stats

import regresion as rg


@pytest.fixture(scope="module")
def datos():
    return rg.generar()


def test_pendiente_lineal_recuperada(datos):
    _, T, _, f = datos
    a = rg.ajustar(np.column_stack([np.ones_like(T), T]), f)
    # Julia: pendiente −0,00386 Hz/°C (EE 0,0001), R² = 0,79
    assert a["beta"][1] == pytest.approx(-0.00386, abs=0.0004)
    assert 0.75 < a["r2"] < 0.83


def test_modelo_cuadratico_mejora(datos):
    _, T, _, f = datos
    X1 = np.column_stack([np.ones_like(T), T])
    X2 = np.column_stack([np.ones_like(T), T, (T - 15) ** 2])
    a1, a2 = rg.ajustar(X1, f), rg.ajustar(X2, f)
    assert a2["sigma"] < a1["sigma"]
    assert a2["r2"] > a1["r2"] + 0.05
    assert a2["beta"][2] == pytest.approx(0.000173, abs=5e-5)


def test_ajuste_coincide_con_scipy(datos):
    _, T, _, f = datos
    a = rg.ajustar(np.column_stack([np.ones_like(T), T]), f)
    r = stats.linregress(T, f)
    assert a["beta"] == pytest.approx([r.intercept, r.slope], rel=1e-9)
    assert a["se"][1] == pytest.approx(r.stderr, rel=1e-9)


def test_traza_del_apalancamiento_es_el_numero_de_parametros(datos):
    _, T, _, _ = datos
    X = np.column_stack([np.ones_like(T), T, (T - 15) ** 2])
    h = rg.apalancamiento(X)
    assert h.sum() == pytest.approx(3.0)
    assert (h > 0).all() and (h < 1).all()


def test_ninguna_observacion_es_muy_influyente(datos):
    _, T, _, f = datos
    X = np.column_stack([np.ones_like(T), T, (T - 15) ** 2])
    assert rg.cook(X, f).max() < 0.5
