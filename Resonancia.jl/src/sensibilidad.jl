# Sensibilidades de las frecuencias propias y actualización de rigideces (J3.5).

"""
    derivada_K_cortante(n, j) -> Matrix{Float64}

Derivada `∂K/∂kⱼ` de la matriz de rigidez de un edificio de cortante de `n` plantas
([`edificio_cortante`](@ref)) respecto de la rigidez `kⱼ` del entrepiso `j`: el entrepiso une las plantas `j-1` y `j`,
así que solo cambian cuatro elementos (`+1` en `[j,j]` y en `[j-1,j-1]`, `-1` en `[j-1,j]` y en `[j,j-1]`).
"""
function derivada_K_cortante(n::Integer, j::Integer)
    1 <= j <= n || throw(ArgumentError("j debe estar entre 1 y n"))
    dK = zeros(n, n)
    dK[j, j] = 1
    if j > 1
        dK[j-1, j-1] += 1
        dK[j-1, j] = dK[j, j-1] = -1
    end
    return dK
end

"""
    sensibilidad_frecuencias(K, M, dK, dM=zeros(size(M))) -> Vector{Float64}

Derivada de cada frecuencia propia (Hz) de `K φ = ω² M φ` respecto de un parámetro `p`, dadas `dK = ∂K/∂p` y
`dM = ∂M/∂p`. Con los modos normalizados a masa unidad, `∂(ω²)/∂p = φᵀ(∂K/∂p − ω² ∂M/∂p)φ` y
`∂f/∂p = ∂(ω²)/∂p / (8π² f)`. Vale si los valores propios son simples.
"""
function sensibilidad_frecuencias(K::AbstractMatrix, M::AbstractMatrix, dK::AbstractMatrix, dM::AbstractMatrix=zeros(size(M)))
    f, Phi = modos_propios(K, M)
    return [begin
        phi = Phi[:, i]
        dlam = dot(phi, dK * phi) - (2π * f[i])^2 * dot(phi, dM * phi)
        dlam / (8π^2 * f[i])
    end for i in eachindex(f)]
end

"""
    jacobiana_frecuencias_cortante(m, k) -> Matrix{Float64}

Matriz `S[i, j] = ∂fᵢ/∂kⱼ` (Hz por N/m) de un edificio de cortante con masas `m` y rigideces de entrepiso `k`.
"""
function jacobiana_frecuencias_cortante(m::AbstractVector, k::AbstractVector)
    n = length(m)
    M, K = edificio_cortante(m, k)
    S = zeros(n, n)
    for j in 1:n
        S[:, j] = sensibilidad_frecuencias(K, M, derivada_K_cortante(n, j))
    end
    return S
end

"""
    actualizar_rigideces(m, k0, f_obj; maxiter=20, tol=1e-12, lambda=0.0) -> (k, historial)

Ajuste de modelo (*model updating*) de un edificio de cortante: busca las rigideces `k` que hacen coincidir las
primeras `length(f_obj)` frecuencias del modelo con las medidas `f_obj` (Hz), partiendo de `k0`, por Gauss–Newton sobre
los cambios relativos `θ = k/k0` (residuos relativos `(fᵢ(k) − f_objᵢ)/f_objᵢ`). `lambda > 0` añade una penalización de
Tikhonov `λ‖θ−1‖²` (regulariza cuando hay menos frecuencias que parámetros). Devuelve `k` y el historial de la
norma del residuo relativo por iteración.
"""
function actualizar_rigideces(m::AbstractVector, k0::AbstractVector, f_obj::AbstractVector; maxiter::Integer=20,
        tol::Real=1e-12, lambda::Real=0.0)
    n, nf = length(m), length(f_obj)
    nf <= n || throw(ArgumentError("no puede haber más frecuencias que plantas"))
    theta = ones(n)
    hist = Float64[]
    for _ in 1:maxiter
        k = k0 .* theta
        M, K = edificio_cortante(m, k)
        f, _ = modos_propios(K, M)
        r = (f[1:nf] .- f_obj) ./ f_obj
        push!(hist, norm(r))
        S = jacobiana_frecuencias_cortante(m, k)[1:nf, :]
        J = (S .* k0') ./ f_obj                      # ∂r/∂θ
        A = vcat(J, sqrt(lambda) * Matrix(I, n, n))
        b = vcat(-r, -sqrt(lambda) * (theta .- 1))
        paso = A \ b
        theta += paso
        norm(paso, Inf) < tol && break
    end
    return k0 .* theta, hist
end
