"""Pruebas de procesado.py frente a Julia (referencia/procesado.json) y frente a SciPy.

Ejecutar desde la raíz: ``uv run pytest mse/m04-senales-ii/python``
"""
import json
from pathlib import Path

import numpy as np
import pytest
from scipy import signal

import procesado as pr

REF = json.loads((Path(__file__).parent.parent / "referencia" / "procesado.json").read_text(encoding="utf-8"))


def cx(d):
    return np.array(d["re"]) + 1j * np.array(d["im"])


# ---------- frente a Julia ----------
def test_ventanas_frente_a_julia():
    r = REF["ventanas"]
    N = r["N"]
    for nombre in r["nombres"]:
        w, p = pr.ventana(nombre, N), r["propiedades"][nombre]
        assert pr.perdida_escalonamiento(w) == pytest.approx(p["perdida"], rel=1e-9)
        assert pr.ancho_banda_3db(w) == pytest.approx(p["ancho3db"], rel=1e-9)
        assert pr.nivel_lobulo_lateral(w) == pytest.approx(p["lobulo"], abs=1e-9)
        assert pr.ancho_banda_ruido(w) == pytest.approx(p["enbw"], rel=1e-12)
        assert pr.ganancia_coherente(w) == pytest.approx(p["gcoh"], rel=1e-12)
    wh, wr = pr.ventana("hann", N), pr.ventana("rectangular", N)
    assert pr.correlacion_solape(wh, 32) == pytest.approx(r["solape_hann_32"], rel=1e-12)
    assert pr.correlacion_solape(wr, 32) == pytest.approx(r["solape_rect_32"], rel=1e-12)
    assert pr.correlacion_solape(wh, 0) == r["solape_hann_0"]
    assert pr.correlacion_solape(wh, 64) == r["solape_hann_64"]
    for v in r["varianza_welch"]:
        K, var = pr.varianza_welch(pr.ventana(v["nombre"], N), v["solape"], r["longitud"])
        assert K == v["K"]
        assert var == pytest.approx(v["var"], rel=1e-12)


def test_tendencia_frente_a_julia():
    r = REF["tendencia"]
    for g, res in r["resultados"].items():
        y, t = pr.quitar_tendencia(r["x"], int(g))
        assert y == pytest.approx(res["y"], abs=1e-12)
        assert t == pytest.approx(res["tendencia"], abs=1e-12)


def test_interpolar_frente_a_julia():
    r = REF["interpolar"]
    tu, xu, hueco = pr.interpolar_uniforme(r["t"], r["x"], r["fs"])
    assert tu == pytest.approx(r["tu"], abs=1e-12)
    assert xu == pytest.approx(r["xu"], abs=1e-12)
    assert list(hueco) == r["hueco"]


def test_integracion_frente_a_julia():
    r = REF["integracion"]
    assert pr.integrar_trapecio(r["x"], r["fs"]) == pytest.approx(r["trapecio"], abs=1e-12)
    assert pr.integrar_frecuencia(r["x"], r["fs"], r["fcorte"], 1) == pytest.approx(r["frecuencia1"], abs=1e-10)
    assert pr.integrar_frecuencia(r["x"], r["fs"], r["fcorte"], 2) == pytest.approx(r["frecuencia2"], abs=1e-10)


def test_snr_frente_a_julia():
    r = REF["snr"]
    assert pr.snr_db(r["x"], r["ruido"]) == pytest.approx(r["snr_db"], rel=1e-12)
    assert pr.snr_banda(r["f"], r["P"], r["Pruido"], r["banda"]) == pytest.approx(r["snr_banda"], rel=1e-12)
    assert pr.snr_banda(r["f"], r["P"], r["Pruido"], [0.0, 10.5]) == pytest.approx(r["snr_banda_total"], rel=1e-12)
    assert pr.rms_ruido_banda(r["densidad"], r["fa"], r["fb"]) == pytest.approx(r["rms_banda"], rel=1e-12)


def test_cruzados_frente_a_julia():
    r = REF["cruzados"]
    e = pr.estimar_frf(r["x"], r["y"], r["fs"], r["nseg"], r["solape"])
    assert e["f"] == pytest.approx(r["f"], abs=1e-12)
    assert e["Gxx"] == pytest.approx(r["Gxx"], rel=1e-10)
    assert e["Gyy"] == pytest.approx(r["Gyy"], rel=1e-10)
    assert e["Gxy"] == pytest.approx(cx(r["Gxy"]), rel=1e-10, abs=1e-14)
    assert e["coherencia"] == pytest.approx(r["coherencia"], rel=1e-9)
    assert e["H1"] == pytest.approx(cx(r["H1"]), rel=1e-9, abs=1e-12)
    assert e["H2"] == pytest.approx(cx(r["H2"]), rel=1e-9, abs=1e-12)
    # identidad: H1/H2 = γ²
    assert e["H1"] / e["H2"] == pytest.approx(e["coherencia"], rel=1e-9)


def test_espectrograma_frente_a_julia():
    r = REF["espectrograma"]
    t, f, P = pr.espectrograma(r["x"], r["fs"], r["nseg"], r["solape"])
    assert t == pytest.approx(r["t"], abs=1e-12)
    assert f == pytest.approx(r["f"], abs=1e-12)
    assert P == pytest.approx(np.array(r["P"]), rel=1e-9, abs=1e-15)


def test_butterworth_frente_a_julia():
    for d in REF["filtros"]["butterworth"]:
        fc = tuple(d["fc"]) if isinstance(d["fc"], list) else d["fc"]
        sos = pr.filtro_butterworth(d["orden"], fc, d["fs"], d["tipo"])
        assert sos == pytest.approx(np.array(d["sos"]), abs=1e-11), d["tipo"]
        assert pr.respuesta_iir(sos, d["f"], d["fs"]) == pytest.approx(cx(d["H"]), abs=1e-11)
        assert pr.retardo_grupo_iir(sos, d["f_retardo"], d["fs"]) == pytest.approx(d["retardo"], rel=1e-9)


def test_fir_frente_a_julia():
    for d in REF["filtros"]["fir"]:
        fc = tuple(d["fc"]) if isinstance(d["fc"], list) else d["fc"]
        b = pr.filtro_fir(d["ntaps"], fc, d["fs"], d["tipo"], d["ventana"])
        assert b == pytest.approx(d["b"], abs=1e-13), d["tipo"]
        assert pr.respuesta_fir(b, d["f"], d["fs"]) == pytest.approx(cx(d["H"]), abs=1e-12)
        assert pr.retardo_grupo_fir(b, [5.0], d["fs"])[0] == pytest.approx(d["retardo"], rel=1e-9)


def test_filtrado_frente_a_julia():
    r = REF["filtros"]
    lp = pr.filtro_butterworth(3, 10.0, 100.0)
    hp = pr.filtro_fir(21, 10.0, 100.0)
    assert pr.filtrar_iir(lp, r["x"]) == pytest.approx(r["iir_causal"], abs=1e-11)
    assert pr.filtrar_fase_cero(lp, r["x"]) == pytest.approx(r["iir_fase_cero"], abs=1e-10)
    assert pr.filtrar_fir(hp, r["x"]) == pytest.approx(r["fir_causal"], abs=1e-11)
    assert pr.filtrar_fir(hp, r["x"], compensar=True) == pytest.approx(r["fir_compensado"], abs=1e-11)
    assert pr.filtrar_fase_cero(hp, r["x"]) == pytest.approx(r["fir_fase_cero"], abs=1e-10)
    assert pr.diezmar(r["x_diezmar"], r["diezmar_q"]) == pytest.approx(r["diezmado"], abs=1e-11)


# ---------- frente a SciPy (árbitro independiente) ----------
def _ruido(n, semilla):
    return np.random.default_rng(semilla).standard_normal(n)


def test_welch_cruzado_y_coherencia_frente_a_scipy():
    x = _ruido(2048, 1)
    y = signal.lfilter([0.2, 0.3, 0.2], [1, -0.6], x) + 0.3 * _ruido(2048, 2)
    fs, nseg = 100.0, 128
    f, Gxx, Gyy, Gxy = pr.espectros_cruzados(x, y, fs, nseg, 0.5)
    fs_, Pxx = signal.welch(x, fs, window="hann", nperseg=nseg, noverlap=nseg // 2)
    assert f == pytest.approx(fs_) and Gxx == pytest.approx(Pxx, rel=1e-10)
    _, Pxy = signal.csd(x, y, fs, window="hann", nperseg=nseg, noverlap=nseg // 2)
    # SciPy da Pxy = conj(X)·Y promediado, como aquí
    assert Gxy == pytest.approx(Pxy, rel=1e-9)
    _, Cxy = signal.coherence(x, y, fs, window="hann", nperseg=nseg, noverlap=nseg // 2)
    assert pr.coherencia(Gxx, Gyy, Gxy) == pytest.approx(Cxy, rel=1e-9)


def test_espectrograma_frente_a_scipy():
    x = _ruido(1000, 3)
    fs, nseg = 50.0, 64
    t, f, P = pr.espectrograma(x, fs, nseg, 0.75)
    fs_, ts, S = signal.spectrogram(x, fs, window="hann", nperseg=nseg, noverlap=48, scaling="density", mode="psd")
    assert f == pytest.approx(fs_) and t == pytest.approx(ts)
    assert P == pytest.approx(S, rel=1e-9)
    # el promedio temporal es la PSD de Welch
    _, Pw = signal.welch(x, fs, window="hann", nperseg=nseg, noverlap=48)
    assert P.mean(axis=1) == pytest.approx(Pw, rel=1e-9)


@pytest.mark.parametrize("orden,fc,fs,tipo,tipo_scipy", [
    (4, 0.5, 500.0, "pasaaltos", "highpass"), (3, 10.0, 100.0, "pasabajos", "lowpass"),
    (2, (8.0, 12.0), 100.0, "pasabanda", "bandpass"), (2, (49.0, 51.0), 500.0, "rechazabanda", "bandstop"),
    (5, 0.3, 100.0, "pasabajos", "lowpass"), (6, (1.0, 20.0), 200.0, "pasabanda", "bandpass"),
])
def test_butterworth_frente_a_scipy(orden, fc, fs, tipo, tipo_scipy):
    sos = pr.filtro_butterworth(orden, fc, fs, tipo)
    ref = signal.butter(orden, fc, btype=tipo_scipy, fs=fs, output="sos")
    f = np.geomspace(0.01 * fs / 100, 0.499 * fs, 300)
    _, H = signal.sosfreqz(ref, worN=f, fs=fs)
    assert pr.respuesta_iir(sos, f, fs) == pytest.approx(H, abs=1e-9)
    x = _ruido(600, 4)
    assert pr.filtrar_iir(sos, x) == pytest.approx(signal.sosfilt(ref, x), abs=1e-9)
    # fase cero: SciPy y aquí extienden la señal por reflexión impar y parten del estado estacionario. La longitud
    # del relleno por defecto es distinta (y en filtros muy lentos, como el de 0,3 Hz, cambia el resultado incluso
    # en el interior), así que se le da a SciPy la misma, 3·(2·secciones + 1), y se compara el registro completo.
    npad = 3 * (2 * len(sos) + 1)
    assert pr.filtrar_fase_cero(sos, x) == pytest.approx(signal.sosfiltfilt(ref, x, padlen=npad), abs=1e-7)


@pytest.mark.parametrize("ntaps,fc,tipo,tipo_scipy,nombre", [
    (21, 10.0, "pasabajos", dict(pass_zero="lowpass"), "hamming"),
    (21, 10.0, "pasaaltos", dict(pass_zero="highpass"), "hann"),
    (31, (10.0, 20.0), "pasabanda", dict(pass_zero="bandpass"), "blackman"),
    (31, (10.0, 20.0), "rechazabanda", dict(pass_zero="bandstop"), "hamming"),
    (51, 10.0, "pasaaltos", dict(pass_zero="highpass"), "hamming"),   # DSP.jl invierte aquí la polaridad; SciPy no
])
def test_fir_frente_a_scipy(ntaps, fc, tipo, tipo_scipy, nombre):
    b = pr.filtro_fir(ntaps, fc, 100.0, tipo, nombre)
    assert b == pytest.approx(signal.firwin(ntaps, fc, window=nombre, fs=100.0, **tipo_scipy), abs=1e-13)


# ---------- propiedades ----------
def test_valores_de_referencia_de_ventanas():
    w = {n: pr.ventana(n, 256) for n in ("rectangular", "hann", "blackman", "flattop")}
    assert pr.perdida_escalonamiento(w["rectangular"]) == pytest.approx(3.92, abs=0.01)
    assert pr.perdida_escalonamiento(w["hann"]) == pytest.approx(1.42, abs=0.01)
    assert pr.perdida_escalonamiento(w["flattop"]) < 0.05
    assert pr.nivel_lobulo_lateral(w["hann"]) == pytest.approx(-31.47, abs=0.1)
    assert pr.nivel_lobulo_lateral(w["flattop"]) < -80
    anchos = [pr.ancho_banda_3db(w[n]) for n in ("rectangular", "hann", "blackman", "flattop")]
    assert anchos == sorted(anchos)  # a más supresión de fuga, lóbulo principal más ancho


def test_butterworth_tabla_neuromind():
    """Paso alto de orden 4, fc = 0,5 Hz, fs = 500 Hz: valores de la Tabla 6.1 del capítulo de filtrado de NeuroMIND."""
    sos = pr.filtro_butterworth(4, 0.5, 500.0, "pasaaltos")
    f = [0.1, 0.25, 0.5, 1.0, 2.0, 5.0]
    H = pr.respuesta_iir(sos, f, 500.0)
    assert 20 * np.log10(np.abs(H)) == pytest.approx([-55.92, -24.10, -3.01, -0.02, 0.0, 0.0], abs=0.006)
    assert 40 * np.log10(np.abs(H)) == pytest.approx([-111.84, -48.20, -6.02, -0.03, 0.0, 0.0], abs=0.012)
    fase = np.degrees(np.angle(H))
    assert fase[[0, 1, 3, 4, 5]] == pytest.approx([-30.1, -78.0, 78.0, 37.8, 15.0], abs=0.05)
    assert abs(fase[2]) == pytest.approx(180, abs=0.06)


def test_fase_cero_y_corte_efectivo():
    fs = 100.0
    lp = pr.filtro_butterworth(4, 2.0, fs)
    # con fase cero la ganancia es |H|²: −6,02 dB en fc y el punto de −3 dB baja a (√2−1)^(1/2N)·fc
    assert 20 * np.log10(abs(pr.respuesta_iir(lp, 2.0, fs)[0]) ** 2) == pytest.approx(-6.0206, abs=1e-3)
    f3 = fs / np.pi * np.arctan((np.sqrt(2) - 1) ** (1 / 8) * np.tan(np.pi * 2.0 / fs))
    assert abs(pr.respuesta_iir(lp, f3, fs)[0]) ** 2 == pytest.approx(1 / np.sqrt(2), rel=1e-9)
    # el filtrado causal retrasa; el de fase cero, no
    t = np.arange(3000) / fs
    s = np.sin(2 * np.pi * 1.1 * t)
    lag = lambda u, v: int(np.argmax(np.correlate(v - v.mean(), u - u.mean(), "full"))) - (len(u) - 1)  # noqa: E731
    assert lag(s, pr.filtrar_iir(lp, s)) > 0
    assert lag(s, pr.filtrar_fase_cero(lp, s)) == 0


def test_integracion_y_deriva():
    fs, f0 = 100.0, 5.0
    t = np.arange(1000) / fs
    x = np.cos(2 * np.pi * f0 * t)
    w = 2 * np.pi * f0
    assert pr.integrar_frecuencia(x + 0.3, fs, 1.0, 1) == pytest.approx(np.sin(w * t) / w, abs=1e-10)
    assert pr.integrar_frecuencia(x, fs, 1.0, 2) == pytest.approx(-np.cos(w * t) / w**2, abs=1e-10)
    # un offset c en la aceleración da una rampa c·t en la velocidad al integrar con el trapecio
    assert pr.integrar_trapecio(np.full(1000, 0.2), fs)[-1] == pytest.approx(0.2 * 999 / fs)


def test_h1_h2_sesgos_con_ruido():
    """Ruido en la salida: H1 insesgada y H2 sobrestimada; ruido en la entrada: al revés (M4.6)."""
    rng = np.random.default_rng(7)
    N, fs = 2**16, 100.0
    x = rng.standard_normal(N)
    sos = pr.filtro_butterworth(2, (8.0, 12.0), fs, "pasabanda")
    y = signal.sosfilt(sos, x)
    k = None
    s = pr.estimar_frf(x, y + 0.5 * rng.standard_normal(N), fs, 1024)
    k = int(np.argmax(np.abs(pr.respuesta_iir(sos, s["f"], fs))))
    Hver = pr.respuesta_iir(sos, s["f"], fs)[k]
    assert abs(s["H1"][k]) == pytest.approx(abs(Hver), rel=0.08)
    assert abs(s["H2"][k]) > 1.1 * abs(Hver)
    q = pr.estimar_frf(x + 0.8 * rng.standard_normal(N), y, fs, 1024)
    assert abs(q["H2"][k]) == pytest.approx(abs(Hver), rel=0.08)
    assert abs(q["H1"][k]) < 0.9 * abs(Hver)


def test_diezmar_evita_el_aliasing():
    fs = 100.0
    t = np.arange(4000) / fs
    alias = np.sin(2 * np.pi * 40.0 * t)
    rms = lambda v: np.sqrt(np.mean(v**2))  # noqa: E731
    assert rms(alias[::4]) == pytest.approx(1 / np.sqrt(2), rel=0.01)  # sin filtrar se pliega entero
    assert rms(pr.diezmar(alias, 4)[100:900]) < 0.01
    ok = pr.diezmar(np.sin(2 * np.pi * 1.0 * t), 4)
    assert ok[100:900] == pytest.approx(np.sin(2 * np.pi * 1.0 * t[::4])[100:900], abs=5e-3)


def test_errores():
    with pytest.raises(ValueError):
        pr.filtro_butterworth(0, 10.0, 100.0)
    with pytest.raises(ValueError):
        pr.filtro_butterworth(2, 60.0, 100.0)
    with pytest.raises(ValueError):
        pr.filtro_butterworth(2, 10.0, 100.0, "pasabanda")
    with pytest.raises(ValueError):
        pr.filtro_fir(100, 10.0, 100.0, "pasaaltos")
    with pytest.raises(ValueError):
        pr.integrar_frecuencia(np.ones(8), 10.0, 1.0, orden=3)
    with pytest.raises(ValueError):
        pr.espectros_cruzados(np.ones(100), np.ones(99), 10.0)
    with pytest.raises(ValueError):
        pr.varianza_welch(pr.ventana("hann", 8), 1.0, 64)
    with pytest.raises(ValueError):
        pr.interpolar_uniforme([0.0, 1.0, 1.0], [1, 2, 3], 1.0)


def test_oscilador_frente_a_julia_y_resonancia():
    r = REF["oscilador"]
    a = pr.aceleracion_1gdl(r["u"], r["f0"], r["zeta"], r["fs"])
    assert a == pytest.approx(r["a"], abs=1e-11)
    # la FRF estimada con H1 coincide con la VERDADERA del sistema muestreado, que es la DFT de su respuesta
    # impulsional (decae del todo en 10 s). No es la continua −ω²/(ω0² − ω² + 2iζω0ω): el retenedor de orden cero y
    # la transmisión directa en el inicio de cada intervalo la modifican (módulo ≈ igual a baja frecuencia; fase, no).
    rng = np.random.default_rng(11)
    u = rng.standard_normal(2**16)
    fs, f0, z = 100.0, 5.0, 0.05
    e = pr.estimar_frf(u, pr.aceleracion_1gdl(u, f0, z, fs), fs, 1024)
    impulso = np.zeros(1024)
    impulso[0] = 1.0
    teo = np.fft.rfft(pr.aceleracion_1gdl(impulso, f0, z, fs))
    banda = (e["f"] > 2) & (e["f"] < 15)
    assert np.abs(e["H1"][banda] / teo[banda] - 1).max() < 0.12
    with pytest.raises(ValueError):
        pr.aceleracion_1gdl(u, f0, 1.0, fs)


def test_wavelet_frente_a_julia_y_propiedades():
    r = REF["wavelet"]
    W = pr.cwt_morlet(r["x"], r["fs"], r["frecuencias"], r["w0"])
    assert W == pytest.approx(np.array(r["W"]), rel=1e-9, abs=1e-12)
    # una sinusoide de amplitud a da ≈ a en su fila y la respuesta gaussiana del filtro en las demás
    fs, N, a = 100.0, 2000, 1.3
    t = np.arange(N) / fs
    W = pr.cwt_morlet(a * np.sin(2 * np.pi * 5.0 * t), fs, [3.0, 5.0, 8.0])
    assert W[1, 400:1600] == pytest.approx(a, rel=0.01)
    for i, f in ((0, 3.0), (2, 8.0)):
        assert W[i, 400:1600].max() == pytest.approx(a * np.exp(-((6 * 5.0 / f - 6) ** 2) / 2), rel=0.02)
    with pytest.raises(ValueError):
        pr.cwt_morlet(np.zeros(10), fs, [60.0])
