"""
    toeplitz(c, r=c) -> Matrix

Matriz de Toeplitz `T[i,j] = t_{i-j}` con primera columna `c` y primera fila `r`
(`T[i,j] = c[i-j+1]` si `i ≥ j`, `r[j-i+1]` si `i < j`). Debe cumplirse `c[1] == r[1]`.
"""
function toeplitz(c::AbstractVector, r::AbstractVector=c)
    c[1] == r[1] || throw(ArgumentError("c[1] y r[1] deben coincidir (la diagonal principal es única)"))
    m, n = length(c), length(r)
    return [i >= j ? c[i-j+1] : r[j-i+1] for i in 1:m, j in 1:n]
end

"""
    hankel(c, r=nothing) -> Matrix

Matriz de Hankel `H[i,j] = h_{i+j}` con primera columna `c` y última fila `r`
(`H[i,j] = c[i+j-1]` si `i+j-1 ≤ length(c)`, `r[i+j-length(c)]` si no). Debe cumplirse
`c[end] == r[1]`. Con `r` omitido, la parte inferior derecha se rellena con ceros.
"""
function hankel(c::AbstractVector, r::Union{Nothing,AbstractVector}=nothing)
    m = length(c)
    r = r === nothing ? [c[end]; zeros(eltype(c), m - 1)] : r
    c[end] == r[1] || throw(ArgumentError("c[end] y r[1] deben coincidir (la antidiagonal está compartida)"))
    n = length(r)
    return [i + j - 1 <= m ? c[i+j-1] : r[i+j-m] for i in 1:m, j in 1:n]
end

"""
    hankel_trayectoria(x, L) -> Matrix

Matriz de trayectoria (embedding) de la serie `x` con ventana `L`: tiene `L` filas y
`K = N-L+1` columnas, con `H[i,j] = x[i+j-1]`. Cada columna es una ventana de `L` muestras
consecutivas; la matriz es de Hankel (antidiagonales constantes).
"""
function hankel_trayectoria(x::AbstractVector, L::Integer)
    N = length(x)
    1 <= L <= N || throw(ArgumentError("la ventana L debe estar entre 1 y N=$N"))
    K = N - L + 1
    return [x[i+j-1] for i in 1:L, j in 1:K]
end

"""
    promedio_antidiagonal(H) -> Vector

Serie de `L+K-1` valores obtenida promediando cada antidiagonal de la matriz `H` (L×K): es la
proyección de `H` sobre las matrices de Hankel («hankelización») que se usa en SSA.
"""
function promedio_antidiagonal(H::AbstractMatrix)
    L, K = size(H)
    N = L + K - 1
    suma = zeros(float(eltype(H)), N)
    cuenta = zeros(Int, N)
    for j in 1:K, i in 1:L
        suma[i+j-1] += H[i, j]
        cuenta[i+j-1] += 1
    end
    return suma ./ cuenta
end

"""
    ssa(x, L, r) -> (reconstruccion, valores_singulares)

Análisis de espectro singular (SSA): construye la matriz de trayectoria de `x` con ventana `L`,
conserva sus `r` mayores valores singulares y devuelve la serie reconstruida por promediado
antidiagonal junto a todos los valores singulares. Una sinusoide pura da rango 2; la suma de
`p` sinusoides de frecuencias distintas, rango `2p` (si `L` y `N-L+1` son suficientes).
"""
function ssa(x::AbstractVector, L::Integer, r::Integer)
    F = svd(hankel_trayectoria(x, L))
    1 <= r <= length(F.S) || throw(ArgumentError("el rango r debe estar entre 1 y $(length(F.S))"))
    Hr = F.U[:, 1:r] * Diagonal(F.S[1:r]) * F.Vt[1:r, :]
    return promedio_antidiagonal(Hr), F.S
end

"""
    circulante(c) -> Matrix

Matriz circulante cuya primera columna es `c`: cada columna es la anterior desplazada
cíclicamente una posición hacia abajo, `C[i,j] = c[mod(i-j, n)+1]`.
"""
function circulante(c::AbstractVector)
    n = length(c)
    return [c[mod(i - j, n)+1] for i in 1:n, j in 1:n]
end

"""
    ifft_radix2(X) -> Vector{ComplexF64}

Transformada de Fourier inversa (longitud potencia de 2), con el factor `1/N`.
"""
ifft_radix2(X::AbstractVector) = conj.(fft_radix2(conj.(X))) ./ length(X)

"""
    conv_circular(a, b) -> Vector

Convolución circular directa de dos vectores de igual longitud: `(a ⊛ b)[k] = Σ_j a[j] b[(k-j) mod n]`
(0-indexado). Coincide con `circulante(a) * b`.
"""
function conv_circular(a::AbstractVector, b::AbstractVector)
    n = length(a)
    n == length(b) || throw(ArgumentError("a y b deben tener la misma longitud"))
    return [sum(a[j+1] * b[mod(k - j, n)+1] for j in 0:n-1) for k in 0:n-1]
end

"""
    conv_circular_fft(a, b) -> Vector{Float64}

Convolución circular mediante el teorema de convolución, `ifft(fft(a) .* fft(b))`. Exige longitud
potencia de 2. Los valores propios de `circulante(a)` son `fft_radix2(a)`.
"""
conv_circular_fft(a::AbstractVector{<:Real}, b::AbstractVector{<:Real}) =
    real.(ifft_radix2(fft_radix2(a) .* fft_radix2(b)))

"""
    vandermonde(x, n=length(x)) -> Matrix

Matriz de Vandermonde `V[i,j] = x[i]^(j-1)`. Está muy mal condicionada si `n` crece.
"""
vandermonde(x::AbstractVector, n::Integer=length(x)) = [xi^(j - 1) for xi in x, j in 1:n]

"""
    autocorrelacion(x, kmax) -> Vector{Float64}

Autocorrelación muestral sesgada `r_k = (1/N) Σ_{t=1}^{N-k} (x_t-x̄)(x_{t+k}-x̄)` para los retardos
`k = 0, …, kmax` (devuelve `kmax+1` valores). Se divide por `N` y no por `N-k`: así la matriz de
Toeplitz que forman es semidefinida positiva.
"""
function autocorrelacion(x::AbstractVector{<:Real}, kmax::Integer)
    N = length(x)
    0 <= kmax < N || throw(ArgumentError("kmax debe estar entre 0 y N-1"))
    z = x .- sum(x) / N
    return [sum(z[t] * z[t+k] for t in 1:N-k) / N for k in 0:kmax]
end

"""
    yule_walker(r, p) -> (phi, sigma2)

Ecuaciones de Yule–Walker para un modelo AR(`p`): resuelve `toeplitz(r[1:p]) * phi = r[2:p+1]` y
devuelve los coeficientes `phi` y la varianza de la innovación `sigma2 = r[1] - phi'r[2:p+1]`.
`r` es la autocorrelación desde el retardo 0.
"""
function yule_walker(r::AbstractVector, p::Integer)
    length(r) >= p + 1 || throw(ArgumentError("hacen falta al menos p+1 retardos"))
    phi = toeplitz(r[1:p]) \ r[2:p+1]
    return phi, r[1] - dot(phi, r[2:p+1])
end

"""
    cadena_masas_muelles(n; m=1.0, k=1.0) -> (M, K)

Matrices dispersas de masa y rigidez de una cadena de `n` masas iguales `m` unidas por muelles `k`,
con el primer muelle anclado a una pared y el último extremo libre. `K` es tridiagonal
(`2k` en la diagonal salvo `k` en el último grado de libertad; `-k` fuera de ella).
"""
function cadena_masas_muelles(n::Integer; m::Real=1.0, k::Real=1.0)
    n >= 1 || throw(ArgumentError("n debe ser positivo"))
    diag = fill(2.0 * k, n)
    diag[end] = k
    K = spdiagonal_tridiag(diag, fill(-float(k), n - 1))
    M = sparse(float(m) * I, n, n)
    return M, K
end

# Matriz tridiagonal simétrica dispersa con diagonal `d` y codiagonal `e`.
function spdiagonal_tridiag(d::Vector{Float64}, e::Vector{Float64})
    n = length(d)
    I_ = vcat(1:n, 1:n-1, 2:n)
    J_ = vcat(1:n, 2:n, 1:n-1)
    V_ = vcat(d, e, e)
    return sparse(I_, J_, V_, n, n)
end

"""
    edificio_cortante(m, k) -> (M, K)

Matrices de masa (diagonal) y rigidez de un edificio de cortante de `n` plantas: `m[i]` es la masa de la
planta `i` y `k[i]` la rigidez lateral del entrepiso `i` (entre la planta `i-1` y la `i`; el entrepiso 1
une la planta 1 con el suelo). `K[i,i] = k[i] + k[i+1]`, `K[i,i+1] = -k[i+1]`. Devuelve matrices densas.
"""
function edificio_cortante(m::AbstractVector, k::AbstractVector)
    n = length(m)
    n == length(k) || throw(ArgumentError("m y k deben tener n elementos"))
    K = zeros(float(eltype(k)), n, n)
    for i in 1:n
        K[i, i] = k[i] + (i < n ? k[i+1] : 0)
        i < n && (K[i, i+1] = K[i+1, i] = -k[i+1])
    end
    return Matrix(Diagonal(float.(m))), K
end

"""
    modos_propios(K, M) -> (f, Phi)

Resuelve el problema generalizado `K φ = ω² M φ` (K simétrica, M simétrica definida positiva).
Devuelve las frecuencias naturales `f = ω/2π` (Hz) en orden creciente y los modos `Phi` (por columnas)
normalizados a masa unidad (`Phiᵀ M Phi = I`), con el signo elegido para que la suma de cada modo sea positiva.
"""
function modos_propios(K::AbstractMatrix, M::AbstractMatrix)
    E = eigen(Symmetric(Matrix(K)), Symmetric(Matrix(M)))
    Phi = copy(E.vectors)
    for j in axes(Phi, 2)
        sum(Phi[:, j]) < 0 && (Phi[:, j] .*= -1)
    end
    f = sqrt.(max.(E.values, 0.0)) ./ (2π)
    return f, Phi
end

"""
    mac(a, b) -> Float64

Criterio de seguridad modal (*modal assurance criterion*): `|aᴴb|² / ((aᴴa)(bᴴb))`. Vale 1 si los
vectores son proporcionales y 0 si son ortogonales; no depende de la escala de cada modo.
"""
mac(a::AbstractVector, b::AbstractVector) = abs2(dot(a, b)) / (real(dot(a, a)) * real(dot(b, b)))
