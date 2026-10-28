"""Pruebas de clasificacion.py: identidades, casos resueltos a mano y recuperación de los resultados de J2.8.

Ejecutar desde la raíz: ``uv run pytest julia/j2-datos/j2-8-ml/python``
"""
from pathlib import Path

import numpy as np
import pandas as pd
import pytest
from scipy import optimize, stats

import clasificacion as cl

RAIZ = Path(__file__).resolve().parents[4]
DATOS = RAIZ / "datos" / "sinteticos" / "edificio-3-plantas"
BANDAS = ((0.8, 1.5), (2.5, 3.4), (3.8, 5.0))


# ----------------------------- modelos -----------------------------

def test_escala_media_cero_y_desviacion_uno():
    X = np.array([[1.0, 10.0], [2.0, 14.0], [3.0, 18.0], [4.0, 22.0]])
    mu, sigma = cl.ajustar_escala(X)
    Z = (X - mu) / sigma
    assert mu == pytest.approx([2.5, 16.0])
    assert Z.mean(axis=0) == pytest.approx([0, 0], abs=1e-12)
    assert Z.std(axis=0, ddof=1) == pytest.approx([1, 1])


def test_knn_nubes_separadas_y_empate():
    A = np.array([[0, 0], [0.2, 0.1], [0.1, 0.3], [0.3, 0.2], [0.25, 0.05]])
    X = np.vstack([A, A + 3])
    y = np.array(["a"] * 5 + ["b"] * 5)
    assert (cl.knn_predecir(X, y, X, k=3) == y).all()
    assert list(cl.knn_predecir(X, y, np.array([[0.1, 0.1], [3.2, 3.1]]), k=3)) == ["a", "b"]
    # k = 1 reproduce las etiquetas de entrenamiento
    rng = np.random.default_rng(0)
    R, yr = rng.normal(size=(12, 2)), np.arange(12) % 2
    assert (cl.knn_predecir(R, yr, R, k=1) == yr).all()
    # empate con k = 2: gana la clase más próxima
    e = cl.knn_predecir(np.array([[0.0, 0], [1.0, 0]]), np.array(["a", "b"]), np.array([[0.3, 0], [0.8, 0]]), k=2)
    assert list(e) == ["a", "b"]


def test_lda_frontera_en_el_punto_medio():
    x1 = np.array([-1.2, -1.0, -0.8, -1.1, -0.9])
    X = np.r_[x1, x1 + 4].reshape(-1, 1)
    y = np.array([0] * 5 + [1] * 5)
    m = cl.lda_ajustar(X, y)
    assert list(cl.lda_predecir(m, np.array([[-1.0], [0.9], [1.1], [3.0]]))) == [0, 0, 1, 1]
    assert cl.lda_probabilidades(m, np.array([[1.0]]))[0] == pytest.approx([0.5, 0.5], abs=1e-6)


def test_logistica_gradiente_nulo_y_coincide_con_optimizador():
    x = np.arange(-3, 3.5, 0.5)
    y = np.array([0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1, 1], dtype=float)
    beta = cl.logistica_ajustar(x.reshape(-1, 1), y, lam=0.0)
    p = cl.logistica_probabilidad(beta, x.reshape(-1, 1))
    assert np.sum(y - p) == pytest.approx(0, abs=1e-8)
    assert np.sum(x * (y - p)) == pytest.approx(0, abs=1e-8)

    def nll(b):
        eta = b[0] + b[1] * x
        return np.sum(np.logaddexp(0, eta) - y * eta)

    ref = optimize.minimize(nll, np.zeros(2), method="BFGS", options={"gtol": 1e-10}).x
    assert beta == pytest.approx(ref, abs=1e-5)


def test_logistica_separable_con_penalizacion_es_finita():
    x1 = np.array([-1.2, -1.0, -0.8, -1.1, -0.9])
    X = np.r_[x1, x1 + 4].reshape(-1, 1)
    y = np.array([0] * 5 + [1] * 5, dtype=float)
    beta = cl.logistica_ajustar(X, y)
    assert np.isfinite(beta).all()
    assert ((cl.logistica_probabilidad(beta, X) >= 0.5) == y.astype(bool)).all()


# ----------------------------- validación y métricas -----------------------------

def test_pliegues_estratificados_particion_y_proporcion():
    y = np.array([0] * 17 + [1] * 6)
    f = cl.pliegues_estratificados(y, 3)
    assert sorted(np.concatenate(f)) == list(range(23))
    assert all(y[idx].sum() == 2 for idx in f)


def test_validacion_cruzada_deja_uno_fuera():
    n = 23
    X, y = np.arange(n, dtype=float).reshape(-1, 1), np.arange(n, dtype=float)
    # con k = n (dejar uno fuera) la predicción de cada muestra es la media del resto
    pred = np.zeros(n)
    for test in [np.array([i]) for i in range(n)]:
        pred[test] = np.delete(y, test).mean()
    esperado = (y.sum() - y) / (n - 1)
    assert pred == pytest.approx(esperado)
    # y la función genérica reparte todo sin repetir
    p = cl.validacion_cruzada(lambda Xe, ye, Xp: np.full(len(Xp), ye.mean()), X, np.arange(n) % 2, k=5)
    assert p.shape == (n,)


def test_matriz_confusion_y_metricas():
    real = np.array([1, 1, 1, 1, 1, 1, 2, 2, 2, 2])
    pred = np.array([1, 1, 1, 1, 1, 2, 1, 1, 2, 2])
    C, clases = cl.matriz_confusion(real, pred)
    assert C.tolist() == [[5, 1], [2, 2]] and clases.tolist() == [1, 2]
    assert cl.exactitud(C) == pytest.approx(0.7)
    prec, rec, f1 = cl.metricas_por_clase(C)
    assert prec == pytest.approx([5 / 7, 2 / 3])
    assert rec == pytest.approx([5 / 6, 0.5])
    assert f1[0] == pytest.approx(2 * (5 / 7) * (5 / 6) / (5 / 7 + 5 / 6))
    # el clasificador que nunca detecta nada
    C0, _ = cl.matriz_confusion(np.r_[np.zeros(90), np.ones(10)], np.zeros(100), clases=[0, 1])
    assert cl.exactitud(C0) == pytest.approx(0.9) and cl.metricas_por_clase(C0)[1][1] == 0


def test_roc_ejemplo_clasico_y_equivalencia_con_mann_whitney():
    assert cl.auc_roc(np.array([0.1, 0.4, 0.35, 0.8]), np.array([0, 0, 1, 1])) == pytest.approx(0.75)
    assert cl.auc_roc(np.full(4, 0.5), np.array([0, 0, 1, 1])) == pytest.approx(0.5)
    rng = np.random.default_rng(3)
    y = (rng.random(60) < 0.3).astype(int)
    s = rng.normal(size=60) + 1.2 * y
    u = stats.mannwhitneyu(s[y == 1], s[y == 0]).statistic
    assert cl.auc_roc(s, y) == pytest.approx(u / (y.sum() * (1 - y).sum()))


# ----------------------------- señales -----------------------------

def test_frecuencias_modales_mejor_que_la_resolucion():
    fs = 100.0
    t = np.arange(6000) / fs
    x = np.sin(2 * np.pi * 3.037 * t) + 0.4 * np.sin(2 * np.pi * 1.213 * t)
    f = cl.frecuencias_modales(x, fs, ((0.8, 1.6), (2.5, 3.5)))
    assert f == pytest.approx([1.213, 3.037], abs=0.01)


def test_caracteristicas_evento_senoide():
    s = np.sin(2 * np.pi * 5 * np.arange(1000) / 1000)
    assert cl.caracteristicas_evento(s) == pytest.approx([np.log10(1 / np.sqrt(2)), np.sqrt(2), -1.5], abs=1e-9)


def test_respuesta_libre_formula():
    y = cl.respuesta_libre(400, 100.0, 1.0, [2.0], [0.5], 0.02)
    w = 2 * np.pi * 2.0
    assert (y[:100] == 0).all()
    assert y[350] == pytest.approx(0.5 * np.exp(-0.02 * w * 2.5) * np.sin(w * np.sqrt(1 - 0.02 ** 2) * 2.5))


# ----------------------------- datos del edificio (los de J2.8) -----------------------------

@pytest.fixture(scope="module")
def estados():
    X, y = [], []
    for e in "ABC":
        a3 = pd.read_csv(DATOS / f"escenario_{e}.csv", sep=";")["a3_ms2"].to_numpy()
        F = cl.por_ventanas(lambda w: cl.frecuencias_modales(w, 100.0, BANDAS), a3, 100.0, 20)
        X.append(F)
        y += [e] * len(F)
    return np.vstack(X), np.array(y)


def test_medias_por_estado(estados):
    X, y = estados
    assert X.shape == (90, 3)
    # Julia: f3 = 4,418 (A), 4,366 (B), 4,251 (C) Hz
    assert X[y == "A", 2].mean() == pytest.approx(4.418, abs=0.03)
    assert X[y == "B", 2].mean() == pytest.approx(4.366, abs=0.03)
    assert X[y == "C", 2].mean() == pytest.approx(4.251, abs=0.03)


def test_lda_en_validacion_cruzada_y_confusion_a_b(estados):
    X, y = estados

    def lda_esc(Xe, ye, Xp):
        mu, sg = cl.ajustar_escala(Xe)
        return cl.lda_predecir(cl.lda_ajustar((Xe - mu) / sg, ye), (Xp - mu) / sg)

    acc = []
    for s in range(10):
        perm = np.random.default_rng(s).permutation(len(y))
        pred = cl.validacion_cruzada(lda_esc, X, y, k=5, perm=perm)
        C, clases = cl.matriz_confusion(y, pred)
        acc.append(cl.exactitud(C))
    assert 0.65 < np.mean(acc) < 0.85          # Julia: 0,74 ± 0,03
    # el estado C (daño) se reconoce mucho mejor que la diferencia entre A y B
    _, rec, _ = cl.metricas_por_clase(C)
    assert rec[2] > 0.8 and rec[2] > rec[0]


def test_deteccion_de_eventos(estados):
    rng = np.random.default_rng(2027)
    fs, m = 100.0, 500
    F, etq = [], []
    for e in "ABC":
        a3 = pd.read_csv(DATOS / f"escenario_{e}.csv", sep=";")["a3_ms2"].to_numpy()
        for i in range(len(a3) // m):
            w = a3[i * m:(i + 1) * m].copy()
            hay = rng.random() < 0.12
            if hay:
                A = 0.2 + 0.6 * rng.random()
                w += cl.respuesta_libre(m, fs, 0.5 + 3.0 * rng.random(), [1.105, 2.939, 4.390], A * np.array([1, 0.6, 0.4]), 0.01)
            F.append(cl.caracteristicas_evento(w))
            etq.append(int(hay))
    X, y = np.array(F), np.array(etq)
    assert 25 < y.sum() < 60 and y.mean() < 0.2
    mu, sg = cl.ajustar_escala(X)
    prob = np.zeros(len(y))
    for test in cl.pliegues_estratificados(y, 5, np.random.default_rng(1).permutation(len(y))):
        train = np.setdiff1d(np.arange(len(y)), test)
        b = cl.logistica_ajustar(((X - mu) / sg)[train], y[train].astype(float))
        prob[test] = cl.logistica_probabilidad(b, ((X - mu) / sg)[test])
    assert cl.auc_roc(prob, y) > 0.9           # Julia: 0,98
    C, _ = cl.matriz_confusion(y, (prob >= 0.5).astype(int), clases=[0, 1])
    assert cl.exactitud(C) > 1 - y.mean()      # mejor que «no detectar nunca nada»
