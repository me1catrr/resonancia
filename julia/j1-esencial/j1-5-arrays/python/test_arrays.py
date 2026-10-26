"""Pruebas de arrays.py frente a los valores de Julia (página J1.5).

Ejecutar desde la raíz: ``uv run pytest julia/j1-esencial/j1-5-arrays/python``
"""
import numpy as np
import pytest

import arrays as ar

F_JULIA = [1.1048012767720872, 2.938675197033046, 4.390152904211614]


def test_frecuencias_frente_a_julia():
    M, K = ar.matrices_3gdl()
    assert ar.frecuencias_propias(M, K) == pytest.approx(F_JULIA, rel=1e-12)


def test_k_simetrica_y_definida_positiva():
    _, K = ar.matrices_3gdl()
    assert np.allclose(K, K.T)
    assert np.all(np.linalg.eigvalsh(K) > 0)


def test_centrado_por_canal():
    t = np.arange(1000) / 100.0
    X = np.column_stack([2 + np.sin(2 * np.pi * 2.5 * t), -1 + 0.8 * np.sin(2 * np.pi * 2.5 * t)])
    Xc = ar.centrar_por_canal(X)
    assert Xc.shape == X.shape
    assert np.abs(Xc.mean(axis=0)).max() < 1e-12


def test_asignar_no_copia_pero_copy_si():
    A = np.array([[1, 2], [3, 4]])
    B = A
    C = A.copy()
    B[0, 0] = 99
    assert A[0, 0] == 99      # B es el mismo objeto
    assert C[0, 0] == 1       # la copia no cambia
