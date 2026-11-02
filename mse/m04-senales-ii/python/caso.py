"""Caso integrado de M4 en Python: Palma del Río, ``set1`` (con tráfico) y ``set2`` (sin tráfico).

Es la pestaña Python de «Práctica guiada»: los mismos pasos que el caso en Julia, con ``procesado.py``. Este código no
se ejecuta en la web (véase CLAUDE.md): aquí está su versión probada, con ``pytest`` (``test_caso.py``), que la
contrasta con las cifras de Julia de ``../referencia/caso.json`` (``scripts/m04/generar_caso.jl``).
"""
import numpy as np

import procesado as pr

G0 = 9.80665   # gravedad estándar: 1 g = 9,80665 m/s² (hipótesis declarada: las fichas dicen «g» sin más)
# Las desviaciones típicas usan ddof=1 (divisor N−1), como `Statistics.std` de Julia; NumPy usa N por defecto.


def leer_csv(ruta):
    """Aceleración en m/s² y frecuencia de muestreo (Hz) de un CSV ``tiempo_s;aceleracion_g``."""
    d = np.loadtxt(ruta, delimiter=";", skiprows=1)
    return d[:, 1] * G0, round(1 / np.median(np.diff(d[:, 0])))


def resumen(x):
    """Media, RMS fluctuante, factor de cresta fluctuante y curtosis (momentos con divisor N)."""
    mu = x.mean()
    var = np.mean((x - mu) ** 2)
    return dict(media=mu, rms_fluctuante=np.sqrt(var), cresta_fluctuante=np.max(np.abs(x - mu)) / np.sqrt(var),
                curtosis=np.mean((x - mu) ** 4) / var**2)


def caso_integrado(ruta_set1, ruta_set2, q=8, cortes=(0.3, 0.5, 1.0)):
    """Ejecuta el caso completo y devuelve las cifras que muestra la página."""
    x1, fs = leer_csv(ruta_set1)
    x2, _ = leer_csv(ruta_set2)
    # 1-2. identificación e inspección
    sal = dict(fs=fs, N=len(x1), set1=resumen(x1), set2=resumen(x2))
    # 3. dónde está la energía y qué picos tiene (Welch con Hann, segmentos de 8192: Δf = 0,0625 Hz)
    f, P = pr.psd_welch(x1, fs, nseg=8192)
    bandas = [(0.0, 0.5), (0.5, 5.0), (5.0, 15.0), (15.0, 32.0), (32.0, 100.0), (100.0, 256.0)]
    sal["fraccion_potencia"] = pr.potencia_bandas(f, P, bandas)[1]
    sal["picos_Hz"] = f[pr.buscar_picos(f, P, fmin=1.0, fmax=60.0, n=6, separacion=0.5)]
    # 4. preprocesado: tendencia lineal, diezmado a 64 Hz (con antialiasing) y pasabanda de fase cero
    y, _ = pr.quitar_tendencia(x1, 1)
    yd = pr.diezmar(y, q)
    fsd = fs / q
    sos = pr.filtro_butterworth(4, (0.5, 25.0), fsd, "pasabanda")
    sal["rms_diezmado"], sal["N_diezmado"] = yd.std(ddof=1), len(yd)
    sal["rms_pasabanda"] = pr.filtrar_fase_cero(sos, yd).std(ddof=1)
    # 5. integración en frecuencia con varios cortes (mm/s y mm)
    sal["integracion"] = []
    for fc in cortes:
        v = pr.integrar_frecuencia(yd, fsd, fc, 1)
        d = pr.integrar_frecuencia(yd, fsd, fc, 2)
        sal["integracion"].append(dict(fcorte=fc, v_rms_mms=1000 * v.std(ddof=1), v_pico_mms=1000 * np.abs(v).max(),
                                       d_rms_mm=1000 * d.std(ddof=1), d_pico_mm=1000 * np.abs(d).max()))
    # 6. contraste con el registro sin tráfico, por bandas
    yd2 = pr.diezmar(pr.quitar_tendencia(x2, 1)[0], q)
    fa, Pa = pr.psd_welch(yd, fsd, nseg=1024)
    _, Pb = pr.psd_welch(yd2, fsd, nseg=1024)
    sal["cociente_trafico_fondo"] = [pr.potencia_bandas(fa, Pa, [b])[0][0] / pr.potencia_bandas(fa, Pb, [b])[0][0]
                                     for b in [(0.5, 5.0), (5.0, 15.0), (15.0, 30.0)]]
    return sal
