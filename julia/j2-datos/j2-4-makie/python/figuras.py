"""Versión Python de J2.4: contraste de colores, picos por segmento y figura de tres paneles.

La figura se hace con matplotlib; el tamaño se da en pulgadas (1 pulgada = 72 pt).
"""
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from scipy import signal


def _lineal(c):
    return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4


def luminancia(hex_color):
    """Luminancia relativa (WCAG) de un color ``#RRGGBB``."""
    r, g, b = (int(hex_color[i:i + 2], 16) / 255 for i in (1, 3, 5))
    return 0.2126 * _lineal(r) + 0.7152 * _lineal(g) + 0.0722 * _lineal(b)


def contraste(a, b="#FFFFFF"):
    """Relación de contraste ``(L1 + 0,05)/(L2 + 0,05)`` entre dos colores ``#RRGGBB``."""
    la, lb = sorted((luminancia(a), luminancia(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def picos_por_segmento(x, fs, seg=6000, nseg=2048, banda=(3.8, 5.0)):
    """Frecuencia del pico dentro de ``banda`` en cada segmento consecutivo de ``seg`` muestras."""
    out = []
    for k in range(len(x) // seg):
        f, P = signal.welch(x[k * seg:(k + 1) * seg], fs=fs, window="hann", nperseg=nseg,
                            noverlap=nseg // 2, detrend="constant")
        m = (f >= banda[0]) & (f <= banda[1])
        out.append(f[m][np.argmax(P[m])])
    return np.array(out)


def figura_columna(datos, etiquetas, ancho_pt=252, alto_pt=190):
    """Diagrama de cajas de ``datos`` (lista de vectores) con el tamaño de una columna de revista."""
    fig, ax = plt.subplots(figsize=(ancho_pt / 72, alto_pt / 72))
    ax.boxplot(datos, tick_labels=etiquetas)
    ax.set(ylabel="frecuencia (Hz)")
    fig.tight_layout()
    return fig
