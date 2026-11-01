"""Procesamiento de señales de M3 en Python (NumPy).

Espejo de ``Resonancia.jl/src/muestreo.jl`` y ``Resonancia.jl/src/espectro.jl`` y de
``recursos/js/senales.js``: mismas convenciones, para contrastar Julia, JavaScript y Python con los
datos de ``../referencia/senales.json``. Este código no se ejecuta en la web (véase CLAUDE.md):
aquí está su versión probada, con ``pytest``.

Convenciones: DFT ``X[k] = Σ x[n] e^{-2πi kn/N}``; espectros unilaterales con los bins
``0…⌊nfft/2⌋``, duplicados salvo DC y (si ``nfft`` es par) Nyquist; PSD ``c_k |X|²/(fs Σw²)``;
amplitud ``c_k |X|/Σw``; Welch con Hann periódica y la media de cada segmento restada; momentos con
divisor N.
"""
import numpy as np


def ventana(nombre, N):
    """Ventana periódica de N puntos: rectangular, hann, hamming, blackman o flattop."""
    n = np.arange(N)
    c = lambda k: np.cos(2 * np.pi * k * n / N)  # noqa: E731
    if nombre == "rectangular":
        return np.ones(N)
    if nombre == "hann":
        return 0.5 - 0.5 * c(1)
    if nombre == "hamming":
        return 0.54 - 0.46 * c(1)
    if nombre == "blackman":
        return 0.42 - 0.5 * c(1) + 0.08 * c(2)
    if nombre == "flattop":
        return 0.21557895 - 0.41663158 * c(1) + 0.277263158 * c(2) - 0.083578947 * c(3) + 0.006947368 * c(4)
    raise ValueError(f"ventana desconocida: {nombre}")


def descriptores_temporales(x):
    """Media, varianza, RMS total y fluctuante, picos, factor de cresta, asimetría y curtosis (ordinaria y exceso)."""
    x = np.asarray(x, dtype=float)
    if x.size == 0:
        raise ValueError("la señal está vacía")
    mu = x.mean()
    var = np.mean((x - mu) ** 2)
    rms = np.sqrt(np.mean(x**2))
    sigma = np.sqrt(var)
    pico = np.max(np.abs(x))
    picof = np.max(np.abs(x - mu))
    k = np.mean((x - mu) ** 4) / var**2 if var > 0 else np.nan
    s3 = np.mean((x - mu) ** 3) / sigma**3 if var > 0 else np.nan
    return dict(media=mu, varianza=var, rms=rms, rms_fluctuante=sigma, pico=pico, pico_fluctuante=picof,
                pico_pico=x.max() - x.min(), cresta=pico / rms, cresta_fluctuante=picof / sigma,
                asimetria=s3, curtosis=k, curtosis_exceso=k - 3)


def cuantizar(x, bits, rango, offset=0.0):
    """Convertidor ideal: entrada ±rango, ``bits`` bits, offset sumado antes. Devuelve (y, saturada, q).

    ``bits`` debe ser un entero ≥ 1 (como en Resonancia.jl y en senales.js).
    """
    if isinstance(bits, bool) or not isinstance(bits, (int, np.integer)) or bits < 1:
        raise ValueError("bits debe ser un entero de al menos 1")
    if rango <= 0:
        raise ValueError("rango debe ser positivo")
    q = 2 * rango / 2.0**bits
    cmin, cmax = -(2.0 ** (bits - 1)), 2.0 ** (bits - 1) - 1
    c = np.round((np.asarray(x, dtype=float) + offset) / q)  # empates al par, como Julia
    saturada = (c < cmin) | (c > cmax)
    return np.clip(c, cmin, cmax) * q, saturada, q


def frecuencia_aparente(f, fs):
    """Frecuencia (Hz) en [0, fs/2] con la que aparece una sinusoide de ``f`` Hz muestreada a ``fs``."""
    return abs(f - fs * np.round(f / fs))


def _unilateral(nfft):
    nf = nfft // 2 + 1
    c = np.full(nf, 2.0)
    c[0] = 1.0
    if nfft % 2 == 0:
        c[-1] = 1.0
    return nf, c


def _preparar(x, nombre, nfft, quitar_media):
    x = np.asarray(x, dtype=float)
    N = x.size
    if nfft < N:
        raise ValueError(f"nfft ({nfft}) no puede ser menor que la longitud de la señal ({N})")
    w = ventana(nombre, N)
    s = x - x.mean() if quitar_media else x
    return w, np.fft.fft(s * w, nfft)  # np.fft.fft rellena con ceros hasta nfft


def periodograma(x, fs, ventana="rectangular", nfft=None, quitar_media=True):
    """PSD unilateral por periodograma: (f, P) en unidades²/Hz."""
    nfft = len(x) if nfft is None else nfft
    w, X = _preparar(x, ventana, nfft, quitar_media)
    nf, c = _unilateral(nfft)
    return np.arange(nf) * fs / nfft, c * np.abs(X[:nf]) ** 2 / (fs * np.sum(w**2))


def espectro_amplitud(x, fs, ventana="rectangular", nfft=None, quitar_media=False):
    """Espectro de amplitud unilateral (amplitud de pico) y fase: (f, A, fase)."""
    nfft = len(x) if nfft is None else nfft
    w, X = _preparar(x, ventana, nfft, quitar_media)
    nf, c = _unilateral(nfft)
    return np.arange(nf) * fs / nfft, c * np.abs(X[:nf]) / np.sum(w), np.angle(X[:nf])


def psd_welch(x, fs, nseg=4096, solape=0.5):
    """PSD de Welch (Hann periódica, media restada por segmento): (f, P).

    El paso entre segmentos es ``round(nseg·(1−solape))`` con empates al par, como en Julia y JS.
    A diferencia de Julia (``psd_welch`` exige ``nseg`` potencia de 2), aquí ``nseg`` puede ser
    cualquiera: NumPy hace la FFT de cualquier longitud. Exige ``0 ≤ solape < 1``.
    """
    x = np.asarray(x, dtype=float)
    if x.size < nseg:
        raise ValueError("la señal es más corta que un segmento")
    if not 0 <= solape < 1:
        raise ValueError("el solape debe estar en [0, 1)")
    paso = max(1, round(nseg * (1 - solape)))
    inicios = range(0, x.size - nseg + 1, paso)
    P = np.mean([periodograma(x[i:i + nseg], fs, ventana="hann")[1] for i in inicios], axis=0)
    return np.arange(nseg // 2 + 1) * fs / nseg, P


def potencia_bandas(f, P, bandas):
    """Σ P Δf en cada banda [fa, fb) y su fracción de la potencia total: (potencia, fraccion)."""
    f, P = np.asarray(f), np.asarray(P)
    df = f[1] - f[0]
    pot = np.array([P[(f >= fa) & (f < fb)].sum() * df for fa, fb in bandas])
    return pot, pot / (P.sum() * df)


def psd_normalizada(f, P, banda=None):
    """NPSD: bins de la banda cerrada divididos por su suma (fracción de potencia por bin): (fb, Pn)."""
    f, P = np.asarray(f), np.asarray(P)
    banda = (f[0], f[-1]) if banda is None else banda
    sel = (f >= banda[0]) & (f <= banda[1])
    if not sel.any():
        raise ValueError("ningún bin dentro de la banda")
    s = P[sel].sum()
    if s <= 0:
        raise ValueError("la PSD es nula en la banda")
    return f[sel], P[sel] / s


def anpsd(f, Ps, banda=None):
    """ANPSD: media de las NPSD de las columnas de ``Ps`` (bins × canales) en la misma banda: (fb, A)."""
    Ps = np.asarray(Ps)
    cols = [psd_normalizada(f, Ps[:, j], banda) for j in range(Ps.shape[1])]
    return cols[0][0], np.mean([c[1] for c in cols], axis=0)


def colorear(r, alfa):
    """Ruido de color: PSD ∝ 1/f^alfa a partir del ruido blanco ``r``; media 0 y desviación típica 1."""
    r = np.asarray(r, dtype=float)
    N = r.size
    if N < 2:
        raise ValueError("hacen falta al menos 2 muestras")
    X = np.fft.fft(r)
    k = np.arange(N)
    g = np.zeros(N)
    g[1:] = np.minimum(k[1:], N - k[1:]) ** (-alfa / 2)
    y = np.fft.ifft(X * g).real
    y -= y.mean()
    return y / np.sqrt(np.mean(y**2))


def aceleracion_1gdl(u, f0, zeta, fs):
    """Aceleración de un oscilador de 1 GDL, ``x'' + 2ζω x' + ω² x = u``, partiendo del reposo.

    Espejo de ``aceleracion_1gdl`` de ``Resonancia.jl/src/edos.jl``: discretización exacta con retenedor
    de orden cero (``u`` constante entre muestras). El elemento ``k`` es la aceleración en el instante
    ``k/fs`` con ``u[k]`` ya aplicada. ``f0`` y ``fs`` en Hz; exige 0 ≤ zeta < 1.
    """
    if not 0 <= zeta < 1:
        raise ValueError("zeta debe estar en [0, 1)")
    if f0 <= 0 or fs <= 0:
        raise ValueError("f0 y fs deben ser positivas")
    u = np.asarray(u, dtype=float)
    w = 2 * np.pi * f0
    wd = w * np.sqrt(1 - zeta**2)
    h = 1.0 / fs
    c, s, e = np.cos(wd * h), np.sin(wd * h), np.exp(-zeta * w * h)
    Phi = e * np.array([[c + zeta * w / wd * s, s / wd], [-(w**2) / wd * s, c - zeta * w / wd * s]])
    A = np.array([[0.0, 1.0], [-(w**2), -2 * zeta * w]])
    Gam = np.linalg.solve(A, (Phi - np.eye(2)) @ np.array([0.0, 1.0]))   # ∫₀ʰ e^{As} B ds
    z = np.zeros(2)
    a = np.empty(u.size)
    for k, uk in enumerate(u):
        a[k] = -2 * zeta * w * z[1] - w**2 * z[0] + uk
        z = Phi @ z + Gam * uk
    return a
