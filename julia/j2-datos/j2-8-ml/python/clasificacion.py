"""Versión Python de J2.8: clasificación de estados y de eventos con numpy.

Réplica de las funciones de ``Resonancia.jl`` (k-NN, LDA, regresión logística, validación cruzada
estratificada, matriz de confusión, métricas y curva ROC) para ver qué hay debajo de una biblioteca
como scikit-learn. Los registros del edificio son sintéticos (``datos/sinteticos/edificio-3-plantas``).
"""
import numpy as np
from scipy import signal


# ---------------------------------------------------------------------------
# Características
# ---------------------------------------------------------------------------

def frecuencias_modales(x, fs, bandas, nseg=1024):
    """Frecuencia (Hz) del pico de Welch en cada banda, refinada con una parábola sobre log(P)."""
    f, P = signal.welch(x, fs=fs, window="hann", nperseg=nseg, noverlap=nseg // 2, detrend="constant")
    df = f[1] - f[0]
    salida = []
    for lo, hi in bandas:
        idx = np.flatnonzero((f >= lo) & (f <= hi))
        k = idx[np.argmax(P[idx])]
        a, b, c = np.log(P[k - 1]), np.log(P[k]), np.log(P[k + 1])
        salida.append(f[k] + 0.5 * (a - c) / (a - 2 * b + c) * df)
    return np.array(salida)


def por_ventanas(funcion, x, fs, seg_s):
    """Aplica ``funcion`` a cada ventana consecutiva de ``seg_s`` s y apila los resultados por filas."""
    m = int(round(fs * seg_s))
    return np.array([funcion(x[i * m:(i + 1) * m]) for i in range(len(x) // m)])


def caracteristicas_evento(x):
    """log10 del RMS, factor de cresta y curtosis en exceso de una ventana."""
    rms = np.sqrt(np.mean(x ** 2))
    s2 = np.mean((x - x.mean()) ** 2)
    curtosis = np.mean((x - x.mean()) ** 4) / s2 ** 2 - 3
    return np.array([np.log10(rms), np.max(np.abs(x)) / rms, curtosis])


def respuesta_libre(n, fs, t0, frecuencias, amplitudes, zeta):
    """Suma de respuestas libres amortiguadas de varios modos tras un impacto en ``t0`` s (cero antes)."""
    t = np.arange(n) / fs - t0
    y = np.zeros(n)
    for f, A in zip(frecuencias, amplitudes):
        w = 2 * np.pi * f
        y += np.where(t >= 0, A * np.exp(-zeta * w * np.maximum(t, 0)) * np.sin(w * np.sqrt(1 - zeta ** 2) * np.maximum(t, 0)), 0.0)
    return y


# ---------------------------------------------------------------------------
# Modelos
# ---------------------------------------------------------------------------

def ajustar_escala(X):
    mu, sigma = X.mean(axis=0), X.std(axis=0, ddof=1)
    return mu, np.where(sigma == 0, 1.0, sigma)


def knn_predecir(Xe, ye, Xp, k=5):
    """Clase más votada entre los ``k`` vecinos euclídeos más próximos (desempate por distancia total)."""
    clases = np.unique(ye)
    pred = []
    for x in Xp:
        d = np.linalg.norm(Xe - x, axis=1)
        vec = np.argsort(d, kind="stable")[:k]
        votos = np.array([np.sum(ye[vec] == c) for c in clases])
        mejores = np.flatnonzero(votos == votos.max())
        if len(mejores) > 1:
            tot = [d[vec][ye[vec] == clases[b]].sum() for b in mejores]
            mejores = mejores[[int(np.argmin(tot))]]
        pred.append(clases[mejores[0]])
    return np.array(pred)


def lda_ajustar(X, y, reg=1e-8):
    """LDA con covarianza común: devuelve (clases, medias, inversa de la covarianza, log de las probabilidades a priori)."""
    clases = np.unique(y)
    n, p = X.shape
    medias = np.array([X[y == c].mean(axis=0) for c in clases])
    S = sum((X[y == c] - medias[i]).T @ (X[y == c] - medias[i]) for i, c in enumerate(clases)) / (n - len(clases))
    S = S + reg * np.trace(S) / p * np.eye(p)
    prior = np.array([np.mean(y == c) for c in clases])
    return clases, medias, np.linalg.inv(S), np.log(prior)


def lda_probabilidades(modelo, X):
    clases, medias, Sinv, logprior = modelo
    L = np.column_stack([X @ (Sinv @ m) - 0.5 * m @ Sinv @ m + lp for m, lp in zip(medias, logprior)])
    L -= L.max(axis=1, keepdims=True)
    P = np.exp(L)
    return P / P.sum(axis=1, keepdims=True)


def lda_predecir(modelo, X):
    return modelo[0][np.argmax(lda_probabilidades(modelo, X), axis=1)]


def logistica_ajustar(X, y, lam=1e-6, maxiter=100, tol=1e-10):
    """Regresión logística binaria (y en {0, 1}) por IRLS con penalización ridge en los coeficientes."""
    A = np.column_stack([np.ones(len(y)), X])
    pen = np.diag(np.r_[0.0, np.full(X.shape[1], lam)])
    beta = np.zeros(A.shape[1])
    for _ in range(maxiter):
        mu = 1 / (1 + np.exp(-A @ beta))
        W = np.maximum(mu * (1 - mu), 1e-10)
        paso = np.linalg.solve(A.T @ (W[:, None] * A) + pen, A.T @ (y - mu) - pen @ beta)
        beta = beta + paso
        if np.max(np.abs(paso)) < tol:
            break
    return beta


def logistica_probabilidad(beta, X):
    return 1 / (1 + np.exp(-(beta[0] + X @ beta[1:])))


# ---------------------------------------------------------------------------
# Validación cruzada y métricas
# ---------------------------------------------------------------------------

def pliegues_estratificados(y, k, perm=None):
    """Lista de ``k`` arrays de índices de prueba con la proporción de clases conservada."""
    n = len(y)
    perm = np.arange(n) if perm is None else np.asarray(perm)
    out = [[] for _ in range(k)]
    sig = 0
    for c in np.unique(y):
        for i in perm:
            if y[i] == c:
                out[sig % k].append(i)
                sig += 1
    return [np.sort(f) for f in out]


def validacion_cruzada(ajustar_predecir, X, y, k=5, perm=None):
    """``ajustar_predecir(Xe, ye, Xp)`` entrena y predice; devuelve la predicción de cada muestra fuera de pliegue."""
    n = len(y)
    salida = None
    for test in pliegues_estratificados(y, k, perm):
        train = np.setdiff1d(np.arange(n), test)
        s = ajustar_predecir(X[train], y[train], X[test])
        if salida is None:
            salida = np.zeros((n,) + s.shape[1:], dtype=s.dtype)
        salida[test] = s
    return salida


def matriz_confusion(real, pred, clases=None):
    clases = np.unique(np.r_[real, pred]) if clases is None else np.asarray(clases)
    C = np.zeros((len(clases), len(clases)), dtype=int)
    for a, b in zip(real, pred):
        C[np.searchsorted(clases, a), np.searchsorted(clases, b)] += 1
    return C, clases


def exactitud(C):
    return np.trace(C) / C.sum()


def metricas_por_clase(C):
    """Precisión, exhaustividad y F1 de cada clase (0 si no están definidas)."""
    def div(a, b):
        return np.divide(a, b, out=np.zeros_like(a, dtype=float), where=b != 0)
    prec = div(np.diag(C).astype(float), C.sum(axis=0))
    rec = div(np.diag(C).astype(float), C.sum(axis=1))
    return prec, rec, div(2 * prec * rec, prec + rec)


def curva_roc(puntuacion, y):
    """(fpr, tpr, umbrales) agrupando puntuaciones iguales; empieza en (0, 0) y termina en (1, 1)."""
    o = np.argsort(-puntuacion, kind="stable")
    s, yo = puntuacion[o], y[o].astype(float)
    P, N = yo.sum(), (1 - yo).sum()
    tp, fp = np.cumsum(yo), np.cumsum(1 - yo)
    ultimo = np.r_[s[1:] != s[:-1], True]
    return np.r_[0, fp[ultimo] / N], np.r_[0, tp[ultimo] / P], np.r_[np.inf, s[ultimo]]


def auc_roc(puntuacion, y):
    fpr, tpr, _ = curva_roc(puntuacion, y)
    return float(np.sum(np.diff(fpr) * (tpr[1:] + tpr[:-1]) / 2))
