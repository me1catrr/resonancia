"""
    descriptores_temporales(x) -> NamedTuple

Descriptores temporales de `x` (M3.2). Los momentos usan el divisor `N` (no `N-1`):

- `media` μ y `varianza` σ²;
- `rms` total `√(mean(x²))` y `rms_fluctuante` σ, que cumplen `rms² = μ² + σ²`;
- `pico` `max|x|`, `pico_fluctuante` `max|x - μ|` y `pico_pico` `max(x) - min(x)`;
- `cresta` `pico/rms` y `cresta_fluctuante` `pico_fluctuante/rms_fluctuante`;
- `asimetria` `mean((x-μ)³)/σ³` (0 para una distribución simétrica);
- `curtosis` ordinaria `mean((x-μ)⁴)/σ⁴` (3 para una normal) y `curtosis_exceso` (`curtosis - 3`).

Las unidades de `media`, `rms` y los picos son las de `x` (las de `varianza`, su cuadrado); el resto
es adimensional. Para vibraciones se suelen usar las versiones fluctuantes.
"""
function descriptores_temporales(x::AbstractVector{<:Real})
    n = length(x)
    n > 0 || throw(ArgumentError("la señal está vacía"))
    μ = sum(x) / n
    σ2 = sum(v -> (v - μ)^2, x) / n
    rms = sqrt(sum(abs2, x) / n)
    σ = sqrt(σ2)
    pico = maximum(abs, x)
    picof = maximum(v -> abs(v - μ), x)
    k = σ2 > 0 ? sum(v -> (v - μ)^4, x) / n / σ2^2 : NaN
    s3 = σ2 > 0 ? sum(v -> (v - μ)^3, x) / n / σ^3 : NaN
    return (media=μ, varianza=σ2, rms=rms, rms_fluctuante=σ, pico=pico, pico_fluctuante=picof,
        pico_pico=maximum(x) - minimum(x), cresta=pico / rms, cresta_fluctuante=picof / σ,
        asimetria=s3, curtosis=k, curtosis_exceso=k - 3)
end

"""
    cuantizar(x; bits, rango, offset=0.0) -> (y, saturada, q)

Convertidor analógico-digital ideal (M3.3) de `bits` bits y entrada bipolar `[-rango, rango]`, en las
unidades de `x`. A la señal se le suma antes `offset` (una componente continua del sensor o del
acondicionamiento). Paso de cuantificación `q = 2·rango/2^bits`; cada muestra se redondea al nivel más
próximo `q·c` con el código entero `c ∈ [-2^(bits-1), 2^(bits-1) - 1]`, y los valores que caen fuera se
recortan al nivel extremo (saturación). Devuelve la señal digitalizada `y` (con el offset incluido), un
vector lógico `saturada` que marca las muestras recortadas y `q`.
"""
function cuantizar(x::AbstractVector{<:Real}; bits::Integer, rango::Real, offset::Real=0.0)
    bits >= 1 || throw(ArgumentError("bits debe ser al menos 1"))
    rango > 0 || throw(ArgumentError("rango debe ser positivo"))
    q = 2rango / 2.0^bits
    cmin, cmax = -2.0^(bits - 1), 2.0^(bits - 1) - 1
    c = round.((x .+ offset) ./ q)
    saturada = (c .< cmin) .| (c .> cmax)
    return clamp.(c, cmin, cmax) .* q, saturada, q
end

"""
    frecuencia_aparente(f, fs) -> Float64

Frecuencia (Hz) con la que aparece en `[0, fs/2]` una sinusoide de frecuencia `f` muestreada a `fs`
sin filtro antialiasing (M3.4): `|f - fs·round(f/fs)|`.
"""
frecuencia_aparente(f::Real, fs::Real) = abs(f - fs * round(f / fs))
