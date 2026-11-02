# Ajuste de una FRF escalar por fracción racional en el dominio z (M7.3, ampliación PolyMAX).
# Versión de una entrada y una salida (SISO) del método de mínimos cuadrados en frecuencia
# con base polinómica z^r, z = e^{jωΔt}: es el caso particular m = ℓ = 1 del método descrito en
# Peeters et al. (2004), con coeficientes reales. Está pensada para comprobar la teoría, no para
# sustituir a una implementación polirreferencia.

"""
    lscf_coeficientes(f, H, p; w=ones(length(f)), f0=first(f), fmax=last(f)) -> (alfa, beta, dt)

Ajusta `H(f) ≈ B(z)/A(z)` con `B(z) = Σ βᵣ zʳ` y `A(z) = Σ αᵣ zʳ` (r = 0,…,p, coeficientes reales),
donde `z = e^{jωΔt}`, `ω = 2π(f − f0)` y `Δt = 1/(2(fmax − f0))`: la banda `[f0, fmax]` se aplica sobre
media circunferencia unidad. `H` son las FRF medidas (complejas), `f` las frecuencias (Hz, crecientes) y
`w` un peso por frecuencia.

El error de ecuación linealizado `w·(B − H·A)` se minimiza resolviendo las **ecuaciones normales reducidas**:
con `X = Ω` (columnas `zʳ`) e `Y = −diag(H)·X`, `R = Re(XᴴX)`, `S = Re(XᴴY)`, `T = Re(YᴴY)`, se elimina `β = −R⁻¹S α`
y queda `M α = 0` con `M = T − SᵀR⁻¹S`. Para evitar la solución trivial se impone `α_p = 1` (coeficiente de
mayor grado). Devuelve `alfa` y `beta` con índice `r+1` para el coeficiente de `zʳ`, y `dt`.
"""
function lscf_coeficientes(f::AbstractVector{<:Real}, H::AbstractVector{<:Number}, p::Integer;
                           w::AbstractVector{<:Real}=ones(length(f)), f0::Real=first(f), fmax::Real=last(f))
    length(f) == length(H) == length(w) || throw(DimensionMismatch("f, H y w deben tener la misma longitud"))
    p >= 1 || throw(ArgumentError("el orden p debe ser ≥ 1"))
    length(f) > 2 * (p + 1) || throw(ArgumentError("hacen falta más de 2(p+1) frecuencias"))
    dt = 1 / (2 * (fmax - f0))
    ω = 2π .* (f .- f0)
    X = [w[k] * cis(ω[k] * dt * r) for k in eachindex(f), r in 0:p]
    Y = -(H .* ones(1, p + 1)) .* X
    R = real(X' * X); S = real(X' * Y); T = real(Y' * Y)
    M = T - S' * (R \ S)
    M = (M + M') / 2
    a = -(M[1:p, 1:p] \ M[1:p, p+1])
    alfa = [a; 1.0]
    beta = -(R \ (S * alfa))
    return alfa, beta, dt
end

"""
    lscf_polos(alfa, dt; f0=0.0) -> (f, zeta)

Frecuencias naturales `f` (Hz, crecientes) y razones de amortiguamiento `zeta` de los polos con parte
imaginaria positiva del polinomio denominador `A(z) = Σ αᵣ zʳ` (`alfa[r+1]`), con `z = e^{λΔt}`, es decir,
`λ = ln(z)/Δt` y `λ + j·2π·f0` si la banda se desplazó. Un polo con `|z| > 1` sale con amortiguamiento
**negativo**: no es físico.
"""
function lscf_polos(alfa::AbstractVector{<:Real}, dt::Real; f0::Real=0.0)
    z = roots_polinomio(alfa)
    λ = log.(z) ./ dt .+ 1im * 2π * f0
    λ = filter(l -> imag(l) > 0, λ)
    ωn = abs.(λ)
    ζ = -real.(λ) ./ ωn
    ord = sortperm(ωn)
    return ωn[ord] ./ 2π, ζ[ord]
end

# raíces de Σ αᵣ zʳ como valores propios de la matriz compañera (sin dependencias nuevas)
function roots_polinomio(alfa::AbstractVector{<:Real})
    p = length(alfa) - 1
    C = zeros(p, p)
    for i in 1:p-1
        C[i+1, i] = 1.0
    end
    for i in 1:p
        C[i, p] = -alfa[i] / alfa[p+1]
    end
    return eigvals(C)
end

"""
    polos_estables(fa, za, fb, zb; tol_f=0.01, tol_z=0.05) -> Vector{Bool}

Para cada polo `(fb[i], zb[i])` de un orden dice si es **estable** respecto de los polos `(fa, za)` del orden
anterior: existe uno con `|Δf|/f ≤ tol_f` y `|Δζ|/ζ ≤ tol_z`, y su amortiguamiento es positivo.
"""
function polos_estables(fa, za, fb, zb; tol_f::Real=0.01, tol_z::Real=0.05)
    est = falses(length(fb))
    for i in eachindex(fb)
        zb[i] > 0 || continue
        est[i] = any(abs(fb[i] - fa[j]) <= tol_f * fb[i] && abs(zb[i] - za[j]) <= tol_z * zb[i] for j in eachindex(fa))
    end
    return est
end
