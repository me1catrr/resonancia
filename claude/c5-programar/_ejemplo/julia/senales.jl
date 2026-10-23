# Utilidades de señales para la unidad C5 (ejemplo didáctico).
# Convención: los índices de `detectar_picos` empiezan en 1 (Julia).

"""
    media_movil(x, n)

Media de cada ventana de `n` muestras consecutivas (sin rellenar los bordes).
Devuelve un vector de longitud `length(x) - n + 1`. Lanza `ArgumentError` si
`n < 1` o `n > length(x)`.
"""
function media_movil(x::AbstractVector{<:Real}, n::Integer)
    (1 <= n <= length(x)) || throw(ArgumentError("n debe estar entre 1 y $(length(x)), no $n"))
    acumulada = [0.0; cumsum(float.(x))]
    return (acumulada[n+1:end] .- acumulada[1:end-n]) ./ n
end

"""
    detectar_picos(x, umbral)

Índices (desde 1) de los máximos locales estrictos que superan `umbral`. Las
muestras de los extremos nunca cuentan.
"""
function detectar_picos(x::AbstractVector{<:Real}, umbral::Real)
    return [i for i in 2:length(x)-1 if x[i] > x[i-1] && x[i] > x[i+1] && x[i] > umbral]
end
