"""Pruebas de ventas.py frente a los valores de Julia (página J2.2).

Ejecutar desde la raíz: ``uv run pytest julia/j2-datos/j2-2-dataframes/python``
"""
from pathlib import Path

import pytest

import ventas as vt

RAIZ = Path(__file__).resolve().parents[4]
BASE = RAIZ / "datos" / "sinteticos" / "curso-claude"


def test_duplicado_y_ausentes():
    crudo = vt.pd.read_csv(BASE / "a_ventas.csv")
    v = vt.ventas_limpias(BASE / "a_ventas.csv")
    assert (len(crudo), len(v)) == (109, 108)
    assert int(v["ventas_eur"].isna().sum()) == 5


def test_totales_por_region_frente_a_julia():
    t = vt.total_por_region(vt.ventas_limpias(BASE / "a_ventas.csv"))
    assert t["Norte"] == pytest.approx(1911061.69, abs=0.01)
    assert t["Centro"] == pytest.approx(2539781.72, abs=0.01)
    assert t["Sur"] == pytest.approx(1619001.97, abs=0.01)


def test_ciclo_diario_frente_a_julia():
    c = vt.ciclo_diario(BASE / "d_ambiental.csv")
    assert len(c) == 24
    assert int(c.idxmax()) == 15 and int(c.idxmin()) == 3
    assert c[15] == pytest.approx(26.9596, abs=5e-5)
    assert c.max() - c.min() == pytest.approx(9.94, abs=5e-3)


def test_horas_sin_datos():
    n = vt.muestras_por_hora(BASE / "d_ambiental.csv")
    assert len(n) == 336
    assert int((n == 0).sum()) == 2
    assert int((n < 6).sum()) == 3
