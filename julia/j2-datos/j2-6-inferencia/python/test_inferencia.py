"""Pruebas de inferencia.py frente a los valores de Julia (página J2.6).

Ejecutar desde la raíz: ``uv run pytest julia/j2-datos/j2-6-inferencia/python``
"""
from pathlib import Path

import numpy as np
import pytest

import inferencia as inf

RAIZ = Path(__file__).resolve().parents[4]
BASE = RAIZ / "datos" / "sinteticos" / "edificio-3-plantas"


@pytest.fixture(scope="module")
def f3():
    return {e: inf.frecuencias_por_segmento(inf.cargar(e, BASE)) for e in "ABC"}


def test_welch_a_frente_a_b_y_c(f3):
    ab = inf.welch_t(f3["A"], f3["B"])
    assert ab["dif"] == pytest.approx(0.0439, abs=5e-4)
    assert ab["t"] == pytest.approx(2.86, abs=0.01)
    assert ab["p"] == pytest.approx(0.0104, abs=5e-4)
    assert ab["ic"] == pytest.approx((0.0117, 0.0762), abs=5e-4)
    ac = inf.welch_t(f3["A"], f3["C"])
    assert ac["t"] == pytest.approx(8.58, abs=0.01)
    assert ac["p"] < 1e-6


def test_tamano_de_efecto(f3):
    assert inf.d_cohen(f3["A"], f3["B"]) == pytest.approx(1.28, abs=0.01)
    assert inf.d_cohen(f3["A"], f3["C"]) == pytest.approx(3.84, abs=0.01)


def test_bootstrap_cubre_la_diferencia(f3):
    b = inf.bootstrap_dif(f3["A"], f3["C"])
    lo, hi = np.quantile(b, [0.025, 0.975])
    assert lo == pytest.approx(0.1123, abs=0.004) and hi == pytest.approx(0.1758, abs=0.004)


def test_tasa_de_falsos_positivos():
    from scipy import stats
    rng = np.random.default_rng(5)
    rech = np.mean([stats.ttest_ind(rng.standard_normal(10), rng.standard_normal(10), equal_var=False).pvalue < 0.05 for _ in range(4000)])
    assert rech == pytest.approx(0.05, abs=0.012)


def test_potencia_crece_con_n():
    assert inf.potencia(0.0221, 0.035, 10, repeticiones=1500) < inf.potencia(0.0221, 0.035, 80, repeticiones=1500)
