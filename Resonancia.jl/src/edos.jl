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

"""
    aceleracion_1gdl(u, f0, zeta, fs) -> Vector{Float64}

Aceleración `ẍ` de un oscilador de 1 GDL, `ẍ + 2ζω ẋ + ω² x = u(t)` (frecuencia natural `f0` en Hz, amortiguamiento
`zeta`), sometido a la fuerza por unidad de masa `u` muestreada a `fs` Hz y partiendo del reposo. La integración usa la
discretización exacta con retenedor de orden cero: es exacta si `u` es constante entre muestras (un escalón, por
ejemplo) y, en otro caso, el error es del orden de `(ω/fs)²`. El elemento `k` devuelto es la aceleración en el instante
`(k-1)/fs`, con `u[k]` ya aplicada.

Sirve para fabricar registros sintéticos de un modo con respuesta conocida (p. ej. el paso de un tren por un puente en
la actividad de M3). Exige `0 ≤ zeta < 1`, `f0 > 0` y `fs > 0`.
"""
function aceleracion_1gdl(u::AbstractVector{<:Real}, f0::Real, zeta::Real, fs::Real)
    0 <= zeta < 1 || throw(ArgumentError("zeta debe estar en [0, 1)"))
    f0 > 0 || throw(ArgumentError("f0 debe ser positiva"))
    fs > 0 || throw(ArgumentError("fs debe ser positiva"))
    w = 2π * f0
    E = exp([0.0 1.0 0.0; -w^2 -2zeta * w 1.0; 0.0 0.0 0.0] .* (1 / fs))   # [Φ Γ; 0 1] del estado [x, ẋ] con entrada u
    p11, p12, g1 = E[1, 1], E[1, 2], E[1, 3]
    p21, p22, g2 = E[2, 1], E[2, 2], E[2, 3]
    x = 0.0; v = 0.0
    a = Vector{Float64}(undef, length(u))
    @inbounds for k in eachindex(u)
        a[k] = -2zeta * w * v - w^2 * x + u[k]
        x, v = p11 * x + p12 * v + g1 * u[k], p21 * x + p22 * v + g2 * u[k]
    end
    return a
end
