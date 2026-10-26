"""Versión Python de J1.3: acumulación de errores de redondeo y bucles sobre una señal.

Los ``float`` de Python son dobles IEEE 754, igual que ``Float64`` en Julia: las
mismas sumas dan exactamente los mismos resultados.
"""
import numpy as np


def acumula(dt, n):
    """Suma ``n`` veces ``dt`` con un bucle (el error de redondeo se acumula)."""
    t = 0.0
    for _ in range(n):
        t += dt
    return t


def cuenta(x, umbral):
    """Número de muestras con ``|x| > umbral``."""
    c = 0
    for v in x:
        if abs(v) > umbral:
            c += 1
    return c


def primero(x, umbral):
    """Índice (desde 0) de la primera muestra con ``|x| > umbral``; ``None`` si no hay."""
    i = 0
    while i < len(x) and abs(x[i]) <= umbral:
        i += 1
    return i if i < len(x) else None


def senal_limpia(fs=100.0, T=10.0):
    t = np.arange(int(round(fs * T))) / fs
    return np.sin(2 * np.pi * 2.5 * t) + 0.4 * np.sin(2 * np.pi * 7.0 * t)
