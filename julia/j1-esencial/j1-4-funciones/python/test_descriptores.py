"""Pruebas de descriptores.py frente a los valores de Julia (página J1.4) y a SciPy.

Ejecutar desde la raíz: ``uv run pytest julia/j1-esencial/j1-4-funciones/python``
"""
import numpy as np
import pytest
from scipy import stats

import descriptores as ds


def senal_limpia(fs=100.0, T=10.0):
    t = np.arange(int(fs * T)) / fs
    return np.sin(2 * np.pi * 2.5 * t) + 0.4 * np.sin(2 * np.pi * 7.0 * t)


def test_descriptores_frente_a_julia():
    d = ds.descriptores(senal_limpia())
    assert d["rms"] == pytest.approx(0.7615773105863908, rel=1e-12)
    assert d["pico"] == pytest.approx(1.3845342211209313, rel=1e-12)
    assert d["cresta"] == pytest.approx(1.8179824974760384, rel=1e-12)
    assert d["curtosis"] == pytest.approx(1.8567181926278256, rel=1e-10)


def test_curtosis_frente_a_scipy():
    x = np.random.default_rng(0).normal(size=5000)
    assert ds.curtosis(x) == pytest.approx(stats.kurtosis(x, fisher=False), rel=1e-12)


def test_senoide_pura():
    t = np.arange(1000) / 100.0
    x = np.sin(2 * np.pi * 2.5 * t)
    assert ds.cresta(x) == pytest.approx(np.sqrt(2), rel=1e-3)   # cresta de una senoide
    assert ds.curtosis(x) == pytest.approx(1.5, rel=1e-3)        # curtosis de una senoide


def test_quitar_media():
    x = np.array([5.0, 6.0, 7.0])
    assert ds.descriptores(x)["rms"] == pytest.approx(np.sqrt(2 / 3))
    assert ds.descriptores(x, quitar_media=False)["rms"] == pytest.approx(np.sqrt(110 / 3))
