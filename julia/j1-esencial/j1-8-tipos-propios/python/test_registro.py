"""Pruebas de registro.py frente a los valores de Julia (página J1.8).

Ejecutar desde la raíz: ``uv run pytest julia/j1-esencial/j1-8-tipos-propios/python``
"""
from dataclasses import FrozenInstanceError
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

import registro as rg

RAIZ = Path(__file__).resolve().parents[4]
CSV = RAIZ / "datos" / "sinteticos" / "edificio-3-plantas" / "escenario_A.csv"


@pytest.fixture(scope="module")
def r():
    a = pd.read_csv(CSV, sep=";")
    return rg.Registro(a.iloc[:, 1:4].to_numpy(), 100.0, ("planta 1", "planta 2", "planta 3"))


def test_tamano_y_rms_frente_a_julia(r):
    assert (r.muestras, r.duracion) == (60000, 600.0)
    assert rg.rms(r) == pytest.approx([0.23363678965232265, 0.22441468726507216, 0.19811461124275892], rel=1e-10)


def test_indexacion_por_nombre_y_por_numero(r):
    assert np.array_equal(r["planta 3"], r[2])


def test_recortar(r):
    r10 = rg.recortar(r, 0, 10)
    assert (r10.muestras, r10.duracion) == (1000, 10.0)
    assert rg.rms(r10) == pytest.approx([0.2775268544655742, 0.2300313249159123, 0.2130504787554114], rel=1e-10)


def test_validacion():
    with pytest.raises(ValueError, match="fs debe ser positiva"):
        rg.Registro(np.zeros((5, 3)), -1.0, ("a", "b", "c"))
    with pytest.raises(ValueError, match="3 columnas y 2 nombres"):
        rg.Registro(np.zeros((5, 3)), 100.0, ("a", "b"))


def test_inmutable(r):
    with pytest.raises(FrozenInstanceError):
        r.fs = 5.0


def test_despacho_por_tipo(r):
    assert isinstance(rg.rms([3.0, 4.0]), float)
    assert isinstance(rg.rms(r), list)
