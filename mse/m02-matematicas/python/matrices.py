"""Matrices estructuradas de M02 en Python (NumPy y SciPy).

Espejo de las funciones de ``Resonancia.jl/src/estructuradas.jl``: mismos algoritmos y mismas
convenciones, para contrastar Julia y Python con los datos de ``../referencia/matrices.json``.
Este código no se ejecuta en la web (véase CLAUDE.md): aquí está su versión probada, con ``pytest``.
"""
import numpy as np
from scipy import linalg


def toeplitz(c, r=None):
    """T[i, j] = t_{i-j}; primera columna ``c``, primera fila ``r`` (c[0] == r[0])."""
    c = np.asarray(c)
    r = c if r is None else np.asarray(r)
    if c[0] != r[0]:
        raise ValueError("c[0] y r[0] deben coincidir")
    return np.array([[c[i - j] if i >= j else r[j - i] for j in range(len(r))] for i in range(len(c))])


def hankel(c, r=None):
    """H[i, j] = h_{i+j}; primera columna ``c``, última fila ``r`` (c[-1] == r[0]); sin ``r``, ceros."""
    c = np.asarray(c)
    m = len(c)
    r = np.concatenate(([c[-1]], np.zeros(m - 1, dtype=c.dtype))) if r is None else np.asarray(r)
    if c[-1] != r[0]:
        raise ValueError("c[-1] y r[0] deben coincidir")
    return np.array([[c[i + j] if i + j < m else r[i + j - (m - 1)] for j in range(len(r))] for i in range(m)])


def hankel_trayectoria(x, L):
    """Matriz de trayectoria L×K (K = N-L+1) con H[i, j] = x[i+j]."""
    x = np.asarray(x)
    K = len(x) - L + 1
    if not 1 <= L <= len(x):
        raise ValueError("la ventana L debe estar entre 1 y N")
    return np.array([[x[i + j] for j in range(K)] for i in range(L)])


def promedio_antidiagonal(H):
    """Promedio de cada antidiagonal de H (L×K): serie de L+K-1 valores."""
    L, K = H.shape
    suma = np.zeros(L + K - 1)
    cuenta = np.zeros(L + K - 1)
    for i in range(L):
        for j in range(K):
            suma[i + j] += H[i, j]
            cuenta[i + j] += 1
    return suma / cuenta


def ssa(x, L, r):
    """SSA: (reconstrucción de rango r, valores singulares) con ventana L."""
    U, S, Vt = np.linalg.svd(hankel_trayectoria(x, L), full_matrices=False)
    Hr = (U[:, :r] * S[:r]) @ Vt[:r]
    return promedio_antidiagonal(Hr), S


def circulante(c):
    """Circulante con primera columna ``c``: C[i, j] = c[(i-j) mod n]."""
    c = np.asarray(c)
    n = len(c)
    return np.array([[c[(i - j) % n] for j in range(n)] for i in range(n)])


def conv_circular(a, b):
    """(a ⊛ b)[k] = Σ_j a[j] b[(k-j) mod n]."""
    n = len(a)
    return np.array([sum(a[j] * b[(k - j) % n] for j in range(n)) for k in range(n)])


def conv_circular_fft(a, b):
    """Convolución circular por el teorema de convolución."""
    return np.real(np.fft.ifft(np.fft.fft(a) * np.fft.fft(b)))


def autocorrelacion(x, kmax):
    """Autocorrelación muestral sesgada r_0..r_kmax (media restada, se divide por N)."""
    x = np.asarray(x, dtype=float)
    N = len(x)
    z = x - x.mean()
    return np.array([np.dot(z[: N - k], z[k:]) / N for k in range(kmax + 1)])


def yule_walker(r, p):
    """Coeficientes AR(p) y varianza de la innovación a partir de la autocorrelación ``r``."""
    r = np.asarray(r)
    phi = np.linalg.solve(toeplitz(r[:p]), r[1 : p + 1])
    return phi, r[0] - phi @ r[1 : p + 1]


def cadena_masas_muelles(n, m=1.0, k=1.0):
    """(M, K) de n masas m unidas por muelles k; primero anclado, último libre."""
    K = np.zeros((n, n))
    for i in range(n):
        K[i, i] = 2 * k if i < n - 1 else k
        if i < n - 1:
            K[i, i + 1] = K[i + 1, i] = -k
    return m * np.eye(n), K


def edificio_cortante(m, k):
    """(M, K) de un edificio de cortante: masas m[i] y rigideces k[i] de cada entrepiso."""
    n = len(m)
    K = np.zeros((n, n))
    for i in range(n):
        K[i, i] = k[i] + (k[i + 1] if i < n - 1 else 0)
        if i < n - 1:
            K[i, i + 1] = K[i + 1, i] = -k[i + 1]
    return np.diag(np.asarray(m, dtype=float)), K


def modos_propios(K, M):
    """Frecuencias (Hz, ascendentes) y modos normalizados a masa unidad de K φ = ω² M φ.

    El signo de cada modo se elige para que su suma sea positiva (igual que en Julia).
    """
    w2, Phi = linalg.eigh(K, M)
    Phi = Phi * np.where(Phi.sum(axis=0) < 0, -1.0, 1.0)
    return np.sqrt(np.maximum(w2, 0)) / (2 * np.pi), Phi


def mac(a, b):
    """Modal assurance criterion |aᵀb|² / ((aᵀa)(bᵀb))."""
    a, b = np.asarray(a), np.asarray(b)
    return abs(np.vdot(a, b)) ** 2 / (np.vdot(a, a).real * np.vdot(b, b).real)


def levinson_durbin(r, p):
    """Yule–Walker por la recursión de Levinson–Durbin: (phi, sigma2, coeficientes de reflexión)."""
    phi = np.zeros(0)
    sigma2 = float(r[0])
    kappa = []
    for k in range(1, p + 1):
        acc = r[k] - sum(phi[j] * r[k - 1 - j] for j in range(k - 1))
        kk = acc / sigma2
        phi = np.concatenate((phi - kk * phi[::-1], [kk]))
        sigma2 *= 1 - kk**2
        kappa.append(kk)
    return phi, sigma2, np.array(kappa)


def matriz_observabilidad(A, C):
    """[C; CA; CA²; …; CA^{n-1}]."""
    A, C = np.asarray(A), np.asarray(C)
    return np.vstack([C @ np.linalg.matrix_power(A, k) for k in range(A.shape[0])])


def matriz_controlabilidad(A, B):
    """[B AB A²B … A^{n-1}B]."""
    A, B = np.asarray(A), np.asarray(B)
    return np.hstack([np.linalg.matrix_power(A, k) @ B for k in range(A.shape[0])])


def matriz_mac(Phi, Psi):
    """MAC[i, j] entre las columnas de dos conjuntos de modos."""
    return np.array([[mac(Phi[:, i], Psi[:, j]) for j in range(Psi.shape[1])] for i in range(Phi.shape[1])])


def era(h, n, dt):
    """Algoritmo de realización de autosistemas: (frecuencias en Hz, amortiguamientos) con parte imaginaria > 0."""
    h = np.asarray(h)
    r = (len(h) - 1) // 2
    if r < n:
        raise ValueError("faltan datos: hacen falta al menos 2n+1 muestras")
    H0 = np.array([[h[i + j] for j in range(r)] for i in range(r)])
    H1 = np.array([[h[i + j + 1] for j in range(r)] for i in range(r)])
    U, S, Vt = np.linalg.svd(H0)
    Sm = np.diag(np.sqrt(S[:n]))
    Ad = np.linalg.inv(Sm) @ U[:, :n].T @ H1 @ Vt[:n].T @ np.linalg.inv(Sm)
    s = np.log(np.linalg.eigvals(Ad).astype(complex)) / dt
    s = s[s.imag > 0]
    f, z = np.abs(s) / (2 * np.pi), -s.real / np.abs(s)
    orden = np.argsort(f)
    return f[orden], z[orden]


def pseudoinversa(A, tol=None):
    """Pseudoinversa de Moore–Penrose V Σ⁺ Uᵀ; los valores singulares ≤ ``tol`` se anulan."""
    U, S, Vt = np.linalg.svd(np.asarray(A, dtype=float), full_matrices=False)
    t = max(np.shape(A)) * np.finfo(float).eps * S[0] if tol is None else tol
    inv_s = np.where(S > t, 1.0 / np.where(S > t, S, 1.0), 0.0)
    return (Vt.T * inv_s) @ U.T


def discretizar_zoh(A, B, dt):
    """Discretización exacta con retenedor de orden cero: exponencial de [[A, B], [0, 0]]·dt."""
    A, B = np.asarray(A, dtype=float), np.asarray(B, dtype=float)
    n, m = A.shape[0], B.shape[1]
    E = linalg.expm(np.block([[A, B], [np.zeros((m, n + m))]]) * dt)
    return E[:n, :n], E[:n, n:]


def edificio_tres_plantas(escenario="A"):
    """Edificio de cortante de tres plantas de M02 (mismos datos que ``Resonancia.edificio_tres_plantas``)."""
    m = np.full(3, 2.0e5)
    k = np.array([5.0e7, 5.0e7, 4.0e7])
    if escenario == "B":
        k = 0.99 * k
    elif escenario == "C":
        k[1] *= 0.9
    elif escenario != "A":
        raise ValueError("escenario debe ser A, B o C")
    K = np.zeros((3, 3))
    for i in range(3):
        K[i, i] = k[i] + (k[i + 1] if i < 2 else 0.0)
        if i < 2:
            K[i, i + 1] = K[i + 1, i] = -k[i + 1]
    return np.diag(m), K
