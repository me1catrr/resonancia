# Identificación estocástica por subespacios dirigida por covarianzas (SSI-COV), M7.8.
# Redactado a partir de la descripción del método en Peeters y De Roeck (1999) tal y como la resume el tutorial
# de Magalhães y Cunha (2011); la implementación es propia (sin matrices de ponderación).

"""
    correlaciones_salidas(Y, jmax; refs=1:size(Y, 2)) -> Array{Float64,3}

Matrices de correlación de las salidas a los retardos `j = 1, …, jmax` (en muestras), con los canales `refs` como
referencias: `R[:, :, j] = (1/N) Σ_k y[k+j] y[k, refs]ᵀ` (`no × r`). Se resta la media de cada canal y se divide por `N`
(estimador sesgado, que mantiene semidefinida positiva la matriz de Toeplitz por bloques).
"""
function correlaciones_salidas(Y::AbstractMatrix{<:Real}, jmax::Integer; refs=1:size(Y, 2))
    N, no = size(Y)
    N > jmax || throw(ArgumentError("el registro ($N muestras) debe ser más largo que el retardo máximo ($jmax)"))
    X = Float64.(Y) .- sum(Y; dims=1) ./ N
    R = zeros(no, length(refs), jmax)
    Xr = X[:, collect(refs)]
    for j in 1:jmax
        R[:, :, j] = X[1+j:N, :]' * Xr[1:N-j, :] ./ N
    end
    return R
end

"""
    toeplitz_bloques(R, jb) -> Matrix{Float64}

Matriz de Toeplitz por bloques `T₁|jb` de `no·jb × r·jb` construida con las correlaciones `R[:, :, 1:2jb-1]`: el bloque
`(i, j)` es `R_{jb+i-j}`. Cada diagonal descendente de bloques es constante.
"""
function toeplitz_bloques(R::AbstractArray{<:Real,3}, jb::Integer)
    no, r, nl = size(R)
    nl >= 2jb - 1 || throw(ArgumentError("hacen falta correlaciones hasta el retardo $(2jb - 1)"))
    T = zeros(no * jb, r * jb)
    for i in 1:jb, j in 1:jb
        T[(i-1)*no+1:i*no, (j-1)*r+1:j*r] = R[:, :, jb+i-j]
    end
    return T
end

"""
    ssi_cov_preparar(Y, fs; jb=30, refs=1:size(Y, 2)) -> NamedTuple

Primera etapa de SSI-COV: correlaciones con retardos `1, …, 2jb−1`, matriz de Toeplitz por bloques y su **única**
descomposición en valores singulares `T = U S Vᵀ`. Los modelos de cualquier orden se obtienen después con
[`ssi_cov_orden`](@ref) reutilizando estos factores (la SVD es lo más caro y solo se hace una vez).
"""
function ssi_cov_preparar(Y::AbstractMatrix{<:Real}, fs::Real; jb::Integer=30, refs=1:size(Y, 2))
    return ssi_cov_desde_correlaciones(correlaciones_salidas(Y, 2jb - 1; refs=refs), jb, 1 / fs)
end

"""
    ssi_cov_desde_correlaciones(R, jb, dt) -> NamedTuple

Igual que [`ssi_cov_preparar`](@ref), pero partiendo de las correlaciones `R[:, :, j]` (`no × r`, retardos `1, …, 2jb−1`)
y del paso de tiempo `dt`. Con las correlaciones teóricas `C A^{j-1} G` de un modelo conocido, el rango de la matriz de
Toeplitz es exactamente el orden del modelo.
"""
function ssi_cov_desde_correlaciones(R::AbstractArray{<:Real,3}, jb::Integer, dt::Real)
    T = toeplitz_bloques(R, jb)
    F = svd(T)
    return (U=F.U, S=F.S, no=size(R, 1), jb=jb, dt=float(dt), T=T)
end

"""
    ssi_cov_orden(modelo, n) -> (f, zeta, formas)

Modelo de estado de orden `n` (par) a partir de la SVD de [`ssi_cov_preparar`](@ref): observabilidad `O = U₁ S₁^{1/2}`
(primeros `n` valores singulares), `C` = sus `no` primeras filas y `A` por mínimos cuadrados con la propiedad de
desplazamiento, `A = O_sup⁺ O_inf`. Los polos `μ` de `A` dan `λ = ln(μ)/Δt`; se conservan los de parte imaginaria positiva
y de ellos `f = |λ|/2π` y `ζ = −Re(λ)/|λ|`. Las formas observables son `C Ψ` (`Ψ` = vectores propios de `A`), una columna por
modo. Los `n/2` modos salen ordenados por frecuencia.
"""
function ssi_cov_orden(modelo, n::Integer)
    (; U, S, no, jb, dt) = modelo
    1 <= n <= length(S) || throw(ArgumentError("el orden debe estar entre 1 y $(length(S))"))
    O = U[:, 1:n] .* sqrt.(S[1:n])'
    C = O[1:no, :]
    A = pinv(O[1:no*(jb-1), :]) * O[no+1:end, :]
    E = eigen(A)
    λ = log.(complex.(E.values)) ./ dt
    k = findall(imag.(λ) .> 0)
    ω = abs.(λ[k])
    o = sortperm(ω)
    k = k[o]
    return ω[o] ./ 2π, -real.(λ[k]) ./ abs.(λ[k]), C * E.vectors[:, k]
end

"""
    modos_estables(prev, act; tol_f=0.01, tol_z=0.05, mac_min=0.95) -> Vector{Bool}

Para cada modo del orden actual `act = (f, zeta, formas)` dice si es **estable** respecto del orden anterior `prev`: existe
un modo con diferencia relativa de frecuencia ≤ `tol_f`, de amortiguamiento ≤ `tol_z` y MAC de las formas ≥ `mac_min`,
y su amortiguamiento es positivo.
"""
function modos_estables(prev, act; tol_f::Real=0.01, tol_z::Real=0.05, mac_min::Real=0.95)
    fa, za, Pa = prev
    fb, zb, Pb = act
    est = falses(length(fb))
    for i in eachindex(fb)
        zb[i] > 0 || continue
        est[i] = any(abs(fb[i] - fa[j]) <= tol_f * fb[i] && abs(zb[i] - za[j]) <= tol_z * zb[i] &&
                     mac_complejo(Pb[:, i], Pa[:, j]) >= mac_min for j in eachindex(fa))
    end
    return est
end
