"""Pruebas de senales.py frente a Julia (referencia/senales.json) y frente a SciPy.

Ejecutar desde la raíz: ``uv run pytest mse/m03-senales-i/python``
"""
import json
from pathlib import Path

import numpy as np
import pytest
from scipy import signal

import senales as sn

REF = json.loads((Path(__file__).parent.parent / "referencia" / "senales.json").read_text(encoding="utf-8"))


def test_descriptores_frente_a_julia():
    r = REF["descriptores"]
    d = sn.descriptores_temporales(r["x"])
    for k, v in d.items():
        assert v == pytest.approx(r[k], rel=1e-12), k
    assert d["rms"] ** 2 == pytest.approx(d["media"] ** 2 + d["varianza"])


def test_convertidor_y_alias_frente_a_julia():
    r = REF["cuantizar"]
    y, sat, q = sn.cuantizar(r["x"], r["bits"], r["rango"], r["offset"])
    assert q == r["q"]
    assert y == pytest.approx(r["y"], abs=1e-12)
    assert list(sat) == r["saturada"]
    a = REF["alias"]
    assert [sn.frecuencia_aparente(f, a["fs"]) for f in a["f"]] == pytest.approx(a["aparente"])


def test_dft_frente_a_julia():
    r = REF["dft"]
    for x, re, im in ((r["x6"], r["re6"], r["im6"]), (r["x12"], r["re12"], r["im12"])):
        X = np.fft.fft(x)
        assert X.real == pytest.approx(re, abs=1e-10)
        assert X.imag == pytest.approx(im, abs=1e-10)
    assert np.fft.fft(r["mano"]).real == pytest.approx(r["mano_re"], abs=1e-12)


def test_periodograma_y_amplitud_frente_a_julia():
    r = REF["periodograma"]
    f, P = sn.periodograma(r["x"], r["fs"])
    assert f == pytest.approx(r["f"])
    assert P == pytest.approx(r["P"], rel=1e-10, abs=1e-14)
    assert sn.periodograma(r["x"], r["fs"], quitar_media=False)[1] == pytest.approx(r["P_con_media"], rel=1e-10, abs=1e-14)
    fh, Ph = sn.periodograma(r["x"], r["fs"], ventana="hann", nfft=32)
    assert fh == pytest.approx(r["f_hann32"])
    assert Ph == pytest.approx(r["P_hann32"], rel=1e-10, abs=1e-14)
    _, A, fase = sn.espectro_amplitud(r["x"], r["fs"])
    assert A == pytest.approx(r["A"], rel=1e-10, abs=1e-14)
    vivos = np.array(r["A"]) > 1e-8
    assert fase[vivos] == pytest.approx(np.array(r["fase"])[vivos], abs=1e-9)
    assert sn.espectro_amplitud(r["x"], r["fs"], ventana="hann", nfft=32)[1] == pytest.approx(r["A_hann32"], rel=1e-10, abs=1e-14)


def test_periodograma_frente_a_scipy():
    # SciPy con detrend constante, ventana rectangular y escalado de densidad: misma convención
    r = REF["periodograma"]
    f, P = signal.periodogram(np.asarray(r["x"]), fs=r["fs"], window="boxcar", detrend="constant", scaling="density")
    assert P == pytest.approx(sn.periodograma(r["x"], r["fs"])[1], rel=1e-10, abs=1e-14)
    # Hann periódica (get_window da la periódica por defecto)
    f, P = signal.periodogram(np.asarray(r["x"]), fs=r["fs"], window="hann", nfft=32, detrend="constant", scaling="density")
    assert P == pytest.approx(sn.periodograma(r["x"], r["fs"], ventana="hann", nfft=32)[1], rel=1e-10, abs=1e-14)


def test_welch_frente_a_julia_y_scipy():
    r = REF["welch"]
    f, P = sn.psd_welch(r["x"], r["fs"], nseg=r["nseg"], solape=r["solape"])
    assert f == pytest.approx(r["f"])
    assert P == pytest.approx(r["P"], rel=1e-10, abs=1e-14)
    fs_, Ps_ = signal.welch(np.asarray(r["x"]), fs=r["fs"], window="hann", nperseg=r["nseg"], noverlap=r["nseg"] // 2,
                            detrend="constant", scaling="density")
    assert Ps_ == pytest.approx(P, rel=1e-10, abs=1e-14)


def test_parseval_dc_y_nyquist():
    fs, N, A, c = 100.0, 1000, 1.5, 0.7
    t = np.arange(N) / fs
    x = c + A * np.cos(2 * np.pi * 12.3 * t + 0.4)
    f, P = sn.periodograma(x, fs, quitar_media=False)
    df = f[1] - f[0]
    assert P[0] * df == pytest.approx(c**2)
    assert P.sum() * df == pytest.approx(c**2 + A**2 / 2)
    f, P = sn.periodograma((-1.0) ** np.arange(16), 16.0, quitar_media=False)
    assert P[-1] * (f[1] - f[0]) == pytest.approx(1.0)


def test_bandas_npsd_y_anpsd_frente_a_julia():
    r, w = REF["bandas"], REF["welch"]
    pot, frac = sn.potencia_bandas(w["f"], w["P"], r["bandas"])
    assert pot == pytest.approx(r["potencia"], rel=1e-10)
    assert frac == pytest.approx(r["fraccion"], rel=1e-10)
    fb, Pn = sn.psd_normalizada(w["f"], w["P"], r["banda_n"])
    assert fb == pytest.approx(r["f_n"])
    assert Pn == pytest.approx(r["Pn"], rel=1e-10)
    assert Pn.sum() == pytest.approx(1)
    _, A = sn.anpsd(w["f"], r["Ps"], r["banda_n"])
    assert A == pytest.approx(r["anpsd"], rel=1e-10)


def test_colorear_frente_a_julia():
    r = REF["colorear"]
    assert sn.colorear(r["r"], 1.0) == pytest.approx(r["rosa"], abs=1e-9)
    assert sn.colorear(r["r"], 2.0) == pytest.approx(r["marron"], abs=1e-9)
