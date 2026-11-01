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


def test_aceleracion_1gdl_frente_a_julia_y_a_la_solucion_exacta():
    f0, z, fs = 4.0, 0.015, 200.0
    t = np.arange(0, 2, 1 / fs)
    # valores de Resonancia.aceleracion_1gdl(sin(2π·3t) + 0.5, 4, 0.015, 200), índices 1-based 2, 50, 100, 250, 400
    a = sn.aceleracion_1gdl(np.sin(2 * np.pi * 3.0 * t) + 0.5, f0, z, fs)
    esperado = {2: 5.882941532456840e-01, 50: 1.354282611785695e00, 100: -2.022743459841400e-01,
                250: 1.319692224763835e00, 400: 3.405416540202140e-01}
    for k, v in esperado.items():
        assert a[k - 1] == pytest.approx(v, abs=1e-12)
    # escalón unitario: x'' = e^{-ζωt}(cos ω_d t − ζω/ω_d sin ω_d t) en los instantes de muestreo
    w = 2 * np.pi * f0
    wd = w * np.sqrt(1 - z**2)
    t5 = np.arange(0, 5, 1 / fs)
    esc = sn.aceleracion_1gdl(np.ones(t5.size), f0, z, fs)
    assert esc == pytest.approx(np.exp(-z * w * t5) * (np.cos(wd * t5) - z * w / wd * np.sin(wd * t5)), abs=1e-10)
    assert esc[0] == 1.0
    with pytest.raises(ValueError):
        sn.aceleracion_1gdl(esc, f0, 1.0, fs)


def _serie(N):
    n = np.arange(N)
    return np.sin(0.37 * n) + 0.3 * np.cos(1.9 * n * n / N) + 0.01 * n


def _welch_directo(x, fs, nseg, paso):
    """Promedio de periodogramas a mano: DFT directa, Hann periódica y media restada por segmento."""
    n = np.arange(nseg)
    w = 0.5 - 0.5 * np.cos(2 * np.pi * n / nseg)
    nf = nseg // 2 + 1
    c = np.full(nf, 2.0)
    c[0] = 1.0
    if nseg % 2 == 0:
        c[-1] = 1.0
    E = np.exp(-2j * np.pi * np.outer(np.arange(nf), n) / nseg)
    Ps = [c * np.abs(E @ ((x[i:i + nseg] - x[i:i + nseg].mean()) * w)) ** 2 / (fs * np.sum(w**2))
          for i in range(0, len(x) - nseg + 1, paso)]
    return np.mean(Ps, axis=0), len(Ps)


def test_welch_nseg_no_potencia_de_2_frente_al_calculo_directo():
    # Julia exige potencia de 2; Python (NumPy) y JS no
    x = _serie(97)
    for nseg, solape, paso in ((12, 0.5, 6), (12, 0.3, 8), (15, 0.5, 8), (30, 0.0, 30)):
        f, P = sn.psd_welch(x, 50.0, nseg=nseg, solape=solape)
        esperado, _ = _welch_directo(x, 50.0, nseg, paso)
        assert f == pytest.approx(np.arange(nseg // 2 + 1) * 50.0 / nseg)
        assert P == pytest.approx(esperado, rel=1e-10, abs=1e-14), (nseg, solape)


def test_welch_paso_redondeado_al_par_con_solape_distinto_de_medio():
    # nseg·(1−solape) = 2,5 → paso 2 (no 3), igual que Julia y senales.js
    x = _serie(30)
    _, P = sn.psd_welch(x, 10.0, nseg=10, solape=0.75)
    esperado, K = _welch_directo(x, 10.0, 10, 2)
    assert K == 11
    assert P == pytest.approx(esperado, rel=1e-10, abs=1e-14)
    _, P3 = sn.psd_welch(x, 10.0, nseg=10, solape=0.75)
    assert P3 != pytest.approx(_welch_directo(x, 10.0, 10, 3)[0], rel=1e-6)


def test_welch_valida_solape_y_longitud():
    x = _serie(40)
    for solape in (1.0, 1.5, -0.1):
        with pytest.raises(ValueError, match="solape"):
            sn.psd_welch(x, 1.0, nseg=16, solape=solape)
    with pytest.raises(ValueError, match="más corta"):
        sn.psd_welch(x[:10], 1.0, nseg=16)
    sn.psd_welch(x, 1.0, nseg=16, solape=0.0)   # el límite inferior es válido


def test_cuantizar_exige_bits_enteros_y_rango_positivo():
    for bits in (0, -3, 2.5, 6.0, True):
        with pytest.raises(ValueError, match="bits"):
            sn.cuantizar([0.1], bits, 1.0)
    with pytest.raises(ValueError, match="rango"):
        sn.cuantizar([0.1], 8, 0.0)
    y, sat, q = sn.cuantizar([-2.0, -0.4, 0.6, 2.0], np.int64(1), 1.0)   # enteros de NumPy válidos
    assert q == 1.0
    assert list(y) == [-1.0, 0.0, 0.0, 0.0]
    assert list(sat) == [True, False, True, True]


def test_periodograma_nfft_impar_sin_bin_de_nyquist():
    x = np.array([0.3, -1, 2, 0.5, 0, 1.5, -0.7])
    f, P = sn.periodograma(x, 14.0)
    assert len(f) == 4 and f[-1] == pytest.approx(3 * 14.0 / 7) and f[-1] < 7.0
    X = np.fft.fft(x - x.mean())
    c = np.array([1.0, 2.0, 2.0, 2.0])
    assert P == pytest.approx(c * np.abs(X[:4]) ** 2 / (14.0 * 7), rel=1e-12)
    assert P.sum() * (f[1] - f[0]) == pytest.approx(np.var(x), rel=1e-12)   # Parseval
    f9, _ = sn.periodograma(x, 14.0, nfft=9)
    assert len(f9) == 5 and f9[-1] == pytest.approx(4 * 14.0 / 9)


def test_colorear_alfa_negativo_y_n_pequeno():
    r = [0.5, -1.2, 0.3, 2.0, -0.7, 1.1, 0.0, -0.4]
    # mismos valores que fija senales.test.mjs para JavaScript
    assert sn.colorear(r, -1.5) == pytest.approx(
        [0.670970912753846, -1.2225830400063322, -0.030707952870855457, 1.690768615776496,
         -1.376279885780816, 1.0027615123591611, -0.2540871562133232, -0.48084300601817614], abs=1e-10)
    assert sn.colorear(r, -0.5) == pytest.approx(
        [0.46523927993660225, -1.3870954808922518, 0.057425374544008555, 1.817570095985223,
         -1.1219326355216575, 0.9595223913870771, -0.22127034599714104, -0.5694586794418606], abs=1e-10)
    # N = 2: solo queda el bin k = 1 (ganancia 1): ±(1, −1) según el signo de r0 − r1
    assert sn.colorear([3.0, 1.0], 1.0) == pytest.approx([1.0, -1.0], abs=1e-12)
    assert sn.colorear([1.0, 3.0], 2.0) == pytest.approx([-1.0, 1.0], abs=1e-12)
    assert sn.colorear([1.0, 3.0], -3.0) == pytest.approx([-1.0, 1.0], abs=1e-12)
    assert sn.colorear([0.2, -1.0, 0.7], 1.0) == pytest.approx([0.32708852, -1.35508101, 1.02799249], abs=1e-7)
    for a in (-2.0, -1.0, 0.0, 1.0, 2.0):
        y = sn.colorear(r, a)
        assert y.mean() == pytest.approx(0, abs=1e-12) and y.std() == pytest.approx(1, abs=1e-12)
    with pytest.raises(ValueError, match="2 muestras"):
        sn.colorear([1.0], 1.0)
