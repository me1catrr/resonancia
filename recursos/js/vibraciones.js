// =============================================================================
// vibraciones.js: funciones de vibraciones usadas por las figuras interactivas
// (Observable JS) de M5, M6 y M7. Módulo ES sin dependencias.
//
// Convenciones (las mismas que en el texto de las unidades):
//   - SI: m [kg], k [N/m], c [N·s/m], h [N/m] (coeficiente histerético), t [s].
//   - ω en rad/s (f = ω/2π en Hz).
//   - Convención temporal compleja e^{+iωt}: la fase de la receptancia va de 0°
//     a −180° (la respuesta se retrasa respecto de la fuerza).
//   - Un número complejo es un objeto {re, im}.
//   - Las pruebas contra Julia están en vibraciones.test.mjs (node --test).
// =============================================================================

// ---------- números complejos mínimos ----------
export const C = (re, im = 0) => ({ re, im });
export const cadd = (a, b) => C(a.re + b.re, a.im + b.im);
export const csub = (a, b) => C(a.re - b.re, a.im - b.im);
export const cmul = (a, b) => C(a.re * b.re - a.im * b.im, a.re * b.im + a.im * b.re);
export const cscale = (a, s) => C(a.re * s, a.im * s);
export const cconj = (a) => C(a.re, -a.im);
export const cabs = (a) => Math.hypot(a.re, a.im);
export const carg = (a) => Math.atan2(a.im, a.re);
export function cdiv(a, b) {
  const d = b.re * b.re + b.im * b.im;
  return C((a.re * b.re + a.im * b.im) / d, (a.im * b.re - a.re * b.im) / d);
}
export function csqrt(a) {
  const r = cabs(a);
  const re = Math.sqrt((r + a.re) / 2);
  const im = Math.sign(a.im || 1) * Math.sqrt(Math.max((r - a.re) / 2, 0));
  return C(re, im);
}
export const cexp = (a) => cscale(C(Math.cos(a.im), Math.sin(a.im)), Math.exp(a.re));

// ---------- 1 GDL: parámetros y polos ----------
/** Parámetros modales de m·x'' + c·x' + k·x = f. */
export function sdofParametros(m, k, c) {
  const wn = Math.sqrt(k / m);
  const zeta = c / (2 * m * wn);
  const regimen = zeta < 1 - 1e-12 ? "subcrítico" : zeta > 1 + 1e-12 ? "supercrítico" : "crítico";
  const sigma = -zeta * wn;
  let polos;
  if (zeta < 1) {
    const wd = wn * Math.sqrt(1 - zeta * zeta);
    polos = [C(sigma, wd), C(sigma, -wd)];
    return { wn, zeta, wd, sigma, regimen, polos, cc: 2 * m * wn };
  }
  const r = wn * Math.sqrt(zeta * zeta - 1);
  polos = [C(sigma + r, 0), C(sigma - r, 0)];
  return { wn, zeta, wd: 0, sigma, regimen, polos, cc: 2 * m * wn };
}

/** Respuesta libre x(t) con x(0)=x0, x'(0)=v0 (los tres regímenes). */
export function sdofLibre(m, k, c, x0, v0, t) {
  const { wn, zeta } = sdofParametros(m, k, c);
  const e = Math.exp(-zeta * wn * t);
  if (zeta < 1 - 1e-12) {
    const wd = wn * Math.sqrt(1 - zeta * zeta);
    return e * (x0 * Math.cos(wd * t) + ((v0 + zeta * wn * x0) / wd) * Math.sin(wd * t));
  }
  if (zeta > 1 + 1e-12) {
    const ws = wn * Math.sqrt(zeta * zeta - 1);
    return e * (x0 * Math.cosh(ws * t) + ((v0 + zeta * wn * x0) / ws) * Math.sinh(ws * t));
  }
  return ((1 + wn * t) * x0 + v0 * t) * Math.exp(-wn * t);
}

/** Respuesta impulsional h(t) = L^{-1}[1/(m s² + c s + k)] para t ≥ 0. */
export function sdofImpulsional(m, k, c, t) {
  if (t < 0) return 0;
  const { wn, zeta } = sdofParametros(m, k, c);
  const e = Math.exp(-zeta * wn * t);
  if (zeta < 1 - 1e-12) {
    const wd = wn * Math.sqrt(1 - zeta * zeta);
    return (e * Math.sin(wd * t)) / (m * wd);
  }
  if (zeta > 1 + 1e-12) {
    const ws = wn * Math.sqrt(zeta * zeta - 1);
    return (e * Math.sinh(ws * t)) / (m * ws);
  }
  return (t * Math.exp(-wn * t)) / m;
}

// ---------- 1 GDL: FRF ----------
/** Receptancia viscosa H(iω) = 1/(k − mω² + iωc). */
export const receptancia = (m, k, c, w) => cdiv(C(1), C(k - m * w * w, w * c));
/** Receptancia con amortiguamiento histerético H(ω) = 1/(k − mω² + i h). */
export const receptanciaHisteretica = (m, k, h, w) => cdiv(C(1), C(k - m * w * w, h));
/** Movilidad Y = iω·H. */
export const movilidad = (m, k, c, w) => cmul(C(0, w), receptancia(m, k, c, w));
/** Inertancia A = −ω²·H. */
export const inertancia = (m, k, c, w) => cscale(receptancia(m, k, c, w), -w * w);
export const aDecibelios = (x, ref = 1) => 20 * Math.log10(x / ref);
export const faseGrados = (z) => (carg(z) * 180) / Math.PI;

/** Factor de amplificación dinámica Q(β, ζ) = 1/√((1−β²)² + (2ζβ)²). */
export const factorAmplificacion = (beta, zeta) =>
  1 / Math.sqrt((1 - beta * beta) ** 2 + (2 * zeta * beta) ** 2);

/** Fase θ de la respuesta respecto de la fuerza (en (−π, 0]) a la frecuencia relativa β. */
export const faseForzada = (beta, zeta) => -Math.atan2(2 * zeta * beta, 1 - beta * beta);

/**
 * Respuesta completa a f(t) = F cos(ωt) con condiciones iniciales x0, v0:
 * solución estacionaria Re{F·H(iω)·e^{iωt}} más transitorio que cumple las
 * condiciones iniciales de la solución TOTAL.
 */
export function sdofForzada(m, k, c, F, w, x0, v0, t) {
  const H = receptancia(m, k, c, w);
  const amp = F * cabs(H);
  const th = carg(H);
  const xp = (tt) => amp * Math.cos(w * tt + th);
  const vp = (tt) => -amp * w * Math.sin(w * tt + th);
  const xt = sdofLibre(m, k, c, x0 - xp(0), v0 - vp(0), t);
  return { total: xt + xp(t), estacionaria: xp(t), transitorio: xt };
}

/** Respuesta a f(t)=F·δ-impulso de intensidad I: x(t) = I·h(t). */
export const sdofRespuestaImpulso = (m, k, c, I, t) => I * sdofImpulsional(m, k, c, t);

// ---------- polinomios: raíces de Durand–Kerner ----------
/** Raíces de un polinomio con coeficientes reales [a_n, …, a_0] (grado n ≥ 1). */
export function raicesPolinomio(coef) {
  const n = coef.length - 1;
  const a = coef.map((x) => x / coef[0]);
  const horner = (z) => {
    let p = C(a[0]);
    for (let i = 1; i <= n; i++) p = cadd(cmul(p, z), C(a[i]));
    return p;
  };
  const radio = 1 + Math.max(...a.slice(1).map(Math.abs));
  let z = Array.from({ length: n }, (_, j) => {
    const ang = (2 * Math.PI * j) / n + 0.4;
    return C(radio * 0.6 * Math.cos(ang), radio * 0.6 * Math.sin(ang));
  });
  for (let it = 0; it < 500; it++) {
    let delta = 0;
    z = z.map((zi, i) => {
      let den = C(1);
      for (let j = 0; j < n; j++) if (j !== i) den = cmul(den, csub(zi, z[j]));
      const corr = cdiv(horner(zi), den);
      delta = Math.max(delta, cabs(corr));
      return csub(zi, corr);
    });
    if (delta < 1e-14) break;
  }
  return z;
}

// ---------- 2 GDL: cadena de dos masas ----------
/** Matrices M, C, K de la cadena pared–k1–m1–k2–m2–k3–pared (amortiguadores c1, c2, c3 en paralelo). */
export function cadena2(p) {
  const { m1, m2, k1, k2, k3, c1, c2, c3 } = p;
  return {
    M: [[m1, 0], [0, m2]],
    C: [[c1 + c2, -c2], [-c2, c2 + c3]],
    K: [[k1 + k2, -k2], [-k2, k2 + k3]],
  };
}

/** Modos no amortiguados normalizados a la masa (Φᵀ M Φ = I). Ordenados por frecuencia. */
export function modosNoAmortiguados({ M, K }) {
  // det(K − λM) = a λ² + b λ + c = 0 con λ = ω²
  const a = M[0][0] * M[1][1] - M[0][1] * M[1][0];
  const b = -(K[0][0] * M[1][1] + K[1][1] * M[0][0] - K[0][1] * M[1][0] - K[1][0] * M[0][1]);
  const c = K[0][0] * K[1][1] - K[0][1] * K[1][0];
  const disc = Math.sqrt(Math.max(b * b - 4 * a * c, 0));
  const lams = [(-b - disc) / (2 * a), (-b + disc) / (2 * a)].sort((x, y) => x - y);
  const modos = lams.map((lam) => {
    // (K − λM) ψ = 0  →  ψ ∝ [−(K01 − λM01), (K00 − λM00)]
    let v = [-(K[0][1] - lam * M[0][1]), K[0][0] - lam * M[0][0]];
    if (Math.hypot(v[0], v[1]) < 1e-14) v = [-(K[1][1] - lam * M[1][1]), K[1][0] - lam * M[1][0]];
    const mr = v[0] * (M[0][0] * v[0] + M[0][1] * v[1]) + v[1] * (M[1][0] * v[0] + M[1][1] * v[1]);
    let s = 1 / Math.sqrt(mr);
    // Convención de signo: primera componente no nula positiva
    if (v[0] * s < 0 || (Math.abs(v[0]) < 1e-14 && v[1] * s < 0)) s = -s;
    return { w: Math.sqrt(lam), phi: [v[0] * s, v[1] * s] };
  });
  return modos;
}

/** Polos y modos (complejos en general) de M s² + C s + K = 0 para 2 GDL. */
export function polosYModos({ M, C: Cm, K }) {
  // det(M s² + C s + K) como polinomio en s (coeficientes reales)
  const p = (i, j) => [M[i][j], Cm[i][j], K[i][j]]; // [s², s, 1]
  const mulPol = (x, y) => {
    const r = Array(x.length + y.length - 1).fill(0);
    x.forEach((xi, i) => y.forEach((yj, j) => (r[i + j] += xi * yj)));
    return r;
  };
  const d1 = mulPol(p(0, 0), p(1, 1));
  const d2 = mulPol(p(0, 1), p(1, 0));
  const coef = d1.map((v, i) => v - d2[i]); // [s^4 … s^0]
  const raices = raicesPolinomio(coef);
  const polos = raices.map((s) => {
    const B = (i, j) => cadd(cadd(C(M[i][j] * (s.re * s.re - s.im * s.im), M[i][j] * 2 * s.re * s.im), cscale(s, Cm[i][j])), C(K[i][j]));
    // B ψ = 0  →  ψ ∝ [−B01, B00]; si es casi nulo usa la fila 2
    let psi = [cscale(B(0, 1), -1), B(0, 0)];
    if (cabs(psi[0]) + cabs(psi[1]) < 1e-12) psi = [cscale(B(1, 1), -1), B(1, 0)];
    // a_r = ψᵀ (2 s M + C) ψ  (transpuesta sin conjugar)
    const D = (i, j) => C(2 * M[i][j] * s.re + Cm[i][j], 2 * M[i][j] * s.im);
    let a = C(0);
    for (let i = 0; i < 2; i++) for (let j = 0; j < 2; j++) a = cadd(a, cmul(cmul(psi[i], D(i, j)), psi[j]));
    const raiz = csqrt(a);
    const phi = psi.map((z) => cdiv(z, raiz));
    return { s, phi, omega: cabs(s), zeta: -s.re / cabs(s), wd: Math.abs(s.im), sobreamortiguado: Math.abs(s.im) < 1e-9 };
  });
  return polos.sort((x, y) => (Math.abs(x.omega - y.omega) > 1e-9 ? x.omega - y.omega : y.s.im - x.s.im));
}

/** Receptancia exacta α(ω) = (K − ω²M + iωC)^{-1} (matriz 2×2 compleja). */
export function receptanciaMatriz({ M, C: Cm, K }, w) {
  const b = (i, j) => C(K[i][j] - w * w * M[i][j], w * Cm[i][j]);
  const det = csub(cmul(b(0, 0), b(1, 1)), cmul(b(0, 1), b(1, 0)));
  return [
    [cdiv(b(1, 1), det), cdiv(cscale(b(0, 1), -1), det)],
    [cdiv(cscale(b(1, 0), -1), det), cdiv(b(0, 0), det)],
  ];
}

/** Receptancia por superposición modal compleja: Σ φ_r φ_rᵀ/(iω − s_r) (2N polos). */
export function receptanciaModal(sistema, w) {
  const modos = polosYModos(sistema);
  const R = [[C(0), C(0)], [C(0), C(0)]];
  for (const m of modos) {
    const den = csub(C(0, w), m.s);
    for (let j = 0; j < 2; j++)
      for (let k = 0; k < 2; k++) R[j][k] = cadd(R[j][k], cdiv(cmul(m.phi[j], m.phi[k]), den));
  }
  return R;
}

/** Receptancia modal con modos reales (amortiguamiento proporcional): Σ φφᵀ/(ω_r²−ω²+2iζ_r ω_r ω). */
export function receptanciaModalReal(sistema, w) {
  const { M, C: Cm } = sistema;
  const modos = modosNoAmortiguados(sistema);
  const R = [[C(0), C(0)], [C(0), C(0)]];
  for (const md of modos) {
    const cr = md.phi[0] * (Cm[0][0] * md.phi[0] + Cm[0][1] * md.phi[1]) + md.phi[1] * (Cm[1][0] * md.phi[0] + Cm[1][1] * md.phi[1]);
    const zr = cr / (2 * md.w);
    const den = C(md.w * md.w - w * w, 2 * zr * md.w * w);
    for (let j = 0; j < 2; j++)
      for (let k = 0; k < 2; k++) R[j][k] = cadd(R[j][k], cdiv(C(md.phi[j] * md.phi[k]), den));
  }
  return R;
}

/** ¿El amortiguamiento es proporcional (modos reales)? Compara Φᵀ C Φ con su diagonal. */
export function esProporcional(sistema, tol = 1e-9) {
  const { C: Cm } = sistema;
  const [a, b] = modosNoAmortiguados(sistema);
  const f = (u, v) => u[0] * (Cm[0][0] * v[0] + Cm[0][1] * v[1]) + u[1] * (Cm[1][0] * v[0] + Cm[1][1] * v[1]);
  const d = Math.max(Math.abs(f(a.phi, a.phi)), Math.abs(f(b.phi, b.phi)), 1e-300);
  return Math.abs(f(a.phi, b.phi)) <= tol * d;
}

/** Muestrea una función y devuelve [{x, y}] para Plot. */
export function muestrea(f, x0, x1, n) {
  return Array.from({ length: n }, (_, i) => {
    const x = x0 + ((x1 - x0) * i) / (n - 1);
    return { x, y: f(x) };
  });
}

/** Muestrea en escala logarítmica entre w0 y w1 (n puntos). */
export function muestreaLog(f, w0, w1, n) {
  const l0 = Math.log10(w0), l1 = Math.log10(w1);
  return Array.from({ length: n }, (_, i) => {
    const x = 10 ** (l0 + ((l1 - l0) * i) / (n - 1));
    return { x, y: f(x) };
  });
}
