"""Versión Python de J2.6: contrastes e intervalos con scipy y bootstrap con numpy.

Estimaciones de la frecuencia del tercer modo por segmentos de 60 s (como en J2.4).
"""
import numpy as np
import pandas as pd
from scipy import signal, stats


def frecuencias_por_segmento(x, fs=100.0, seg=6000, nseg=2048, banda=(3.8, 5.0)):
    """Frecuencia del pico dentro de ``banda`` en cada segmento consecutivo de ``seg`` muestras."""
    out = []
    for k in range(len(x) // seg):
        f, P = signal.welch(x[k * seg:(k + 1) * seg], fs=fs, window="hann", nperseg=nseg,
                            noverlap=nseg // 2, detrend="constant")
        m = (f >= banda[0]) & (f <= banda[1])
        out.append(f[m][np.argmax(P[m])])
    return np.array(out)


def welch_t(a, b):
    """Contraste t de Welch: diferencia de medias, t, grados de libertad, p e IC del 95 %."""
    r = stats.ttest_ind(a, b, equal_var=False)
    ic = r.confidence_interval(0.95)
    return {"dif": a.mean() - b.mean(), "t": r.statistic, "df": r.df, "p": r.pvalue, "ic": (ic.low, ic.high)}


def d_cohen(a, b):
    """Tamaño de efecto: diferencia de medias entre la desviación típica combinada."""
    return (a.mean() - b.mean()) / np.sqrt((a.var(ddof=1) + b.var(ddof=1)) / 2)


def bootstrap_dif(a, b, n=10000, semilla=1):
    """Muestras bootstrap de la diferencia de medias."""
    rng = np.random.default_rng(semilla)
    return np.array([rng.choice(a, len(a)).mean() - rng.choice(b, len(b)).mean() for _ in range(n)])


def potencia(dif, sd, n, repeticiones=4000, semilla=3):
    """Potencia (por simulación) de un t de Welch de nivel 0,05."""
    rng = np.random.default_rng(semilla)
    rech = sum(stats.ttest_ind(sd * rng.standard_normal(n), dif + sd * rng.standard_normal(n), equal_var=False).pvalue < 0.05
               for _ in range(repeticiones))
    return rech / repeticiones


def cargar(esc, base):
    return pd.read_csv(f"{base}/escenario_{esc}.csv", sep=";")["a3_ms2"].to_numpy()
