"""Pruebas de montecarlo.py frente a los valores de Julia (página J2.5).

Ejecutar desde la raíz: ``uv run pytest julia/j2-datos/j2-5-montecarlo/python``
"""
import numpy as np
import pytest
from scipy import stats

import montecarlo as mc


def test_frecuencias_nominales():
    assert mc.frecuencias(mc.M_NOM, mc.K_NOM) == pytest.approx([1.1048012767720872, 2.938675197033046, 4.390152904211614], rel=1e-12)


def test_sigma_lineal_frente_a_julia():
    s, _ = mc.sigma_lineal()
    assert s == pytest.approx([0.0191, 0.0551, 0.0798], abs=6e-5)


def test_monte_carlo_cerca_de_la_propagacion_lineal():
    F = mc.propagacion(n=5000)
    s, _ = mc.sigma_lineal()
    # el error relativo de una desviación típica con n muestras es ~ 1/sqrt(2n) = 1 %: se admite el 5 %
    assert F.std(axis=0, ddof=1) == pytest.approx(s, rel=0.05)
    assert F.mean(axis=0) == pytest.approx([1.1048, 2.9387, 4.3902], abs=0.005)


def test_cuantil_normal_y_clt():
    assert stats.norm.ppf(0.975) == pytest.approx(1.9599639845400576)
    rng = np.random.default_rng(2)
    medias = rng.exponential(1.0, size=(20000, 30)).mean(axis=1)
    assert medias.std(ddof=1) == pytest.approx(1 / np.sqrt(30), rel=0.03)
    assert stats.skew(medias) < stats.skew(rng.exponential(1.0, 20000)) / 3
