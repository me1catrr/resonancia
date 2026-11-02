"""Procesamiento de señales de M4 en Python (NumPy).

Espejo de ``Resonancia.jl/src/{ventanas,preprocesado,integracion,cruzado,filtros}.jl`` y de
``recursos/js/procesado.js``: mismas convenciones, para contrastar Julia, JavaScript y Python con los
datos de ``../referencia/procesado.json``. Este código no se ejecuta en la web (véase CLAUDE.md):
aquí está su versión probada, con ``pytest``.

Convenciones: espectros unilaterales con los bins ``0…⌊nseg/2⌋``, duplicados salvo DC y (si ``nseg`` es par)
Nyquist; PSD ``c_k |X|²/(fs Σw²)``; espectro cruzado ``Gxy = promedio(conj(X)·Y)`` con la misma escala, de modo
que ``H1 = Gxy/Gxx`` y ``H2 = Gyy/conj(Gxy)``; media restada en cada segmento. Los filtros FIR son un vector
``b``; los IIR, una matriz ``sos`` con filas ``[b0 b1 b2 1 a1 a2]``.
"""
import numpy as np


# ---------- ventanas (M4.1) ----------
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


def ventana_simetrica(nombre, L):
    """Ventana simétrica de L puntos (la que se usa para diseñar filtros)."""
    if L == 1:
        return np.ones(1)
    w = ventana(nombre, L - 1)
    return np.append(w, w[0])


def ganancia_coherente(w):
    return np.sum(w) / len(w)


def ancho_banda_ruido(w):
    """ENBW en bins: N Σw² / (Σw)²."""
    return len(w) * np.sum(w**2) / np.sum(w) ** 2


def _modulo_ventana(w, nu):
    n = np.arange(len(w))
    return abs(np.sum(w * np.exp(-2j * np.pi * nu * n / len(w))))


def _primer_cruce(w, nivel, paso=0.01):
    W0, nmax = _modulo_ventana(w, 0.0), len(w) / 2
    a = 0.0
    while a + paso <= nmax:
        if _modulo_ventana(w, a + paso) / W0 <= nivel:
            b = a + paso
            for _ in range(50):
                m = (a + b) / 2
                if _modulo_ventana(w, m) / W0 > nivel:
                    a = m
                else:
                    b = m
            return (a + b) / 2
        a += paso
    raise ValueError(f"la respuesta de la ventana no baja de {nivel} antes de {nmax} bins")


def perdida_escalonamiento(w):
    """Pérdida por escalonamiento en dB: la amplitud de un tono a medio bin."""
    return -20 * np.log10(_modulo_ventana(w, 0.5) / _modulo_ventana(w, 0.0))


def ancho_banda_3db(w):
    """Ancho del lóbulo principal a -3 dB, en bins."""
    return 2 * _primer_cruce(w, 1 / np.sqrt(2))


def nivel_lobulo_lateral(w, paso=0.02):
    """Nivel (dB) del mayor lóbulo lateral respecto del principal."""
    W0 = _modulo_ventana(w, 0.0)
    nmax = min(len(w) / 2, 64.0)
    nus = np.arange(int(np.floor(nmax / paso + 1e-9)) + 1) * paso
    m = np.array([_modulo_ventana(w, nu) for nu in nus])
    i = int(np.argmax(m <= W0 / np.sqrt(2)))
    if m[i] > W0 / np.sqrt(2):
        raise ValueError("la respuesta de la ventana no baja de -3 dB")
    while i < len(m) - 1 and m[i + 1] <= m[i]:
        i += 1
    return 20 * np.log10(m[i:].max() / W0)


def correlacion_solape(w, s):
    """Correlación entre segmentos consecutivos de Welch desplazados s muestras: Σ w[n] w[n+s] / Σ w²."""
    N = len(w)
    if s < 0:
        raise ValueError("el desplazamiento no puede ser negativo")
    if s >= N:
        return 0.0
    return float(np.sum(w[: N - s] * w[s:]) / np.sum(w**2))


def varianza_welch(w, solape, longitud):
    """(K, varianza relativa) de la PSD de Welch frente a la de un solo periodograma."""
    N = len(w)
    if not 0 <= solape < 1:
        raise ValueError("el solape debe estar en [0, 1)")
    if longitud < N:
        raise ValueError("el registro es más corto que un segmento")
    D = max(1, int(round(N * (1 - solape))))
    K = (longitud - N) // D + 1
    s = sum((1 - j / K) * correlacion_solape(w, j * D) ** 2 for j in range(1, K))
    return K, (1 + 2 * s) / K


# ---------- preprocesado (M4.3) ----------
def quitar_tendencia(x, grado=1):
    """Resta el polinomio de grado ``grado`` ajustado por mínimos cuadrados. Devuelve (y, tendencia)."""
    x = np.asarray(x, dtype=float)
    N = len(x)
    if grado < 0:
        raise ValueError("el grado no puede ser negativo")
    if N <= grado:
        raise ValueError(f"hacen falta más de {grado} muestras para ajustar un polinomio de grado {grado}")
    s = np.zeros(1) if N == 1 else np.linspace(-1, 1, N)
    A = np.vander(s, grado + 1, increasing=True)
    tendencia = A @ np.linalg.lstsq(A, x, rcond=None)[0]
    return x - tendencia, tendencia


def interpolar_uniforme(t, x, fs, tolerancia=1.5):
    """Remuestrea a una rejilla uniforme de ``fs`` Hz por interpolación lineal. Devuelve (tu, xu, hueco)."""
    t, x = np.asarray(t, dtype=float), np.asarray(x, dtype=float)
    if len(t) != len(x):
        raise ValueError("t y x deben tener la misma longitud")
    if fs <= 0:
        raise ValueError("fs debe ser positiva")
    ok = np.isfinite(t) & np.isfinite(x)
    tt, xx = t[ok], x[ok]
    if len(tt) < 2:
        raise ValueError("hacen falta al menos 2 muestras válidas")
    if not np.all(np.diff(tt) > 0):
        raise ValueError("los instantes deben ser estrictamente crecientes")
    n = int(np.floor((tt[-1] - tt[0]) * fs + 1e-9)) + 1
    tu = tt[0] + np.arange(n) / fs
    xu = np.empty(n)
    hueco = np.zeros(n, dtype=bool)
    j = 0
    for k, tau in enumerate(tu):
        while j < len(tt) - 2 and tt[j + 1] < tau:
            j += 1
        a, b = tt[j], tt[j + 1]
        xu[k] = xx[j] + (xx[j + 1] - xx[j]) * (tau - a) / (b - a)
        hueco[k] = (b - a) > tolerancia / fs
    return tu, xu, hueco


# ---------- integración y ruido (M4.4, M4.5) ----------
def integrar_trapecio(x, fs):
    """Integral acumulada por la regla del trapecio, con valor inicial 0."""
    if fs <= 0:
        raise ValueError("fs debe ser positiva")
    x = np.asarray(x, dtype=float)
    v = np.zeros(len(x))
    v[1:] = np.cumsum((x[:-1] + x[1:]) / (2 * fs))
    return v


def integrar_frecuencia(x, fs, fcorte, orden=1):
    """Integra ``orden`` veces en frecuencia, anulando lo que queda por debajo de ``fcorte`` y la continua."""
    x = np.asarray(x, dtype=float)
    N = len(x)
    if N < 2:
        raise ValueError("hacen falta al menos 2 muestras")
    if fs <= 0:
        raise ValueError("fs debe ser positiva")
    if fcorte < 0:
        raise ValueError("fcorte no puede ser negativa")
    if orden not in (1, 2):
        raise ValueError("orden debe ser 1 o 2")
    X = np.fft.fft(x)
    k = np.arange(N)
    kk = np.where(k <= N // 2, k, k - N)
    f = np.abs(kk) * fs / N
    with np.errstate(divide="ignore", invalid="ignore"):
        Y = X / (1j * 2 * np.pi * kk * fs / N) ** orden
    Y[(k == 0) | (f < fcorte)] = 0.0
    return np.fft.ifft(Y).real


def _potencia(v):
    v = np.asarray(v, dtype=float)
    return np.sum((v - v.mean()) ** 2) / len(v)


def snr_db(x, ruido):
    """Relación señal-ruido en dB con la potencia igual a la varianza de cada registro."""
    pn = _potencia(ruido)
    if pn <= 0:
        raise ValueError("el ruido tiene potencia nula")
    return 10 * np.log10(_potencia(x) / pn)


def _potencia_banda(f, P, banda):
    f, P = np.asarray(f, dtype=float), np.asarray(P, dtype=float)
    return np.sum(P[(f >= banda[0]) & (f < banda[1])]) * (f[1] - f[0])


def snr_banda(f, P, Pruido, banda):
    """SNR en dB dentro de una banda (fa ≤ f < fb)."""
    pn = _potencia_banda(f, Pruido, banda)
    if pn <= 0:
        raise ValueError("el ruido tiene potencia nula en la banda")
    return 10 * np.log10(_potencia_banda(f, P, banda) / pn)


def rms_ruido_banda(densidad, fa, fb):
    """Valor eficaz del ruido de un sensor de densidad plana: densidad·√(fb − fa)."""
    if densidad < 0:
        raise ValueError("la densidad de ruido no puede ser negativa")
    if not fb > fa >= 0:
        raise ValueError("la banda debe cumplir 0 ≤ fa < fb")
    return densidad * np.sqrt(fb - fa)


# ---------- espectros cruzados y espectrograma (M4.6, M4.7) ----------
def _inicios(N, nseg, solape):
    if N < nseg:
        raise ValueError(f"la señal ({N} muestras) es más corta que un segmento ({nseg})")
    if not 0 <= solape < 1:
        raise ValueError("el solape debe estar en [0, 1)")
    if nseg < 2:
        raise ValueError("nseg debe ser al menos 2")
    return np.arange(0, N - nseg + 1, max(1, int(round(nseg * (1 - solape)))))


def _unilateral(nseg):
    nf = nseg // 2 + 1
    doble = np.full(nf, 2.0)
    doble[0] = 1.0
    if nseg % 2 == 0:
        doble[-1] = 1.0
    return nf, doble


def espectros_cruzados(x, y, fs, nseg=1024, solape=0.5, nombre_ventana="hann"):
    """(f, Gxx, Gyy, Gxy) unilaterales por el método de Welch."""
    x, y = np.asarray(x, dtype=float), np.asarray(y, dtype=float)
    if len(x) != len(y):
        raise ValueError("x e y deben tener la misma longitud")
    inicios = _inicios(len(x), nseg, solape)
    w = ventana(nombre_ventana, nseg)
    nf, doble = _unilateral(nseg)
    Gxx, Gyy, Gxy = np.zeros(nf), np.zeros(nf), np.zeros(nf, dtype=complex)
    for ini in inicios:
        sx, sy = x[ini : ini + nseg], y[ini : ini + nseg]
        X, Y = np.fft.fft((sx - sx.mean()) * w)[:nf], np.fft.fft((sy - sy.mean()) * w)[:nf]
        Gxx += np.abs(X) ** 2
        Gyy += np.abs(Y) ** 2
        Gxy += np.conj(X) * Y
    c = doble / (len(inicios) * fs * np.sum(w**2))
    return np.arange(nf) * (fs / nseg), Gxx * c, Gyy * c, Gxy * c


def coherencia(Gxx, Gyy, Gxy):
    """Coherencia γ² = |Gxy|²/(Gxx·Gyy)."""
    return np.abs(Gxy) ** 2 / (Gxx * Gyy)


def frf_h1(Gxx, Gxy):
    return Gxy / Gxx


def frf_h2(Gyy, Gxy):
    return Gyy / np.conj(Gxy)


def estimar_frf(x, y, fs, nseg=1024, solape=0.5, nombre_ventana="hann"):
    """Atajo: dict con f, H1, H2, coherencia, Gxx, Gyy y Gxy."""
    f, Gxx, Gyy, Gxy = espectros_cruzados(x, y, fs, nseg, solape, nombre_ventana)
    return dict(f=f, H1=frf_h1(Gxx, Gxy), H2=frf_h2(Gyy, Gxy), coherencia=coherencia(Gxx, Gyy, Gxy),
                Gxx=Gxx, Gyy=Gyy, Gxy=Gxy)


def espectrograma(x, fs, nseg=256, solape=0.75, nombre_ventana="hann"):
    """(t, f, P): PSD unilateral por segmento (P[k, j]); su promedio temporal es la PSD de Welch."""
    x = np.asarray(x, dtype=float)
    inicios = _inicios(len(x), nseg, solape)
    w = ventana(nombre_ventana, nseg)
    nf, doble = _unilateral(nseg)
    c = doble / (fs * np.sum(w**2))
    P = np.empty((nf, len(inicios)))
    for j, ini in enumerate(inicios):
        s = x[ini : ini + nseg]
        P[:, j] = c * np.abs(np.fft.fft((s - s.mean()) * w)[:nf]) ** 2
    return (inicios + nseg / 2) / fs, np.arange(nf) * (fs / nseg), P


# ---------- filtros (M4.2) ----------
def _sinc(x):
    return np.sinc(x)  # sin(πx)/(πx)


def respuesta_fir(b, f, fs):
    f = np.atleast_1d(np.asarray(f, dtype=float))
    zinv = np.exp(-2j * np.pi * f / fs)
    return np.array([np.sum(b * z ** np.arange(len(b))) for z in zinv])


def filtro_fir(ntaps, fc, fs, tipo="pasabajos", nombre_ventana="hamming"):
    """Coeficientes de un FIR por ventana: pasabajos, pasaaltos, pasabanda o rechazabanda."""
    if ntaps < 3:
        raise ValueError("ntaps debe ser al menos 3")
    if fs <= 0:
        raise ValueError("fs debe ser positiva")
    if tipo not in ("pasabajos", "pasaaltos", "pasabanda", "rechazabanda"):
        raise ValueError(f"tipo desconocido: {tipo}")
    if tipo in ("pasaaltos", "rechazabanda") and ntaps % 2 == 0:
        raise ValueError(f"para {tipo} ntaps debe ser impar")
    bordes = list(fc) if isinstance(fc, (tuple, list)) else [fc]
    banda = tipo in ("pasabanda", "rechazabanda")
    if len(bordes) != (2 if banda else 1):
        raise ValueError(f"{tipo} necesita " + ("(f1, f2)" if banda else "una sola frecuencia de corte"))
    if not all(0 < b < fs / 2 for b in bordes):
        raise ValueError("las frecuencias de corte deben estar entre 0 y fs/2")
    if banda and not bordes[0] < bordes[1]:
        raise ValueError("hace falta f1 < f2")
    n = np.arange(ntaps) - (ntaps - 1) / 2
    pasabajos = lambda f: (2 * f / fs) * _sinc(2 * f / fs * n)  # noqa: E731
    delta = (n == 0).astype(float)
    if tipo == "pasabajos":
        h = pasabajos(bordes[0])
    elif tipo == "pasaaltos":
        h = delta - pasabajos(bordes[0])
    elif tipo == "pasabanda":
        h = pasabajos(bordes[1]) - pasabajos(bordes[0])
    else:
        h = delta - (pasabajos(bordes[1]) - pasabajos(bordes[0]))
    h = h * ventana_simetrica(nombre_ventana, ntaps)
    f_ref = {"pasabajos": 0.0, "rechazabanda": 0.0, "pasaaltos": fs / 2}.get(tipo, sum(bordes) / 2)
    return h / abs(respuesta_fir(h, f_ref, fs)[0])


def _polos_butterworth(N):
    k = np.arange(1, N + 1)
    return np.exp(1j * np.pi * (2 * k + N - 1) / (2 * N))


def _prototipo_a_analogico(N, tipo, w):
    pk = _polos_butterworth(N)
    if tipo == "pasabajos":
        return np.array([], dtype=complex), w[0] * pk, w[0] ** N
    if tipo == "pasaaltos":
        return np.zeros(N, dtype=complex), w[0] / pk, 1.0
    B, w02 = w[1] - w[0], w[0] * w[1]
    p = []
    if tipo == "pasabanda":
        for q in pk:
            d = np.sqrt(complex((B * q) ** 2 - 4 * w02))
            p += [(B * q + d) / 2, (B * q - d) / 2]
        return np.zeros(N, dtype=complex), np.array(p), B**N
    for q in pk:
        d = np.sqrt(complex(B**2 - 4 * q**2 * w02))
        p += [(B + d) / (2 * q), (B - d) / (2 * q)]
    z0 = 1j * np.sqrt(w02)
    return np.concatenate([np.full(N, z0), np.full(N, -z0)]), np.array(p), 1.0


def _agrupar_raices(r, ordenar_por_modulo=False):
    tol = lambda q: 1e-9 * max(1.0, abs(q))  # noqa: E731
    complejas = [q for q in r if q.imag > tol(q)]
    reales = sorted(q.real for q in r if abs(q.imag) <= tol(q))
    if ordenar_por_modulo:
        complejas = sorted(complejas, key=abs)  # estable, como `sort(by=abs)` en Julia
    pol = [np.array([1.0, -2 * q.real, abs(q) ** 2]) for q in complejas]
    i, j = 0, len(reales) - 1
    while i < j:
        pol.append(np.array([1.0, -(reales[i] + reales[j]), reales[i] * reales[j]]))
        i += 1
        j -= 1
    if i == j:
        pol.append(np.array([1.0, -reales[i], 0.0]))
    return pol


def filtro_butterworth(orden, fc, fs, tipo="pasabajos"):
    """Matriz ``sos`` (filas [b0 b1 b2 1 a1 a2]) de un Butterworth con transformación bilineal y *prewarping*."""
    if orden < 1:
        raise ValueError("el orden debe ser al menos 1")
    if fs <= 0:
        raise ValueError("fs debe ser positiva")
    if tipo not in ("pasabajos", "pasaaltos", "pasabanda", "rechazabanda"):
        raise ValueError(f"tipo desconocido: {tipo}")
    bordes = list(fc) if isinstance(fc, (tuple, list)) else [fc]
    banda = tipo in ("pasabanda", "rechazabanda")
    if len(bordes) != (2 if banda else 1):
        raise ValueError(f"{tipo} necesita " + ("(f1, f2)" if banda else "una sola frecuencia de corte"))
    if not all(0 < b < fs / 2 for b in bordes):
        raise ValueError("las frecuencias de corte deben estar entre 0 y fs/2")
    if banda and not bordes[0] < bordes[1]:
        raise ValueError("hace falta f1 < f2")
    fs2 = 2.0 * fs
    w = fs2 * np.tan(np.pi * np.array(bordes) / fs)
    z, p, k = _prototipo_a_analogico(orden, tipo, w)
    zd = np.concatenate([(fs2 + z) / (fs2 - z), np.full(len(p) - len(z), -1.0 + 0j)])
    pd = (fs2 + p) / (fs2 - p)
    kd = k * (np.prod(fs2 - z) / np.prod(fs2 - p)).real
    num, den = _agrupar_raices(zd), _agrupar_raices(pd, ordenar_por_modulo=True)
    nsec = max(len(num), len(den))
    sos = np.zeros((nsec, 6))
    for s in range(nsec):
        sos[s, 0:3] = num[s] if s < len(num) else [1.0, 0.0, 0.0]
        sos[s, 3:6] = den[s] if s < len(den) else [1.0, 0.0, 0.0]
    sos[0, 0:3] *= kd
    return sos


def respuesta_iir(sos, f, fs):
    """Respuesta en frecuencia compleja de una cascada de secciones."""
    f = np.atleast_1d(np.asarray(f, dtype=float))
    zinv = np.exp(-2j * np.pi * f / fs)
    H = np.ones_like(zinv)
    for b0, b1, b2, _, a1, a2 in sos:
        H = H * (b0 + b1 * zinv + b2 * zinv**2) / (1 + a1 * zinv + a2 * zinv**2)
    return H


def _tau_polinomio(c, w):
    zinv = np.exp(-1j * w)
    n = np.arange(len(c))
    return float(np.real(np.sum(n * c * zinv**n) / np.sum(c * zinv**n)))


def retardo_grupo_fir(b, f, fs):
    """Retardo de grupo (s) de un FIR en las frecuencias ``f``."""
    return np.array([_tau_polinomio(np.asarray(b), 2 * np.pi * q / fs) / fs for q in np.atleast_1d(f)])


def retardo_grupo_iir(sos, f, fs):
    """Retardo de grupo (s) de un IIR en las frecuencias ``f``."""
    return np.array([sum(_tau_polinomio(s[:3], 2 * np.pi * q / fs) - _tau_polinomio(s[3:], 2 * np.pi * q / fs)
                         for s in sos) / fs for q in np.atleast_1d(f)])


def _filtrar_sos(sos, x, estacionario=False):
    y = np.array(x, dtype=float)
    for b0, b1, b2, _, a1, a2 in sos:
        z1 = z2 = 0.0
        if estacionario:
            g = (b0 + b1 + b2) / (1 + a1 + a2)
            z1, z2 = (g - b0) * y[0], (b2 - a2 * g) * y[0]
        for n in range(len(y)):
            xn = y[n]
            yn = b0 * xn + z1
            z1 = b1 * xn - a1 * yn + z2
            z2 = b2 * xn - a2 * yn
            y[n] = yn
    return y


def filtrar_iir(sos, x):
    """Filtrado causal con una cascada de secciones (estado inicial nulo)."""
    return _filtrar_sos(sos, x)


def filtrar_fir(b, x, compensar=False):
    """Filtrado causal con un FIR; ``compensar=True`` adelanta la salida (ntaps-1)/2 muestras."""
    x = np.asarray(x, dtype=float)
    y = np.convolve(b, x)[: len(x)]
    if not compensar:
        return y
    if len(b) % 2 == 0:
        raise ValueError("compensar exige ntaps impar")
    d = (len(b) - 1) // 2
    return np.concatenate([y[d:], np.zeros(d)])


def filtrar_fase_cero(filtro, x):
    """Filtrado adelante-atrás (|H|²): ``filtro`` es una matriz ``sos`` (2D) o los coeficientes ``b`` de un FIR (1D)."""
    x = np.asarray(x, dtype=float)
    N = len(x)
    if N < 2:
        raise ValueError("hacen falta al menos 2 muestras")
    filtro = np.asarray(filtro, dtype=float)
    es_iir = filtro.ndim == 2
    orden = 2 * filtro.shape[0] + 1 if es_iir else len(filtro)
    npad = min(3 * orden, N - 1)
    ext = np.concatenate([2 * x[0] - x[npad:0:-1], x, 2 * x[-1] - x[-2 : -npad - 2 : -1]])
    pasada = (lambda v: _filtrar_sos(filtro, v, estacionario=True)) if es_iir else (lambda v: np.convolve(filtro, v)[: len(v)])
    y = pasada(pasada(ext)[::-1])[::-1]
    return y[npad : npad + N]


def diezmar(x, q):
    """Reduce q veces la frecuencia de muestreo con un FIR antialiasing de fase cero (Hamming, 20q+1 coeficientes)."""
    if q < 1:
        raise ValueError("q debe ser al menos 1")
    x = np.asarray(x, dtype=float)
    if q == 1:
        return x.copy()
    h = filtro_fir(20 * q + 1, 0.4 / q, 1.0, "pasabajos", "hamming")
    return filtrar_fir(h, x, compensar=True)[::q]


# ---------- oscilador de 1 GDL (M4.6) ----------
def aceleracion_1gdl(u, f0, zeta, fs):
    """Aceleración de un oscilador de 1 GDL, ``x'' + 2ζω x' + ω² x = u``, partiendo del reposo.

    Espejo de ``aceleracion_1gdl`` de ``Resonancia.jl/src/edos.jl``: discretización exacta con retenedor de
    orden cero (``u`` constante entre muestras). El elemento ``k`` es la aceleración en el instante ``k/fs``
    con ``u[k]`` ya aplicada. ``f0`` y ``fs`` en Hz; exige 0 ≤ zeta < 1.
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
