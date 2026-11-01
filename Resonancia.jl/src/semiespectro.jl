# Semiespectro (espectro de retardos positivos) por correlograma con ventana exponencial, M7.1 y M7.9.
# Redactado a partir de la descripción de Magalhães y Cunha (2011); la implementación y la corrección del
# amortiguamiento son propias.

"""
    semiespectro(x, fs, f; L=1000, tau=Inf) -> Vector{ComplexF64}

Semiespectro `S⁺(f)` de la señal `x` (muestreada a `fs` Hz) en las frecuencias `f` (Hz), por el correlograma de los
**retardos positivos**:

    S⁺(f) = Δt [ w₀ r₀/2 + Σ_{j=1}^{L} w_j r_j e^{-i2π f jΔt} ],   w_j = exp(-jΔt/τ),

donde `r_j` es la autocorrelación muestral sesgada de `x` ([`autocorrelacion`](@ref)). Con `tau = Inf` la ventana es
rectangular. En unidades²/Hz y con el convenio bilateral, `Re S⁺ = S/2` (`S`: densidad espectral de potencia bilateral).

La ventana exponencial multiplica la correlación por `e^{-t/τ}`: cada polo `λ` pasa a `λ − 1/τ`, es decir, el
amortiguamiento estimado excede al verdadero en `1/(τ ω_n)` aproximadamente. Se corrige con
[`corregir_amortiguamiento_exponencial`](@ref).
"""
function semiespectro(x::AbstractVector{<:Real}, fs::Real, f::AbstractVector{<:Real}; L::Integer=1000, tau::Real=Inf)
    dt = 1 / fs
    r = autocorrelacion(x, L)
    w = exp.(-(0:L) .* dt ./ tau)
    c = w .* r
    c[1] /= 2
    j = collect(0:L)
    return [dt * sum(c[k+1] * cis(-2π * fk * j[k+1] * dt) for k in 0:L) for fk in f]
end

"""
    corregir_amortiguamiento_exponencial(zeta, f, tau) -> zeta_corregido

Resta del amortiguamiento estimado `zeta` el efecto de la ventana exponencial de constante `tau` (s) para un modo de
frecuencia `f` (Hz): `ζ − 1/(τ ω_n)` con `ω_n = 2π f`. Es una aproximación de primer orden, válida para `ζ` pequeño
y `1/τ` pequeño frente a `ω_n`.
"""
corregir_amortiguamiento_exponencial(zeta::Real, f::Real, tau::Real) = zeta - 1 / (tau * 2π * f)
