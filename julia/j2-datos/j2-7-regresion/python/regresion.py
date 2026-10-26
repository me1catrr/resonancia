"""Versión Python de J2.7: regresión por mínimos cuadrados, diagnóstico y compensación.

Los datos son sintéticos (la misma receta que en la página de Julia); como los generadores
aleatorios difieren, se comprueba la recuperación de los parámetros y las identidades algebraicas.
"""
import numpy as np


def generar(n=365, semilla=2026):
    """Temperatura estacional, humedad y frecuencia del tercer modo (Hz) con deriva térmica."""
    rng = np.random.default_rng(semilla)
    dia = np.arange(1, n + 1)
    T = 15 + 10 * np.sin(2 * np.pi * (dia - 100) / 365) + 3 * rng.standard_normal(n)
    H = 60 + 15 * rng.standard_normal(n)
    f = 4.39 * (1 - 0.0009 * (T - 15) + 0.00004 * (T - 15) ** 2) + 0.012 * rng.standard_normal(n)
    return dia, T, H, f


def ajustar(X, y):
    """Mínimos cuadrados con QR: coeficientes, errores típicos, R² y desviación residual."""
    Q, R = np.linalg.qr(X)
    beta = np.linalg.solve(R, Q.T @ y)
    res = y - X @ beta
    gl = len(y) - X.shape[1]
    s2 = res @ res / gl
    cov = s2 * np.linalg.inv(R.T @ R)
    r2 = 1 - (res @ res) / ((y - y.mean()) @ (y - y.mean()))
    return {"beta": beta, "se": np.sqrt(np.diag(cov)), "r2": r2, "sigma": np.sqrt(s2), "res": res, "gl": gl}


def apalancamiento(X):
    """Diagonal de la matriz sombrero ``X (X'X)^-1 X'``."""
    Q, _ = np.linalg.qr(X)
    return (Q ** 2).sum(axis=1)


def cook(X, y):
    """Distancia de Cook de cada observación."""
    a = ajustar(X, y)
    h = apalancamiento(X)
    p = X.shape[1]
    return a["res"] ** 2 / (p * a["sigma"] ** 2) * h / (1 - h) ** 2
