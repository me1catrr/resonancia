"""Versión Python de la práctica de J1.1: una señal de dos modos y su valor RMS.

La parte determinista coincide con la de Julia; el ruido no se compara porque
los generadores aleatorios de Julia y de NumPy son distintos.
"""
import numpy as np


def senal_dos_modos(fs=100.0, T=10.0, f1=2.5, f2=7.0, a1=1.0, a2=0.4):
    """Devuelve ``(t, x)``: suma de dos senoides de frecuencias f1 y f2 (Hz)."""
    n = int(round(fs * T))
    t = np.arange(n) / fs
    return t, a1 * np.sin(2 * np.pi * f1 * t) + a2 * np.sin(2 * np.pi * f2 * t)


def rms(x):
    """Valor eficaz de un vector."""
    return float(np.sqrt(np.mean(np.square(x))))
