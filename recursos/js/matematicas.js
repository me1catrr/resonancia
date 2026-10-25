// =============================================================================
// matematicas.js: álgebra lineal, FFT y herramientas de señales para los
// laboratorios interactivos (Observable JS) de M02. Módulo ES sin dependencias.
//
// Convenciones:
//   - Una matriz es un array de filas (array de arrays de números); un vector, un array.
//   - Algoritmos pensados para matrices PEQUEÑAS (decenas de filas): Jacobi para
//     autovalores y SVD, eliminación gaussiana con pivoteo. No sustituyen a LAPACK.
//   - FFT radix-2 (longitud potencia de 2), X[k] = Σ x[n] e^{-2πi kn/N}.
//   - Los autovectores y los vectores singulares tienen signo arbitrario.
//   - Pruebas frente a Julia: matematicas.test.mjs, con los datos de
//     mse/m02-matematicas/referencia/matrices.json (generados por
//     scripts/m02/generar_referencia.jl).
// =============================================================================

const EPS = 2.220446049250313e-16;

// ---------- álgebra básica ----------
export const ceros = (m, n) => Array.from({ length: m }, () => new Array(n).fill(0));
export const identidad = (n) => Array.from({ length: n }, (_, i) => Array.from({ length: n }, (_, j) => (i === j ? 1 : 0)));
export const traspuesta = (A) => A[0].map((_, j) => A.map((fila) => fila[j]));
export const matVec = (A, x) => A.map((fila) => fila.reduce((s, a, j) => s + a * x[j], 0));
export const matMul = (A, B) => {
  const Bt = traspuesta(B);
  return A.map((fila) => Bt.map((col) => fila.reduce((s, a, k) => s + a * col[k], 0)));
};
export const dot = (a, b) => a.reduce((s, ai, i) => s + ai * b[i], 0);
export const norma2Vec = (x) => Math.sqrt(dot(x, x));

// ---------- normas matriciales ----------
/** Norma 1 (máxima suma de columnas en valor absoluto). */
export const norma1 = (A) => Math.max(...traspuesta(A).map((c) => c.reduce((s, a) => s + Math.abs(a), 0)));
/** Norma infinito (máxima suma de filas en valor absoluto). */
export const normaInf = (A) => Math.max(...A.map((f) => f.reduce((s, a) => s + Math.abs(a), 0)));
/** Norma de Frobenius. */
export const normaFro = (A) => Math.sqrt(A.reduce((s, f) => s + f.reduce((t, a) => t + a * a, 0), 0));

// ---------- autovalores de matrices simétricas (Jacobi cíclico) ----------
/** Autovalores (ascendentes) y autovectores (por columnas) de una matriz simétrica. */
export function autoSimetrica(A, maxBarridos = 60) {
  const n = A.length;
  const a = A.map((f) => f.slice());
  const v = identidad(n);
  const fuera = () => {
    let s = 0;
    for (let i = 0; i < n; i++) for (let j = i + 1; j < n; j++) s += a[i][j] * a[i][j];
    return Math.sqrt(s);
  };
  const escala = normaFro(A) || 1;
  for (let barrido = 0; barrido < maxBarridos && fuera() > 1e-15 * escala; barrido++) {
    for (let p = 0; p < n - 1; p++) {
      for (let q = p + 1; q < n; q++) {
        if (Math.abs(a[p][q]) < 1e-300) continue;
        const theta = (a[q][q] - a[p][p]) / (2 * a[p][q]);
        const t = Math.sign(theta || 1) / (Math.abs(theta) + Math.sqrt(1 + theta * theta));
        const c = 1 / Math.sqrt(1 + t * t);
        const s = t * c;
        for (let k = 0; k < n; k++) {
          const akp = a[k][p], akq = a[k][q];
          a[k][p] = c * akp - s * akq;
          a[k][q] = s * akp + c * akq;
        }
        for (let k = 0; k < n; k++) {
          const apk = a[p][k], aqk = a[q][k];
          a[p][k] = c * apk - s * aqk;
          a[q][k] = s * apk + c * aqk;
        }
        for (let k = 0; k < n; k++) {
          const vkp = v[k][p], vkq = v[k][q];
          v[k][p] = c * vkp - s * vkq;
          v[k][q] = s * vkp + c * vkq;
        }
      }
    }
  }
  const orden = [...Array(n).keys()].sort((i, j) => a[i][i] - a[j][j]);
  return {
    valores: orden.map((i) => a[i][i]),
    vectores: Array.from({ length: n }, (_, k) => orden.map((j) => v[k][j])),
  };
}

// ---------- SVD (Jacobi unilateral de Hestenes) ----------
/** A = U·diag(S)·Vᵀ con S descendente. A es m×n; devuelve U (m×r), S (r), V (n×r), r = min(m, n). */
export function svd(A, maxBarridos = 60) {
  const m = A.length, n = A[0].length;
  if (m < n) {
    const { U, S, V } = svd(traspuesta(A), maxBarridos);
    return { U: V, S, V: U };
  }
  const U = A.map((f) => f.slice());
  const V = identidad(n);
  for (let barrido = 0; barrido < maxBarridos; barrido++) {
    let rotado = false;
    for (let p = 0; p < n - 1; p++) {
      for (let q = p + 1; q < n; q++) {
        let alfa = 0, beta = 0, gamma = 0;
        for (let i = 0; i < m; i++) {
          alfa += U[i][p] * U[i][p];
          beta += U[i][q] * U[i][q];
          gamma += U[i][p] * U[i][q];
        }
        if (Math.abs(gamma) <= 1e-15 * Math.sqrt(alfa * beta) || gamma === 0) continue;
        rotado = true;
        const zeta = (beta - alfa) / (2 * gamma);
        const t = Math.sign(zeta || 1) / (Math.abs(zeta) + Math.sqrt(1 + zeta * zeta));
        const c = 1 / Math.sqrt(1 + t * t);
        const s = c * t;
        for (let i = 0; i < m; i++) {
          const up = U[i][p], uq = U[i][q];
          U[i][p] = c * up - s * uq;
          U[i][q] = s * up + c * uq;
        }
        for (let i = 0; i < n; i++) {
          const vp = V[i][p], vq = V[i][q];
          V[i][p] = c * vp - s * vq;
          V[i][q] = s * vp + c * vq;
        }
      }
    }
    if (!rotado) break;
  }
  const S = Array.from({ length: n }, (_, j) => Math.sqrt(U.reduce((s, f) => s + f[j] * f[j], 0)));
  const orden = [...Array(n).keys()].sort((i, j) => S[j] - S[i]);
  const Ss = orden.map((j) => S[j]);
  const Uo = U.map((f) => orden.map((j, k) => (Ss[k] > 0 ? f[j] / Ss[k] : 0)));
  const Vo = V.map((f) => orden.map((j) => f[j]));
  return { U: Uo, S: Ss, V: Vo };
}

/** Norma espectral (mayor valor singular). */
export const norma2 = (A) => svd(A).S[0];
/** Número de condición en norma 2: σ_max/σ_min (Infinity si A es singular). */
export function cond2(A) {
  const S = svd(A).S;
  const min = S[S.length - 1];
  return min > 0 ? S[0] / min : Infinity;
}
/** Rango numérico: valores singulares mayores que `tol` (por defecto máx(m,n)·ε·σ_max). */
export function rango(A, tol) {
  const S = svd(A).S;
  const t = tol ?? Math.max(A.length, A[0].length) * EPS * S[0];
  return S.filter((s) => s > t).length;
}
/** Pseudoinversa de Moore–Penrose V Σ⁺ Uᵀ; los valores singulares ≤ `tol` se anulan (SVD truncada). */
export function pseudoinversa(A, tol) {
  const { U, S, V } = svd(A);
  const t = tol ?? Math.max(A.length, A[0].length) * EPS * S[0];
  return V.map((fv) => U.map((fu) => S.reduce((s, sk, k) => s + (sk > t ? (fv[k] * fu[k]) / sk : 0), 0)));
}
/** Aproximación de rango `r` (Eckart–Young): Σ_{i≤r} σ_i u_i v_iᵀ. */
export function aproxRango(A, r) {
  const { U, S, V } = svd(A);
  return A.map((_, i) => A[0].map((__, j) => S.slice(0, r).reduce((s, sk, k) => s + sk * U[i][k] * V[j][k], 0)));
}

/** Exponencial de una matriz por escalado y cuadrado con serie de Taylor de orden 18 (matrices pequeñas). */
export function expm(A) {
  const n = A.length, nA = norma1(A);
  const s = nA > 0.5 ? Math.ceil(Math.log2(nA / 0.5)) : 0;
  const B = A.map((f) => f.map((v) => v / 2 ** s));
  let E = identidad(n), T = identidad(n);
  for (let k = 1; k <= 18; k++) {
    T = matMul(T, B).map((f) => f.map((v) => v / k));
    E = E.map((f, i) => f.map((v, j) => v + T[i][j]));
  }
  for (let i = 0; i < s; i++) E = matMul(E, E);
  return E;
}

// ---------- sistemas lineales y mínimos cuadrados ----------
/** Resuelve A x = b por eliminación gaussiana con pivoteo parcial (A cuadrada). */
export function resolver(A, b) {
  const n = A.length;
  const M = A.map((f, i) => [...f, b[i]]);
  for (let k = 0; k < n; k++) {
    let p = k;
    for (let i = k + 1; i < n; i++) if (Math.abs(M[i][k]) > Math.abs(M[p][k])) p = i;
    if (Math.abs(M[p][k]) < 1e-300) throw new Error("matriz singular");
    [M[k], M[p]] = [M[p], M[k]];
    for (let i = k + 1; i < n; i++) {
      const f = M[i][k] / M[k][k];
      for (let j = k; j <= n; j++) M[i][j] -= f * M[k][j];
    }
  }
  const x = new Array(n).fill(0);
  for (let i = n - 1; i >= 0; i--) {
    let s = M[i][n];
    for (let j = i + 1; j < n; j++) s -= M[i][j] * x[j];
    x[i] = s / M[i][i];
  }
  return x;
}
/** Solución de mínimos cuadrados min‖A x − b‖ mediante la SVD (A de rango completo por columnas). */
export function minimosCuadrados(A, b) {
  const { U, S, V } = svd(A);
  const tol = Math.max(A.length, A[0].length) * EPS * S[0];
  const x = new Array(A[0].length).fill(0);
  S.forEach((s, k) => {
    if (s <= tol) return;
    const coef = dot(U.map((f) => f[k]), b) / s;
    V.forEach((f, j) => (x[j] += coef * f[k]));
  });
  return x;
}

// ---------- matrices estructuradas ----------
/** Toeplitz T[i][j] = t_{i−j}: primera columna `c`, primera fila `r` (c[0] = r[0]). */
export function toeplitz(c, r = c) {
  if (c[0] !== r[0]) throw new Error("c[0] y r[0] deben coincidir");
  return c.map((_, i) => r.map((__, j) => (i >= j ? c[i - j] : r[j - i])));
}
/** Hankel H[i][j] = h_{i+j}: primera columna `c`, última fila `r` (c[último] = r[0]); sin `r`, ceros. */
export function hankel(c, r = null) {
  const m = c.length;
  const fila = r ?? [c[m - 1], ...new Array(m - 1).fill(0)];
  if (c[m - 1] !== fila[0]) throw new Error("c[último] y r[0] deben coincidir");
  return c.map((_, i) => fila.map((__, j) => (i + j < m ? c[i + j] : fila[i + j - (m - 1)])));
}
/** Matriz de trayectoria L×K (K = N−L+1) con H[i][j] = x[i+j]. */
export function hankelTrayectoria(x, L) {
  const K = x.length - L + 1;
  if (L < 1 || K < 1) throw new Error("ventana no válida");
  return Array.from({ length: L }, (_, i) => Array.from({ length: K }, (_, j) => x[i + j]));
}
/** Promedio de cada antidiagonal (hankelización): serie de L+K−1 valores. */
export function promedioAntidiagonal(H) {
  const L = H.length, K = H[0].length;
  const suma = new Array(L + K - 1).fill(0), n = new Array(L + K - 1).fill(0);
  for (let i = 0; i < L; i++) for (let j = 0; j < K; j++) { suma[i + j] += H[i][j]; n[i + j]++; }
  return suma.map((s, k) => s / n[k]);
}
/** SSA: reconstrucción de rango `r` con ventana `L` y valores singulares de la matriz de trayectoria. */
export function ssa(x, L, r) {
  const H = hankelTrayectoria(x, L);
  return { reconstruccion: promedioAntidiagonal(aproxRango(H, r)), valoresSingulares: svd(H).S };
}
/** Circulante: primera columna `c`, C[i][j] = c[(i−j) mod n]. */
export function circulante(c) {
  const n = c.length;
  return c.map((_, i) => c.map((__, j) => c[(((i - j) % n) + n) % n]));
}
/** Vandermonde V[i][j] = x_i^j (n columnas). */
export const vandermonde = (x, n = x.length) => x.map((xi) => Array.from({ length: n }, (_, j) => xi ** j));

// ---------- FFT ----------
/** FFT radix-2 de la señal (re, im); devuelve {re, im}. La longitud debe ser potencia de 2. */
export function fft(re, im = null) {
  const n = re.length;
  if (n === 0 || (n & (n - 1)) !== 0) throw new Error("la longitud debe ser potencia de 2");
  const xr = Float64Array.from(re), xi = Float64Array.from(im ?? new Array(n).fill(0));
  for (let i = 1, j = 0; i < n; i++) {
    let bit = n >> 1;
    for (; j & bit; bit >>= 1) j ^= bit;
    j ^= bit;
    if (i < j) { [xr[i], xr[j]] = [xr[j], xr[i]]; [xi[i], xi[j]] = [xi[j], xi[i]]; }
  }
  for (let len = 2; len <= n; len <<= 1) {
    const ang = (-2 * Math.PI) / len;
    for (let i = 0; i < n; i += len) {
      for (let k = 0; k < len / 2; k++) {
        const wr = Math.cos(ang * k), wi = Math.sin(ang * k);
        const a = i + k, b = i + k + len / 2;
        const tr = xr[b] * wr - xi[b] * wi, ti = xr[b] * wi + xi[b] * wr;
        xr[b] = xr[a] - tr; xi[b] = xi[a] - ti;
        xr[a] += tr; xi[a] += ti;
      }
    }
  }
  return { re: Array.from(xr), im: Array.from(xi) };
}
/** FFT inversa (con el factor 1/N). */
export function ifft(re, im) {
  const n = re.length;
  const { re: r, im: i } = fft(re, im.map((v) => -v));
  return { re: r.map((v) => v / n), im: i.map((v) => -v / n) };
}
/** Convolución circular directa (a ⊛ b)[k] = Σ_j a[j]·b[(k−j) mod n]. */
export function convCircular(a, b) {
  const n = a.length;
  return a.map((_, k) => a.reduce((s, aj, j) => s + aj * b[(((k - j) % n) + n) % n], 0));
}
/** Convolución circular mediante FFT (longitud potencia de 2). */
export function convCircularFFT(a, b) {
  const A = fft(a), B = fft(b);
  const re = A.re.map((ar, k) => ar * B.re[k] - A.im[k] * B.im[k]);
  const im = A.re.map((ar, k) => ar * B.im[k] + A.im[k] * B.re[k]);
  return ifft(re, im).re;
}

// ---------- señales y estadística ----------
/** Generador pseudoaleatorio determinista (mulberry32): devuelve una función U(0,1). */
export function rng(semilla = 1) {
  let s = semilla >>> 0;
  return () => {
    s = (s + 0x6d2b79f5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
/** Muestra normal estándar (Box–Muller) a partir de un generador U(0,1). */
export function normal(u) {
  return Math.sqrt(-2 * Math.log(1 - u())) * Math.cos(2 * Math.PI * u());
}
/** Autocorrelación muestral sesgada r_0…r_kmax (se divide por N; media restada). */
export function autocorrelacion(x, kmax) {
  const N = x.length, media = x.reduce((s, v) => s + v, 0) / N;
  const z = x.map((v) => v - media);
  return Array.from({ length: kmax + 1 }, (_, k) => {
    let s = 0;
    for (let t = 0; t < N - k; t++) s += z[t] * z[t + k];
    return s / N;
  });
}
/** Yule–Walker: coeficientes AR(p) y varianza de la innovación a partir de la autocorrelación r. */
export function yuleWalker(r, p) {
  const phi = resolver(toeplitz(r.slice(0, p)), r.slice(1, p + 1));
  return { phi, sigma2: r[0] - dot(phi, r.slice(1, p + 1)) };
}
/** Simula un AR(p): x_t = Σ φ_j x_{t−j} + e_t, e_t ~ N(0, σ²). Descarta un transitorio de 200 muestras. */
export function simulaAR(phi, sigma, N, semilla = 1) {
  const u = rng(semilla), p = phi.length, burn = 200;
  const x = new Array(N + burn).fill(0);
  for (let t = p; t < N + burn; t++) x[t] = phi.reduce((s, f, j) => s + f * x[t - 1 - j], 0) + sigma * normal(u);
  return x.slice(burn);
}

// ---------- estructuras ----------
/** Matrices de masa y rigidez de una cadena de n masas m unidas por muelles k, con el primero anclado y el último libre. */
export function cadenaMasasMuelles(n, m = 1, k = 1) {
  const K = ceros(n, n);
  for (let i = 0; i < n; i++) {
    K[i][i] = i < n - 1 ? 2 * k : k;
    if (i < n - 1) { K[i][i + 1] = -k; K[i + 1][i] = -k; }
  }
  return { M: identidad(n).map((f) => f.map((v) => v * m)), K };
}
/** Edificio de cortante: masas m[i] de cada planta y rigideces k[i] del entrepiso i (el 1.º une con el suelo). */
export function edificioCortante(m, k) {
  const n = m.length, K = ceros(n, n);
  for (let i = 0; i < n; i++) {
    K[i][i] = k[i] + (i < n - 1 ? k[i + 1] : 0);
    if (i < n - 1) { K[i][i + 1] = -k[i + 1]; K[i + 1][i] = -k[i + 1]; }
  }
  return { M: m.map((mi, i) => m.map((_, j) => (i === j ? mi : 0))), K };
}
/**
 * Modos de K φ = ω² M φ con M diagonal definida positiva. Devuelve f (Hz, ascendente) y
 * Phi (por columnas, normalizado a masa unidad, con suma positiva en cada modo).
 */
export function modosPropios(K, M) {
  const n = K.length, d = M.map((f, i) => Math.sqrt(f[i]));
  const Kt = K.map((f, i) => f.map((v, j) => v / (d[i] * d[j])));
  const { valores, vectores } = autoSimetrica(Kt);
  const Phi = vectores.map((f, i) => f.map((v) => v / d[i]));
  for (let j = 0; j < n; j++) {
    const suma = Phi.reduce((s, f) => s + f[j], 0);
    if (suma < 0) Phi.forEach((f) => (f[j] = -f[j]));
  }
  return { f: valores.map((l) => Math.sqrt(Math.max(l, 0)) / (2 * Math.PI)), Phi };
}
/** MAC (modal assurance criterion): |aᵀb|² / ((aᵀa)(bᵀb)). */
export const mac = (a, b) => dot(a, b) ** 2 / (dot(a, a) * dot(b, b));

// ---------- ventanas, Hilbert y correlación cruzada ----------
/** Ventana periódica de N puntos: rectangular, hann, hamming, blackman o flattop. */
export function ventana(nombre, N) {
  const c = (k, n) => Math.cos((2 * Math.PI * k * n) / N);
  const f = {
    rectangular: () => 1,
    hann: (n) => 0.5 - 0.5 * c(1, n),
    hamming: (n) => 0.54 - 0.46 * c(1, n),
    blackman: (n) => 0.42 - 0.5 * c(1, n) + 0.08 * c(2, n),
    flattop: (n) => 0.21557895 - 0.41663158 * c(1, n) + 0.277263158 * c(2, n) - 0.083578947 * c(3, n) + 0.006947368 * c(4, n),
  }[nombre];
  if (!f) throw new Error("ventana desconocida: " + nombre);
  return Array.from({ length: N }, (_, n) => f(n));
}
/** Ancho de banda equivalente de ruido N·Σw²/(Σw)² (en bins). */
export function anchoBandaRuido(w) {
  const s = w.reduce((a, v) => a + v, 0), s2 = w.reduce((a, v) => a + v * v, 0);
  return (w.length * s2) / (s * s);
}
/** Señal analítica por FFT: devuelve {re, im} (im es la transformada de Hilbert). Longitud potencia de 2. */
export function hilbert(x) {
  const N = x.length, X = fft(x);
  const h = (k) => (k === 0 || k === N / 2 ? 1 : k < N / 2 ? 2 : 0);
  return ifft(X.re.map((v, k) => v * h(k)), X.im.map((v, k) => v * h(k)));
}
/** Correlación cruzada muestral sesgada para los retardos −kmax…kmax. */
export function correlacionCruzada(x, y, kmax) {
  const N = x.length, mx = x.reduce((a, v) => a + v, 0) / N, my = y.reduce((a, v) => a + v, 0) / N;
  const zx = x.map((v) => v - mx), zy = y.map((v) => v - my);
  return Array.from({ length: 2 * kmax + 1 }, (_, i) => {
    const k = i - kmax;
    let s = 0;
    for (let t = Math.max(0, -k); t < Math.min(N, N - k); t++) s += zx[t] * zy[t + k];
    return s / N;
  });
}
