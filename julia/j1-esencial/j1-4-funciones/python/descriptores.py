"""Versión Python de J1.4: descriptores temporales de una señal.

Definiciones iguales a las de Julia: RMS, pico (máximo del valor absoluto), factor de
cresta (pico/RMS) y curtosis no «en exceso» (vale 3 para una distribución normal).
"""
import numpy as np


def rms(x):
    """Valor eficaz: raíz de la media de los cuadrados."""
    x = np.asarray(x, dtype=float)
    return float(np.sqrt(np.mean(x**2)))


def pico(x):
    """Máximo del valor absoluto."""
    return float(np.max(np.abs(x)))


def cresta(x):
    """Factor de cresta: pico dividido entre RMS."""
    return pico(x) / rms(x)


def curtosis(x):
    """Curtosis: ``E[(x - m)^4] / var^2`` (varianza poblacional)."""
    x = np.asarray(x, dtype=float)
    d = x - x.mean()
    return float(np.mean(d**4) / np.mean(d**2) ** 2)


def descriptores(x, quitar_media=True):
    """Diccionario con ``rms``, ``pico``, ``cresta`` y ``curtosis``."""
    x = np.asarray(x, dtype=float)
    y = x - x.mean() if quitar_media else x
    return {"rms": rms(y), "pico": pico(y), "cresta": cresta(y), "curtosis": curtosis(y)}
