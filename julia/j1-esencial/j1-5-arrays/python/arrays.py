"""Versión Python de J1.5: matrices de un sistema de 3 GDL, modos y centrado por canales.

``numpy`` y ``scipy`` hacen el papel de ``LinearAlgebra``. Diferencia importante: en NumPy
los índices empiezan en 0 y ``B = A`` también comparte memoria (no copia).
"""
import numpy as np
from scipy import linalg


def matrices_3gdl(m=2.0e5, k=(5.0e7, 5.0e7, 4.0e7)):
    """Matrices de masa y rigidez de un edificio de cortante de tres plantas."""
    k1, k2, k3 = k
    M = m * np.eye(3)
    K = np.array([[k1 + k2, -k2, 0.0], [-k2, k2 + k3, -k3], [0.0, -k3, k3]])
    return M, K


def frecuencias_propias(M, K):
    """Frecuencias naturales en Hz, en orden creciente, de ``K φ = ω² M φ``."""
    w2 = linalg.eigh(K, M, eigvals_only=True)
    return np.sqrt(w2) / (2 * np.pi)


def centrar_por_canal(X):
    """Resta a cada columna (canal) su media; ``X`` es muestras × canales."""
    return X - X.mean(axis=0, keepdims=True)
