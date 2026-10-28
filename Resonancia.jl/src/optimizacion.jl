# Optimización y ajuste de modelos (J3.7): FRF de 1 GDL, modelo de PSD de un pico modal,
# frecuencias de un edificio de cortante en función de sus rigideces (model updating)
# y puntos iniciales reproducibles para estrategias multi-start.
#
# No depende de Optim.jl ni de LsqFit.jl: solo define los modelos y las funciones de coste;
# la unidad J3.7 los entrega a esos paquetes.

"""
    frf_1gdl(f, f0, zeta, A=1.0) -> ComplexF64

Receptancia (FRF desplazamiento/fuerza) de un oscilador de 1 GDL a la frecuencia `f` (Hz):

    H(f) = A / (1 - (f/f0)² + 2i ζ f/f0)

`f0` es la frecuencia natural no amortiguada (Hz), `zeta` el amortiguamiento relativo y `A = 1/k` la
flexibilidad estática (m/N). Se puede difundir sobre un vector de frecuencias con `frf_1gdl.(f, f0, zeta, A)`.
"""
function frf_1gdl(f::Real, f0::Real, zeta::Real, A::Real=1.0)
    r = f / f0
    return A / complex(1 - r^2, 2 * zeta * r)
end

"""
    frf_1gdl_ri(f, p) -> Vector{Float64}

Modelo de FRF de 1 GDL con la forma que pide el ajuste por mínimos cuadrados: `f` es un vector de frecuencias
(Hz), `p = [f0, zeta, A]` y el resultado apila las partes real e imaginaria, `[real.(H); imag.(H)]`
(longitud `2 * length(f)`).
"""
function frf_1gdl_ri(f::AbstractVector{<:Real}, p::AbstractVector{<:Real})
    length(p) == 3 || throw(ArgumentError("p debe ser [f0, zeta, A]"))
    H = [frf_1gdl(fi, p[1], p[2], p[3]) for fi in f]
    return vcat(real.(H), imag.(H))
end

"""
    psd_modal_1gdl(f, p) -> Vector

Densidad espectral de potencia de la aceleración de un oscilador de 1 GDL excitado por ruido blanco, más un suelo
de ruido: `p = [f0, zeta, S0, ruido]`,

    S(f) = S0 f⁴ / ((f0² - f²)² + (2 ζ f0 f)²) + ruido .

Sirve para ajustar el entorno de un pico del espectro de Welch (`S0` y `ruido` en unidades²/Hz).
"""
function psd_modal_1gdl(f::AbstractVector{<:Real}, p::AbstractVector{<:Real})
    length(p) == 4 || throw(ArgumentError("p debe ser [f0, zeta, S0, ruido]"))
    f0, z, S0, r = p
    return [S0 * fi^4 / ((f0^2 - fi^2)^2 + (2 * z * f0 * fi)^2) + r for fi in f]
end

"""
    frecuencias_cortante(theta; m=fill(2.0e5, 3), k0=[5.0e7, 5.0e7, 4.0e7]) -> Vector{Float64}

Frecuencias naturales (Hz, crecientes) de un edificio de cortante cuyas rigideces de entrepiso son
`k = theta .* k0`. Los parámetros `theta` son factores adimensionales respecto de la rigidez nominal `k0` (N/m),
con lo que el problema inverso queda bien escalado (todos del orden de 1). Es el modelo directo del
*model updating* de J3.7: con los valores por defecto, `theta = [1, 1, 1]` da 1,105; 2,939 y 4,390 Hz.
"""
function frecuencias_cortante(theta::AbstractVector{<:Real}; m::AbstractVector{<:Real}=fill(2.0e5, 3),
        k0::AbstractVector{<:Real}=[5.0e7, 5.0e7, 4.0e7])
    length(theta) == length(k0) == length(m) || throw(ArgumentError("theta, m y k0 deben tener la misma longitud"))
    all(>(0), theta) || throw(DomainError(theta, "los factores de rigidez deben ser positivos"))
    M, K = edificio_cortante(m, theta .* k0)
    f, _ = modos_propios(K, M)
    return f
end

"""
    residuos_frecuencias(theta, f_med; kwargs...) -> Vector{Float64}

Errores relativos entre las frecuencias del modelo `frecuencias_cortante(theta; kwargs...)` y las medidas `f_med`:
`(f_modelo - f_med) ./ f_med`. `f_med` puede ser un vector (una medida de cada modo) o una matriz
`modos × medidas`, en cuyo caso el resultado apila las columnas.
"""
function residuos_frecuencias(theta::AbstractVector{<:Real}, f_med::AbstractVecOrMat{<:Real}; kwargs...)
    f = frecuencias_cortante(theta; kwargs...)
    size(f_med, 1) == length(f) || throw(ArgumentError("f_med debe tener una fila por modo"))
    return vec((f .- f_med) ./ f_med)
end

"""
    coste_frecuencias(theta, f_med; kwargs...) -> Float64

Función objetivo del model updating con frecuencias: suma de los cuadrados de `residuos_frecuencias`.
Es cero cuando el modelo reproduce exactamente las frecuencias medidas.
"""
coste_frecuencias(theta::AbstractVector{<:Real}, f_med::AbstractVecOrMat{<:Real}; kwargs...) =
    sum(abs2, residuos_frecuencias(theta, f_med; kwargs...))

"""
    puntos_iniciales(lo, hi, n) -> Vector{Vector{Float64}}

`n` puntos de arranque repartidos en la caja `lo ≤ x ≤ hi` con la secuencia de Halton (bases 2, 3, 5, …):
reproducibles sin generador aleatorio y mejor repartidos que un muestreo uniforme. Para estrategias multi-start.
"""
function puntos_iniciales(lo::AbstractVector{<:Real}, hi::AbstractVector{<:Real}, n::Integer)
    d = length(lo)
    d == length(hi) || throw(ArgumentError("lo y hi deben tener la misma longitud"))
    all(lo .<= hi) || throw(ArgumentError("se exige lo ≤ hi"))
    d <= length(_PRIMOS_HALTON) || throw(ArgumentError("dimensión máxima: $(length(_PRIMOS_HALTON))"))
    return [lo .+ (hi .- lo) .* [_halton(i, _PRIMOS_HALTON[j]) for j in 1:d] for i in 1:n]
end

const _PRIMOS_HALTON = (2, 3, 5, 7, 11, 13, 17, 19)

# Elemento `i` (≥ 1) de la secuencia de van der Corput en base `b`.
function _halton(i::Integer, b::Integer)
    x, f = 0.0, 1.0 / b
    while i > 0
        x += f * (i % b)
        i ÷= b
        f /= b
    end
    return x
end
