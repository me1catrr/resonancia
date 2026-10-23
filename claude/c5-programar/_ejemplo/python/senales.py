"""Utilidades de señales para la unidad C5 (ejemplo didáctico).

Convención: los índices de ``detectar_picos`` empiezan en 0 (Python).
"""
import numpy as np


def media_movil(x, n):
    """Media de cada ventana de ``n`` muestras consecutivas ("valid": sin rellenar los bordes).

    Devuelve un arreglo de longitud ``len(x) - n + 1``.
    Lanza ``ValueError`` si ``n < 1`` o ``n > len(x)``.
    """
    x = np.asarray(x, dtype=float)
    if n < 1 or n > len(x):
        raise ValueError(f"n debe estar entre 1 y {len(x)}, no {n}")
    acumulada = np.concatenate(([0.0], np.cumsum(x)))
    return (acumulada[n:] - acumulada[:-n]) / n


def detectar_picos(x, umbral):
    """Índices (desde 0) de los máximos locales estrictos que superan ``umbral``.

    Un máximo local es una muestra mayor que su anterior y que su siguiente;
    las dos muestras de los extremos nunca cuentan.
    """
    x = np.asarray(x, dtype=float)
    centro = x[1:-1]
    es_pico = (centro > x[:-2]) & (centro > x[2:]) & (centro > umbral)
    return (np.flatnonzero(es_pico) + 1).tolist()
