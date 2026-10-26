"""Versión Python de J1.7: espectro de Welch y figura de dos paneles con matplotlib.

``scipy.signal.welch`` con ventana de Hann periódica, solape del 50 % y media restada por
segmento equivale a ``psd_welch`` de Resonancia.jl (densidad espectral unilateral).
"""
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from scipy import signal


def espectro(x, fs, nseg=4096):
    """Densidad espectral de potencia unilateral por el método de Welch: ``(f, P)``."""
    return signal.welch(x, fs=fs, window="hann", nperseg=nseg, noverlap=nseg // 2, detrend="constant")


def picos(f, P, fmin=0.5, fmax=6.0, n=3):
    """Frecuencias de los ``n`` máximos locales más altos en ``[fmin, fmax]``, en orden creciente."""
    idx, _ = signal.find_peaks(P)
    idx = [i for i in idx if fmin <= f[i] <= fmax]
    idx = sorted(sorted(idx, key=lambda i: P[i], reverse=True)[:n])
    return f[idx]


def figura_dos_paneles(t, x, f, P, fpicos):
    """Serie temporal y espectro semilogarítmico con los picos marcados."""
    fig, (a1, a2) = plt.subplots(1, 2, figsize=(9, 3))
    a1.plot(t, x, lw=0.8)
    a1.set(xlabel="tiempo (s)", ylabel="a (m/s²)")
    a2.semilogy(f, P)
    for fp in fpicos:
        a2.axvline(fp, ls="--", c="C1", lw=0.8)
    a2.set(xlabel="frecuencia (Hz)", ylabel="PSD ((m/s²)²/Hz)", xlim=(0, 10))
    fig.tight_layout()
    return fig
