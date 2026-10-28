# Referencias analíticas para las ecuaciones diferenciales ordinarias (J3.6): respuesta libre exacta de un
# oscilador de 1 GDL, fuerzas multiseno y su respuesta estacionaria.
#
# No depende de OrdinaryDiffEq.jl: son las soluciones con las que se comprueban las integraciones numéricas.

"""
    respuesta_libre_1gdl(t, f0, zeta; x0=1.0, v0=0.0) -> Float64

Desplazamiento exacto de un oscilador de 1 GDL subamortiguado en vibración libre, con `x(0) = x0` y `x'(0) = v0`:

    x(t) = e^{-ζωt} (x0 cos ω_d t + (v0 + ζω x0)/ω_d sin ω_d t)

con `ω = 2π f0` y `ω_d = ω√(1-ζ²)`. `f0` en Hz, `t` en s. Exige `0 ≤ zeta < 1`. Se puede difundir sobre un
vector de tiempos con `respuesta_libre_1gdl.(t, f0, zeta)`.
"""
function respuesta_libre_1gdl(t::Real, f0::Real, zeta::Real; x0::Real=1.0, v0::Real=0.0)
    0 <= zeta < 1 || throw(ArgumentError("zeta debe estar en [0, 1)"))
    f0 > 0 || throw(ArgumentError("f0 debe ser positiva"))
    w = 2π * f0
    wd = w * sqrt(1 - zeta^2)
    return exp(-zeta * w * t) * (x0 * cos(wd * t) + (v0 + zeta * w * x0) / wd * sin(wd * t))
end

"""
    fuerza_multiseno(t, f, A, phi) -> Float64

Fuerza como suma de armónicos, `Σ Aᵢ cos(2π fᵢ t + φᵢ)`, con las frecuencias `f` (Hz), las amplitudes `A` y las
fases `phi` (rad). Con frecuencias en una rejilla `fᵢ = i Δf` y amplitudes iguales aproxima una excitación de banda
ancha y densidad espectral plana (p. ej. el viento turbulento), y es **periódica** de periodo `1/Δf`.
"""
function fuerza_multiseno(t::Real, f::AbstractVector{<:Real}, A::AbstractVector{<:Real}, phi::AbstractVector{<:Real})
    (length(f) == length(A) == length(phi)) || throw(DimensionMismatch("f, A y phi deben tener la misma longitud"))
    s = 0.0
    @inbounds for i in eachindex(f)
        s += A[i] * cos(2π * f[i] * t + phi[i])
    end
    return s
end

"""
    rms_respuesta_multiseno(f, A, f0, zeta, k) -> Float64

Valor eficaz del desplazamiento estacionario de un oscilador de 1 GDL (frecuencia natural `f0` en Hz, amortiguamiento
`zeta`, rigidez `k` en N/m) excitado por `fuerza_multiseno(t, f, A, phi)`. Cada armónico responde con `Aᵢ |H(fᵢ)|`, con
`H` la receptancia `frf_1gdl(f, f0, zeta, 1/k)`, y las potencias se suman:

    σ_x² = Σ (Aᵢ²/2) |H(fᵢ)|²

No depende de las fases. Es exacto si el tiempo de observación es un múltiplo entero del periodo de la fuerza.
"""
function rms_respuesta_multiseno(f::AbstractVector{<:Real}, A::AbstractVector{<:Real}, f0::Real, zeta::Real, k::Real)
    length(f) == length(A) || throw(DimensionMismatch("f y A deben tener la misma longitud"))
    k > 0 || throw(ArgumentError("k debe ser positiva"))
    return sqrt(sum(A[i]^2 / 2 * abs2(frf_1gdl(f[i], f0, zeta, 1 / k)) for i in eachindex(f)))
end
