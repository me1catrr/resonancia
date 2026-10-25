"""
    cociente_rayleigh(K, M, x) -> Float64

Cociente de Rayleigh `xᵀKx / xᵀMx`. Es estacionario en cada modo propio, donde vale `ω²`, y está acotado
entre `ω₁²` y `ωₙ²` para cualquier `x ≠ 0`.
"""
cociente_rayleigh(K::AbstractMatrix, M::AbstractMatrix, x::AbstractVector) = dot(x, K * x) / dot(x, M * x)

"""
    rayleigh_amortiguamiento(M, K, f1, f2, z1, z2) -> C

Matriz de amortiguamiento proporcional `C = αM + βK` que da los amortiguamientos relativos `z1` y `z2`
en las frecuencias `f1` y `f2` (Hz). Para cualquier otra frecuencia, `ζ(ω) = α/(2ω) + βω/2`.
"""
function rayleigh_amortiguamiento(M::AbstractMatrix, K::AbstractMatrix, f1::Real, f2::Real, z1::Real, z2::Real)
    w1, w2 = 2π * f1, 2π * f2
    ab = [1/(2w1) w1/2; 1/(2w2) w2/2] \ [z1, z2]
    return ab[1] * M + ab[2] * K
end

"""
    expm(A) -> Matrix

Exponencial de una matriz cuadrada por escalado y cuadrado: serie de Taylor de orden 18 sobre
`A/2^s`, con `s` tal que `‖A/2^s‖₁ ≤ 0.5`, y `s` cuadrados sucesivos. Suficiente para las matrices pequeñas
del curso; para casos exigentes, úsese `exp` de `LinearAlgebra`.
"""
function expm(A::AbstractMatrix)
    n = size(A, 1)
    nA = opnorm(A, 1)
    s = nA > 0.5 ? ceil(Int, log2(nA / 0.5)) : 0
    B = Matrix{float(eltype(A))}(A) ./ 2^s
    E = Matrix{float(eltype(A))}(I, n, n)
    T = copy(E)
    for k in 1:18
        T = T * B / k
        E += T
    end
    for _ in 1:s
        E = E * E
    end
    return E
end

"""
    espacio_estados(M, C, K, B2) -> (A, B)

Forma de estado `x' = A x + B u` del sistema `M q'' + C q' + K q = B2 u`, con `x = [q; q']`:
`A = [0 I; -M⁻¹K -M⁻¹C]`, `B = [0; M⁻¹B2]`.
"""
function espacio_estados(M::AbstractMatrix, C::AbstractMatrix, K::AbstractMatrix, B2::AbstractVecOrMat)
    n = size(M, 1)
    B2m = B2 isa AbstractVector ? reshape(B2, :, 1) : B2
    Mi = inv(Matrix(M))
    A = [zeros(n, n) Matrix(I, n, n); -Mi * K -Mi * C]
    B = [zeros(n, size(B2m, 2)); Mi * B2m]
    return A, B
end

"""
    discretizar_zoh(A, B, dt) -> (Ad, Bd)

Discretización exacta con retenedor de orden cero (la entrada es constante en cada paso): `Ad = e^{A dt}`,
`Bd = ∫₀^dt e^{As} ds B`. Se calcula con la exponencial de la matriz ampliada `[A B; 0 0]·dt`, que sirve
también si `A` es singular.
"""
function discretizar_zoh(A::AbstractMatrix, B::AbstractMatrix, dt::Real)
    n, m = size(A, 1), size(B, 2)
    E = expm([Matrix(A) Matrix(B); zeros(m, n + m)] .* dt)
    return E[1:n, 1:n], E[1:n, n+1:end]
end

"""
    polos_modales(A) -> (f, zeta)

Frecuencias naturales (Hz) y amortiguamientos relativos de los polos con parte imaginaria positiva de
`A`, en orden creciente de frecuencia. Si `A` es discreta, conviértanse antes con `log(λ)/dt`.
"""
function polos_modales(A::AbstractMatrix)
    s = filter(p -> imag(p) > 1e-12, eigvals(Matrix(A)))
    f = abs.(s) ./ (2π)
    zeta = -real.(s) ./ abs.(s)
    o = sortperm(f)
    return f[o], zeta[o]
end

"""
    pseudoinversa_svd(A; tol) -> Matrix

Pseudoinversa de Moore–Penrose `A⁺ = V Σ⁺ Uᵀ`, donde `Σ⁺` invierte los valores singulares mayores que `tol`
(por defecto `max(size(A)) · eps · σ₁`) y anula el resto. Con `tol` mayor se regulariza (SVD truncada).
"""
function pseudoinversa_svd(A::AbstractMatrix; tol::Real=maximum(size(A)) * eps() * opnorm(A))
    F = svd(Matrix(A))
    inv_s = [s > tol ? 1 / s : 0.0 for s in F.S]
    return F.V * Diagonal(inv_s) * F.U'
end

"""
    rango_numerico(A; tol) -> Int

Número de valores singulares de `A` mayores que `tol` (por defecto `max(size(A)) · eps · σ₁`).
"""
function rango_numerico(A::AbstractMatrix; tol::Real=maximum(size(A)) * eps() * opnorm(A))
    return count(>(tol), svdvals(Matrix(A)))
end

"""
    edificio_tres_plantas(; escenario=:A) -> (M, C, K)

Edificio de cortante de tres plantas del caso transversal de M02. Masas de 2·10⁵ kg por planta y
rigideces de entrepiso de 5·10⁷ N/m (entrepisos 1 y 2) y 4·10⁷ N/m (entrepiso 3); el amortiguamiento es
proporcional con ζ = 1 % en las dos primeras frecuencias. Escenarios: `:A` (referencia), `:B` (variabilidad
ambiental: las tres rigideces un 1 % menores, p. ej. por temperatura) y `:C` (daño: el entrepiso 2 pierde un 10 %).
"""
function edificio_tres_plantas(; escenario::Symbol=:A)
    m = fill(2.0e5, 3)
    k = [5.0e7, 5.0e7, 4.0e7]
    escenario === :B && (k = 0.99 .* k)
    escenario === :C && (k[2] *= 0.9)
    escenario in (:A, :B, :C) || throw(ArgumentError("escenario debe ser :A, :B o :C"))
    # la amortiguación se fija con los modos del estado de referencia
    M, K = edificio_cortante(m, k)
    M0, K0 = edificio_cortante(m, [5.0e7, 5.0e7, 4.0e7])
    f0, _ = modos_propios(K0, M0)
    C = rayleigh_amortiguamiento(M0, K0, f0[1], f0[2], 0.01, 0.01)
    return M, C, K
end

"""
    polos_ar(phi, dt) -> (f, zeta)

Frecuencias (Hz) y amortiguamientos relativos de los polos con parte imaginaria positiva de un modelo
AR(`p`), `x[k] = Σ phi[j] x[k-j] + e[k]`, muestreado cada `dt` s. Los polos discretos son las raíces de
`z^p - phi[1] z^{p-1} - … - phi[p]`, que se calculan como valores propios de su matriz compañera, y se pasan
a continuo con `s = log(z)/dt`. Con `dt` fijo, las frecuencias por encima de `1/(2dt)` no se distinguen de las de abajo.
"""
function polos_ar(phi::AbstractVector, dt::Real)
    p = length(phi)
    Cm = zeros(p, p)
    Cm[1, :] = phi
    for i in 2:p
        Cm[i, i-1] = 1
    end
    s = log.(complex.(eigvals(Cm))) ./ dt
    s = filter(q -> imag(q) > 1e-12, s)
    f = abs.(s) ./ (2π)
    zeta = -real.(s) ./ abs.(s)
    o = sortperm(f)
    return f[o], zeta[o]
end
