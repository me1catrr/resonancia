"""Pruebas de matrices.py frente a Julia (referencia/matrices.json) y frente a SciPy.

Ejecutar desde la raíz: ``uv run pytest mse/m02-matematicas/python``
"""
import json
from pathlib import Path

import numpy as np
import pytest
from scipy import linalg

import matrices as mx

REF = json.loads((Path(__file__).parent.parent / "referencia" / "matrices.json").read_text(encoding="utf-8"))


def test_valores_propios_y_svd_frente_a_julia():
    r = REF["rectangular"]
    R = np.array(r["R"])
    assert np.linalg.eigvalsh(np.array(REF["simetrica"]["A"])) == pytest.approx(REF["simetrica"]["valores_propios"], rel=1e-12)
    S = np.linalg.svd(R, compute_uv=False)
    assert S == pytest.approx(r["valores_singulares"], rel=1e-12)
    assert np.linalg.norm(R, 1) == pytest.approx(r["norma1"])
    assert np.linalg.norm(R, np.inf) == pytest.approx(r["normaInf"])
    assert np.linalg.norm(R, "fro") == pytest.approx(r["normaFro"])
    assert np.linalg.cond(R) == pytest.approx(r["cond2"], rel=1e-10)
    x, *_ = np.linalg.lstsq(R, np.array(r["b_ls"]), rcond=None)
    assert x == pytest.approx(r["minimos_cuadrados"], rel=1e-10)


def test_hilbert5():
    h = REF["hilbert5"]
    H = np.array(h["H"])
    assert np.linalg.cond(H) == pytest.approx(h["cond2"], rel=1e-6)
    assert np.linalg.solve(H, np.ones(5)) == pytest.approx(h["solucion"], rel=1e-6)


def test_fft_y_convolucion_circular():
    f = REF["fft8"]
    X = np.fft.fft(f["x"])
    assert X.real == pytest.approx(f["re"], abs=1e-12)
    assert X.imag == pytest.approx(f["im"], abs=1e-12)
    c = REF["conv_circular"]
    assert mx.conv_circular(c["a"], c["b"]) == pytest.approx(c["c"], abs=1e-12)
    assert mx.conv_circular_fft(c["a"], c["b"]) == pytest.approx(c["c"], abs=1e-12)
    assert mx.circulante(c["a"]) @ np.array(c["b"]) == pytest.approx(c["c"], abs=1e-12)
    # valores propios de una circulante = DFT de su primera columna
    a = np.array(c["a"])
    assert np.sort(np.abs(np.linalg.eigvals(mx.circulante(a)))) == pytest.approx(np.sort(np.abs(np.fft.fft(a))), abs=1e-10)


def test_estructuradas_frente_a_scipy_y_definicion():
    assert mx.toeplitz([1, 2, 3], [1, 5, 6]).tolist() == [[1, 5, 6], [2, 1, 5], [3, 2, 1]]
    assert mx.toeplitz([1, 2, 3], [1, 5, 6]).tolist() == linalg.toeplitz([1, 2, 3], [1, 5, 6]).tolist()
    assert mx.hankel([1, 2, 3], [3, 4, 5]).tolist() == linalg.hankel([1, 2, 3], [3, 4, 5]).tolist()
    assert mx.hankel([1, 2, 3]).tolist() == [[1, 2, 3], [2, 3, 0], [3, 0, 0]]
    assert mx.circulante([1, 2, 3]).tolist() == [[1, 3, 2], [2, 1, 3], [3, 2, 1]]
    assert mx.circulante([1, 2, 3]).tolist() == linalg.circulant([1, 2, 3]).tolist()
    assert mx.hankel_trayectoria([1, 2, 3, 4, 5], 3).tolist() == [[1, 2, 3], [2, 3, 4], [3, 4, 5]]
    with pytest.raises(ValueError):
        mx.toeplitz([1, 2], [9, 3])
    with pytest.raises(ValueError):
        mx.hankel([1, 2, 3], [9, 4, 5])


def test_antidiagonal_y_ssa_frente_a_julia():
    assert mx.promedio_antidiagonal(np.array([[1.0, 2.0], [3.0, 4.0]])).tolist() == [1.0, 2.5, 4.0]
    s = REF["ssa"]
    rec, S = mx.ssa(s["x"], s["L"], 4)
    assert S[:8] == pytest.approx(s["valores_singulares"], rel=1e-9)
    assert rec == pytest.approx(s["reconstruccion_rango4"], abs=1e-9)
    assert S[4] < 1e-9 * S[0]  # dos sinusoides: rango 4


def test_autocorrelacion_y_yule_walker_frente_a_julia():
    y = REF["yule_walker"]
    r = mx.autocorrelacion(y["z"], 5)
    assert r == pytest.approx(y["r"], abs=1e-12)
    phi, s2 = mx.yule_walker(r, 2)
    assert phi == pytest.approx(y["phi"], rel=1e-9)
    assert s2 == pytest.approx(y["sigma2"], rel=1e-9)
    # AR(1) teórico
    p, s = 0.7, 2.0
    rt = [s * p**k / (1 - p**2) for k in range(6)]
    phi1, s21 = mx.yule_walker(rt, 1)
    assert phi1[0] == pytest.approx(p)
    assert s21 == pytest.approx(s)


def test_cadena_y_edificio_frente_a_julia():
    c = REF["cadena4"]
    M, K = mx.cadena_masas_muelles(4, c["m"], c["k"])
    f, Phi = mx.modos_propios(K, M)
    assert f == pytest.approx(c["f"], rel=1e-10)
    assert np.abs(Phi) == pytest.approx(np.array(c["modos_abs"]), abs=1e-8)
    assert Phi.T @ M @ Phi == pytest.approx(np.eye(4), abs=1e-10)
    assert (Phi.sum(axis=0) > 0).all()
    n = 4
    w2 = (2 * np.pi * f) ** 2
    esperado = [2 * c["k"] / c["m"] * (1 - np.cos((2 * j - 1) * np.pi / (2 * n + 1))) for j in range(1, n + 1)]
    assert w2 == pytest.approx(esperado, rel=1e-10)

    e = REF["edificio_generico"]
    Me, Ke = mx.edificio_cortante(e["m"], e["k"])
    assert Ke == pytest.approx(np.array(e["K"]), abs=1e-14)
    fe, Pe = mx.modos_propios(Ke, Me)
    assert fe == pytest.approx(e["f"], rel=1e-10)
    assert np.abs(Pe) == pytest.approx(np.array(e["modos_abs"]), abs=1e-8)


def test_mac():
    m = REF["mac"]
    assert mx.mac(m["a"], m["b"]) == pytest.approx(m["valor"], rel=1e-12)
    assert mx.mac(m["a"], -4.2 * np.array(m["a"])) == pytest.approx(1.0)
    assert mx.mac([1, 0], [0, 1]) == 0


def test_era_frente_a_julia():
    e = REF["era"]
    f, z = mx.era(e["h"], e["n"], e["dt"])
    assert f == pytest.approx(e["f"], abs=1e-8)
    assert z == pytest.approx(e["zeta"], abs=1e-8)
    assert f == pytest.approx([2.0, 5.0], abs=1e-7)
    with pytest.raises(ValueError):
        mx.era(e["h"][:6], 4, e["dt"])


def test_levinson_durbin_frente_a_julia_y_a_yule_walker():
    lv = REF["levinson"]
    phi, s2, kappa = mx.levinson_durbin(lv["r"], lv["p"])
    assert phi == pytest.approx(lv["phi"], rel=1e-9)
    assert s2 == pytest.approx(lv["sigma2"], rel=1e-9)
    assert kappa == pytest.approx(lv["kappa"], rel=1e-9)
    phi_yw, s2_yw = mx.yule_walker(lv["r"], lv["p"])
    assert phi == pytest.approx(phi_yw, rel=1e-9)
    assert s2 == pytest.approx(s2_yw, rel=1e-9)


def test_observabilidad_y_mac_del_edificio_frente_a_julia():
    o = REF["observabilidad"]
    A = np.array(o["A"])
    assert np.linalg.matrix_rank(mx.matriz_observabilidad(A, o["C_centro"])) == o["rango_centro"] == 4
    assert np.linalg.matrix_rank(mx.matriz_observabilidad(A, o["C_extremo"])) == o["rango_extremo"] == 6
    B = np.array([[0.0], [0.0], [0.0], [0.0], [1.0], [0.0]])
    assert np.linalg.matrix_rank(mx.matriz_controlabilidad(A, B)) == 4
    m = REF["mac_edificio"]
    Me, K0 = mx.edificio_cortante([1.0, 1.0, 1.0], [1.0, 1.0, 1.0])
    _, K1 = mx.edificio_cortante([1.0, 1.0, 1.0], [1.0, 0.9, 1.0])
    f0, P0 = mx.modos_propios(K0, Me)
    f1, P1 = mx.modos_propios(K1, Me)
    assert f0 == pytest.approx(m["f0"], rel=1e-10)
    assert f1 == pytest.approx(m["f1"], rel=1e-10)
    assert mx.matriz_mac(P0, P1) == pytest.approx(np.array(m["matriz"]), abs=1e-8)


def test_pseudoinversa_y_exponencial_frente_a_julia():
    r = REF["pseudoinversa"]
    assert mx.pseudoinversa(r["A"]) == pytest.approx(np.array(r["P"]), rel=1e-10, abs=1e-12)
    assert mx.pseudoinversa(r["A"]) == pytest.approx(np.linalg.pinv(r["A"]), rel=1e-10, abs=1e-12)
    e = REF["expm"]
    assert linalg.expm(np.array(e["A"])) == pytest.approx(np.array(e["expA"]), rel=1e-10)
    Ad, Bd = mx.discretizar_zoh(e["A"], [[0.0], [1.0]], e["dt"])
    assert Ad == pytest.approx(np.array(e["Ad"]), rel=1e-10)
    assert Bd == pytest.approx(np.array(e["Bd"]), rel=1e-10)


def test_edificio_tres_plantas_frente_a_julia():
    e = REF["edificio3"]
    M, K = mx.edificio_tres_plantas("A")
    w2 = linalg.eigh(K, M, eigvals_only=True)
    assert np.sqrt(w2) / (2 * np.pi) == pytest.approx(e["f"], rel=1e-9)
    MC, KC = mx.edificio_tres_plantas("C")
    assert np.sqrt(linalg.eigh(KC, MC, eigvals_only=True)) / (2 * np.pi) == pytest.approx(e["f_C"], rel=1e-9)
    with pytest.raises(ValueError):
        mx.edificio_tres_plantas("Z")


def test_espacio_estados_y_polos_frente_a_julia():
    e = REF["edificio3"]
    M, C, K = mx.edificio_tres_plantas("A", amortiguado=True)
    A, B = mx.espacio_estados(M, C, K, [[0.0], [0.0], [1.0]])
    f, zeta = mx.polos_modales(A)
    assert f == pytest.approx(e["f_polos"], rel=1e-9)
    assert zeta == pytest.approx(e["zeta"], rel=1e-7)
    assert B.shape == (6, 1) and B[5, 0] == pytest.approx(1 / 2.0e5)
    # los dos primeros amortiguamientos se fijan al 1 %
    assert zeta[:2] == pytest.approx([0.01, 0.01], abs=1e-9)


def test_polos_ar_frente_a_julia():
    r = REF["polos_ar"]
    f, zeta = mx.polos_ar(r["phi"], r["dt"])
    assert f == pytest.approx(np.atleast_1d(r["f"]), rel=1e-9)
    assert zeta == pytest.approx(np.atleast_1d(r["zeta"]), rel=1e-9)


def test_hilbert_ventanas_y_correlacion_cruzada_frente_a_julia():
    from scipy import signal
    h = REF["hilbert"]
    z = mx.hilbert_analitica(h["x"])
    assert z.imag == pytest.approx(h["im"], abs=1e-10)
    assert np.abs(z) == pytest.approx(h["env"], abs=1e-10)
    assert signal.hilbert(h["x"]).imag == pytest.approx(h["im"], abs=1e-10)
    c = REF["xcorr"]
    assert mx.correlacion_cruzada(c["x"], c["y"], c["kmax"]) == pytest.approx(c["cc"], abs=1e-12)
    v = REF["ventanas"]
    for n in ("hann", "hamming", "blackman", "flattop"):
        assert mx.ventana(n, v["N"]) == pytest.approx(v[n], abs=1e-12)
