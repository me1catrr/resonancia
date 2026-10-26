"""Pruebas de tablas.py frente a los valores de Julia (página J1.6).

Ejecutar desde la raíz: ``uv run pytest julia/j1-esencial/j1-6-datos/python``
"""
from pathlib import Path

import pytest

import tablas as tb

RAIZ = Path(__file__).resolve().parents[4]
EDIFICIO = RAIZ / "datos" / "sinteticos" / "edificio-3-plantas" / "escenario_A.csv"
MANTENIMIENTO = RAIZ / "datos" / "sinteticos" / "curso-claude" / "c_mantenimiento.csv"


def test_forma_y_columnas_del_acelerometro():
    df = tb.leer_acelerometro(EDIFICIO)
    assert df.shape == (60000, 4)
    assert list(df.columns) == ["tiempo_s", "a1_ms2", "a2_ms2", "a3_ms2"]
    assert df["tiempo_s"].iloc[1] - df["tiempo_s"].iloc[0] == pytest.approx(0.01)


def test_rms_frente_a_julia():
    df = tb.leer_acelerometro(EDIFICIO)
    r = tb.rms_por_canal(df, ["a1_ms2", "a2_ms2", "a3_ms2"])
    assert r["a1_ms2"] == pytest.approx(0.23363678965232265, rel=1e-10)
    assert r["a2_ms2"] == pytest.approx(0.22441468726507216, rel=1e-10)
    assert r["a3_ms2"] == pytest.approx(0.19811461124275892, rel=1e-10)


def test_resumen_mantenimiento_frente_a_julia():
    r = tb.resumen_mantenimiento(MANTENIMIENTO)
    assert r["ordenes"] == 180
    assert r["ausentes"] == 3
    assert r["n_correctivas"] == 50
    assert r["coste_medio"] == pytest.approx(940.9415819209041, rel=1e-12)
    assert r["coste_medio_correctivo"] == pytest.approx(2960.654199999999, rel=1e-12)
