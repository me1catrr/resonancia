"""Pruebas de tipos.py frente a los valores calculados en Julia (página J1.3).

Ejecutar desde la raíz: ``uv run pytest julia/j1-esencial/j1-3-tipos/python``
"""
import numpy as np
import pytest

import tipos as tp


def test_acumulacion_igual_que_julia():
    # En Julia: acumula(0.01, 1000) == 9.999999999999831
    assert tp.acumula(0.01, 1000) == 9.999999999999831
    assert tp.acumula(0.1, 100) == 9.99999999999998


def test_suma_no_asociativa():
    assert 0.1 + 0.2 != 0.3
    assert 0.1 + 0.2 == pytest.approx(0.3, abs=1e-15)


def test_epsilon_de_maquina():
    assert np.finfo(np.float64).eps == 2.220446049250313e-16
    assert np.finfo(np.float32).eps == pytest.approx(1.1920929e-7)


def test_cuenta_y_primero_sobre_senal_limpia():
    x = tp.senal_limpia()
    assert tp.cuenta(x, 1.2) == 110                      # Julia: count(abs.(l) .> 1.2)
    assert tp.primero(x, 1.2) == 46                      # Julia: findfirst = 47 (desde 1)
    assert max(abs(x)) == pytest.approx(1.3845342211209313, rel=1e-12)


def test_primero_sin_resultado():
    assert tp.primero([0.1, -0.2], 1.0) is None
