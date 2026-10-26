"""Versión Python de J2.5: propagación de incertidumbre en el edificio de tres plantas.

Modelo de cortante de tres plantas: masas ``m`` (kg) y rigideces de entrepiso ``k`` (N/m).
Los números aleatorios de NumPy y de Julia son distintos: se comparan estadísticos, no muestras.
"""
import numpy as np
from scipy import linalg

M_NOM = np.full(3, 2.0e5)
K_NOM = np.array([5.0e7, 5.0e7, 4.0e7])


def matrices(m, k):
    K = np.array([[k[0] + k[1], -k[1], 0.0], [-k[1], k[1] + k[2], -k[2]], [0.0, -k[2], k[2]]])
    return np.diag(m), K


def frecuencias(m, k):
    """Frecuencias naturales en Hz, en orden creciente."""
    M, K = matrices(m, k)
    return np.sqrt(linalg.eigh(K, M, eigvals_only=True)) / (2 * np.pi)


def propagacion(n=20000, cv_k=0.05, cv_m=0.02, semilla=2026):
    """Muestras de ``(f1, f2, f3)`` con rigideces y masas normales independientes."""
    rng = np.random.default_rng(semilla)
    F = np.empty((n, 3))
    for i in range(n):
        k = K_NOM * (1 + cv_k * rng.standard_normal(3))
        m = M_NOM * (1 + cv_m * rng.standard_normal(3))
        F[i] = frecuencias(m, k)
    return F


def sigma_lineal(cv_k=0.05, cv_m=0.02):
    """Desviación típica de cada frecuencia por propagación lineal (derivadas por diferencias centrales)."""
    theta = np.concatenate([M_NOM, K_NOM])
    sigma = np.concatenate([cv_m * M_NOM, cv_k * K_NOM])
    J = np.empty((3, 6))
    for j in range(6):
        h = 1e-6 * theta[j]
        tp, tm = theta.copy(), theta.copy()
        tp[j] += h
        tm[j] -= h
        J[:, j] = (frecuencias(tp[:3], tp[3:]) - frecuencias(tm[:3], tm[3:])) / (2 * h)
    return np.sqrt(((J * sigma) ** 2).sum(axis=1)), J
