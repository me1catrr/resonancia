# Propiedades de las ventanas espectrales (M4.1). Se calculan sobre la ventana concreta `w`
# (la que devuelve `ventana`), evaluando su transformada de Fourier de tiempo discreto (DTFT)
# en frecuencias fraccionarias: `ν` está en bins de la DFT de N puntos (1 bin = fs/N).
# Ya existen `ganancia_coherente` y `ancho_banda_ruido` (ENBW) en senales.jl.

# Módulo de la DTFT de `w` en la frecuencia `ν` (bins). Con ν = 0 es Σw.
_modulo_ventana(w, ν) = abs(sum(w[n+1] * cis(-2π * ν * n / length(w)) for n in 0:length(w)-1))

# Búsqueda de ν (bins) donde |W(ν)|/|W(0)| cruza `nivel` por primera vez, avanzando de `paso` en `paso`
# y afinando por bisección.
function _primer_cruce(w, nivel; paso=0.01, nmax=length(w) / 2)
    W0 = _modulo_ventana(w, 0.0)
    a = 0.0
    while a + paso <= nmax
        if _modulo_ventana(w, a + paso) / W0 <= nivel
            b = a + paso
            for _ in 1:50
                m = (a + b) / 2
                _modulo_ventana(w, m) / W0 > nivel ? (a = m) : (b = m)
            end
            return (a + b) / 2
        end
        a += paso
    end
    throw(ArgumentError("la respuesta de la ventana no baja de $nivel antes de $nmax bins"))
end

"""
    perdida_escalonamiento(w) -> Float64

Pérdida por escalonamiento (*scalloping loss*, M4.1) en dB: cuánto se subestima la amplitud de una
sinusoide cuya frecuencia cae **a medio bin** de dos bins de la DFT, el peor caso, `-20·log10(|W(½)|/|W(0)|)`.
Vale unos 3,92 dB (36 % de la amplitud) para la ventana rectangular, 1,42 dB para la de Hann y casi 0 para la flat-top.
"""
perdida_escalonamiento(w::AbstractVector{<:Real}) = -20log10(_modulo_ventana(w, 0.5) / _modulo_ventana(w, 0.0))

"""
    ancho_banda_3db(w) -> Float64

Ancho del lóbulo principal a −3 dB (potencia mitad) en **bins** de la DFT (M4.1): es la separación mínima aproximada
entre dos tonos para verlos como picos distintos. Unos 0,89 bins para la ventana rectangular y 1,44 para la de Hann.
Multiplicado por `fs/N` da hercios.
"""
ancho_banda_3db(w::AbstractVector{<:Real}) = 2 * _primer_cruce(w, 1 / √2)

"""
    nivel_lobulo_lateral(w) -> Float64

Nivel, en dB respecto del lóbulo principal, del mayor lóbulo lateral de la ventana (M4.1): cuánto «se escapa» a bins
lejanos (fuga). Se busca el primer mínimo de `|W(ν)|` y, a partir de él, el máximo hasta `min(N/2, 64)` bins. Valores
de referencia: −13,3 dB (rectangular), −31,5 dB (Hann), −58 dB (Blackman) y menos de −80 dB (flat-top).
"""
function nivel_lobulo_lateral(w::AbstractVector{<:Real}; paso=0.02)
    W0 = _modulo_ventana(w, 0.0)
    nmax = min(length(w) / 2, 64.0)
    νs = 0.0:paso:nmax
    m = [_modulo_ventana(w, ν) for ν in νs]
    # se empieza a buscar el primer mínimo fuera de la cima del lóbulo principal (la flat-top tiene
    # un rizado diminuto en ella): a partir del primer punto por debajo de −3 dB
    i = findfirst(<=(W0 / √2), m)
    i === nothing && throw(ArgumentError("la respuesta de la ventana no baja de −3 dB"))
    while i < length(m) && m[i+1] <= m[i]
        i += 1
    end
    return 20log10(maximum(@view m[i:end]) / W0)
end

"""
    correlacion_solape(w, desplazamiento) -> Float64

Correlación entre dos segmentos consecutivos de Welch (M4.1): `Σ w[n]·w[n+s] / Σ w²`, con `s` el desplazamiento
en muestras entre segmentos y `w` la ventana. Es 1 con `s = 0` y 0 si `s ≥ N` (sin solape). Para Hann con solape del
50 % vale 1/6; con la rectangular, 0,5.
"""
function correlacion_solape(w::AbstractVector{<:Real}, s::Integer)
    N = length(w)
    s >= 0 || throw(ArgumentError("el desplazamiento no puede ser negativo"))
    s >= N && return 0.0
    return sum(w[n] * w[n+s] for n in 1:N-s) / sum(abs2, w)
end

"""
    varianza_welch(w, solape, longitud) -> (K, var_relativa)

Varianza relativa de la PSD de Welch (M4.1) respecto de la de un solo periodograma (que tiene varianza relativa 1, es
decir, desviación igual a la propia PSD), para un registro de `longitud` muestras, ventana `w` y solape relativo
`solape` en `[0, 1)`. `K = ⌊(longitud − N)/D⌋ + 1` es el número de segmentos, con `D = round(N·(1 − solape))`. Con
ruido gaussiano y PSD localmente plana: `var = (1/K)·[1 + 2·Σ_{j=1}^{K−1} (1 − j/K)·ρ(jD)²]`, donde `ρ` es
`correlacion_solape`. Sin solape, `var = 1/K`. Subir el solape aumenta `K` pero los segmentos se correlacionan, de modo
que la ganancia se agota hacia el 50–75 % con Hann.
"""
function varianza_welch(w::AbstractVector{<:Real}, solape::Real, longitud::Integer)
    N = length(w)
    0 <= solape < 1 || throw(ArgumentError("el solape debe estar en [0, 1)"))
    longitud >= N || throw(ArgumentError("el registro es más corto que un segmento"))
    D = max(1, round(Int, N * (1 - solape)))
    K = (longitud - N) ÷ D + 1
    s = sum((1 - j / K) * correlacion_solape(w, j * D)^2 for j in 1:K-1; init=0.0)
    return K, (1 + 2s) / K
end

# ---------------------------------------------------------------------------
# Ventanas del ensayo de impacto (M4.1, «Ventanas en el ensayo con martillo»)
# ---------------------------------------------------------------------------

"""
    ventana_exponencial(N, fs, tau) -> Vector{Float64}

Ventana exponencial `w[n] = exp(-t_n/τ)` de `N` puntos, con `t_n = n/fs` (`n = 0, …, N-1`), `fs` en Hz y `tau`
en segundos (M4.1). Vale 1 en el primer punto y `exp(-T/τ)` al final del registro (`T = N/fs`). Se aplica **solo a
respuestas de impacto** que no llegan a decaer dentro del registro: multiplica cada modo por `exp(-σ₀ t)` con
`σ₀ = 1/τ`, y por eso añade a su amortiguamiento un valor conocido que luego se puede restar (véase
[`amortiguamiento_ventana_exponencial`](@ref) y [`corregir_amortiguamiento_exponencial`](@ref)).
"""
function ventana_exponencial(N::Integer, fs::Real, tau::Real)
    N >= 1 || throw(ArgumentError("N debe ser positivo"))
    fs > 0 && tau > 0 || throw(ArgumentError("fs y tau deben ser positivos"))
    return exp.(-(0:N-1) ./ (fs * tau))
end

"""
    amortiguamiento_ventana_exponencial(w_final, T) -> Float64

Amortiguamiento añadido `σ₀ = -ln(w(T))/T` (rad/s) por una ventana exponencial que vale `w_final` (entre 0 y 1,
exclusivos) al final de un registro de `T` segundos (M4.1). Es `1/τ`: con `w_final = 0,10` y `T = 0,64 s` sale
`σ₀ ≈ 3,6 rad/s`, es decir, `σ₀/2π ≈ 0,57 Hz`. A cada modo de frecuencia natural `ωₙ` le suma una razón de
amortiguamiento `σ₀/ωₙ`.
"""
function amortiguamiento_ventana_exponencial(w_final::Real, T::Real)
    0 < w_final < 1 || throw(ArgumentError("w_final debe estar entre 0 y 1 (exclusivos)"))
    T > 0 || throw(ArgumentError("T debe ser positivo"))
    return -log(w_final) / T
end

"""
    ventana_fuerza(N, inicio, ancho) -> Vector{Float64}

Ventana de fuerza de `N` puntos (M4.1): vale 1 en `ancho` muestras consecutivas desde la muestra `inicio`
(índice de 1 a `N`) y 0 en el resto. Se aplica a la señal de fuerza de un ensayo con martillo para dejar solo el golpe
y anular el ruido que hay antes y después. No es la ventana exponencial: esta se aplica a la respuesta.
"""
function ventana_fuerza(N::Integer, inicio::Integer, ancho::Integer)
    1 <= inicio <= N || throw(ArgumentError("inicio debe estar entre 1 y N"))
    ancho >= 1 || throw(ArgumentError("ancho debe ser positivo"))
    inicio + ancho - 1 <= N || throw(ArgumentError("la ventana de fuerza se sale del registro"))
    w = zeros(N)
    w[inicio:inicio+ancho-1] .= 1.0
    return w
end
