"""Versión Python de J2.3: detectores de defectos en una señal de vibración.

Las posiciones de los defectos inyectados son las mismas que en la página de Julia
(índices desde 0 aquí, desde 1 allí).
"""
import numpy as np

POSICIONES_PICOS = [1105, 2340, 2700, 3409, 3508, 3872]   # 1-based, como en Julia
SIGNOS_PICOS = [1, 1, 1, 1, -1, -1]


def inyectar_defectos(x):
    """Copia de ``x`` con 6 picos de ±5, un tramo plano (muestras 1500–1539) y un salto de +0,3 desde la 3000."""
    y = np.array(x, dtype=float)
    for p, s in zip(POSICIONES_PICOS, SIGNOS_PICOS):
        y[p - 1] += 5.0 * s
    y[1499:1539] = 0.0
    y[2999:] += 0.3
    return y


def fuera_de_rango(x, limite):
    """Índices (desde 0) con ``|x| > limite``."""
    return np.flatnonzero(np.abs(x) > limite)


def z_mad(x):
    """Z-score modificado: ``0,6745 (x − mediana) / MAD``."""
    m = np.median(x)
    mad = np.median(np.abs(x - m))
    return 0.6745 * (x - m) / mad


def hampel(x, k=5, n=4):
    """Índices (desde 0) detectados por el filtro de Hampel de ventana ``2k+1`` y umbral ``n``."""
    x = np.asarray(x, float)
    out = []
    for i in range(len(x)):
        w = x[max(0, i - k): min(len(x), i + k + 1)]
        m = np.median(w)
        s = 1.4826 * np.median(np.abs(w - m))
        if s > 0 and abs(x[i] - m) > n * s:
            out.append(i)
    return np.array(out, dtype=int)


def tramos_planos(x, minimo=10):
    """Lista de ``(inicio, fin)`` (desde 0, ambos incluidos) de tramos de valores idénticos de al menos ``minimo`` muestras."""
    out, i, n = [], 0, len(x)
    while i < n:
        j = i
        while j + 1 < n and x[j + 1] == x[i]:
            j += 1
        if j - i + 1 >= minimo:
            out.append((i, j))
        i = j + 1
    return out


def salto_por_medianas(x, ventana=200):
    """Devuelve ``(índice de la ventana tras el salto mayor, tamaño del salto)`` comparando medianas de ventanas consecutivas."""
    n = len(x) // ventana
    med = np.array([np.median(x[i * ventana:(i + 1) * ventana]) for i in range(n)])
    d = np.diff(med)
    k = int(np.argmax(np.abs(d)))
    return k + 1, float(d[k])
