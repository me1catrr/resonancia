"""Pruebas de senal.py frente al valor analítico y al calculado en Julia.

Ejecutar desde la raíz: ``uv run pytest julia/j1-esencial/j1-1-entorno/python``
"""
import numpy as np
import pytest

import senal as sg

# Calculado en la página de J1.1 con `sqrt(mean(abs2, x))`, N = 1000.
RMS_JULIA = 0.7615773105863908


def test_longitud_y_paso():
    t, x = sg.senal_dos_modos()
    assert len(t) == len(x) == 1000
    assert t[1] - t[0] == pytest.approx(0.01)


def test_rms_analitico():
    # Con periodos enteros, RMS² = (a1² + a2²)/2.
    _, x = sg.senal_dos_modos()
    assert sg.rms(x) == pytest.approx(np.sqrt((1.0**2 + 0.4**2) / 2), rel=1e-12)


def test_rms_frente_a_julia():
    _, x = sg.senal_dos_modos()
    assert sg.rms(x) == pytest.approx(RMS_JULIA, rel=1e-12)
