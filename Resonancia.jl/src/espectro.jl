"""
    dft(x) -> Vector{ComplexF64}

Transformada discreta de Fourier de `x` para cualquier longitud `N`, con la misma convención que
`fft_radix2` (`X[k] = Σ x[n] e^{-2πi kn/N}`). Si `N` es potencia de 2 llama a `fft_radix2`; si no,
usa el algoritmo de Bluestein (transformada chirp-z), que reescribe la DFT como una convolución
calculada con FFT de potencia de 2. Coste `O(N log N)` en ambos casos.
"""
function dft(x::AbstractVector{<:Number})
    N = length(x)
    N > 0 || throw(ArgumentError("la señal está vacía"))
    count_ones(N) == 1 && return fft_radix2(x)
    # chirp e^{-iπ n²/N}; n² mod 2N evita perder precisión con ángulos grandes
    w = [cis(-π * mod(n * n, 2N) / N) for n in 0:N-1]
    M = 1
    while M < 2N - 1
        M <<= 1
    end
    a = zeros(ComplexF64, M)
    a[1:N] .= x .* w
    b = zeros(ComplexF64, M)
    b[1:N] .= conj.(w)
    for n in 1:N-1
        b[M-n+1] = conj(w[n+1])
    end
    c = ifft_radix2(fft_radix2(a) .* fft_radix2(b))
    return w .* c[1:N]
end

# Bins unilaterales de una DFT de nfft puntos: 0..⌊nfft/2⌋. Se duplican todos salvo DC y,
# si nfft es par, Nyquist (que no tienen pareja en frecuencias negativas).
function _unilateral(nfft)
    nf = nfft ÷ 2 + 1
    doble = fill(2.0, nf)
    doble[1] = 1.0
    iseven(nfft) && (doble[nf] = 1.0)
    return nf, doble
end

function _preparar(x, nombre_ventana, nfft, quitar_media)
    N = length(x)
    nfft >= N || throw(ArgumentError("nfft ($nfft) no puede ser menor que la longitud de la señal ($N)"))
    w = ventana(nombre_ventana, N)
    s = Float64.(x)
    quitar_media && (s .-= sum(s) / N)
    return w, dft(vcat(s .* w, zeros(nfft - N)))
end

"""
    periodograma(x, fs; ventana=:rectangular, nfft=length(x), quitar_media=true) -> (f, P)

Densidad espectral de potencia (PSD) unilateral de `x` estimada con un único periodograma (M3.6):
`P[k] = c_k |X[k]|² / (fs Σw²)`, con `X` la DFT de `x·w` rellenada con ceros hasta `nfft` puntos,
`Σw²` la energía de la ventana y `c_k = 2` salvo en DC y en Nyquist (`c_k = 1`). Unidades: las de
`x` al cuadrado por hercio. Con cualquier ventana se cumple `sum(P)·Δf = Σ(x w)² / Σw²` (con
`Δf = fs/nfft`), que con la rectangular es el valor cuadrático medio de `x` (Parseval). Con
`quitar_media=false` la media aparece en el bin de DC con potencia μ²/Δf (sin duplicar).
"""
function periodograma(x::AbstractVector{<:Real}, fs::Real; ventana::Symbol=:rectangular,
        nfft::Integer=length(x), quitar_media::Bool=true)
    w, X = _preparar(x, ventana, nfft, quitar_media)
    nf, doble = _unilateral(nfft)
    P = doble .* abs2.(X[1:nf]) ./ (fs * sum(abs2, w))
    return collect(0:nf-1) .* (fs / nfft), P
end

"""
    espectro_amplitud(x, fs; ventana=:rectangular, nfft=length(x), quitar_media=false) -> (f, A, fase)

Espectro de amplitud unilateral de `x` (M3.5): `A[k] = c_k |X[k]| / Σw`, con `c_k = 2` salvo en DC y
Nyquist. Una sinusoide `a·cos(2π f₀ t + φ)` con `f₀` en el centro de un bin da `A = a` y `fase = φ`
(rad) en ese bin. Unidades: las de `x` (amplitud de pico). El relleno con ceros (`nfft > length(x)`)
interpola el espectro pero no añade información.
"""
function espectro_amplitud(x::AbstractVector{<:Real}, fs::Real; ventana::Symbol=:rectangular,
        nfft::Integer=length(x), quitar_media::Bool=false)
    w, X = _preparar(x, ventana, nfft, quitar_media)
    nf, doble = _unilateral(nfft)
    return collect(0:nf-1) .* (fs / nfft), doble .* abs.(X[1:nf]) ./ sum(w), angle.(X[1:nf])
end

"""
    potencia_bandas(f, P, bandas) -> (potencia, fraccion)

Integral discreta `Σ P[k]·Δf` de una PSD unilateral en cada banda `(fa, fb)` de `bandas`, con el criterio
semiabierto `fa ≤ f < fb`, y su fracción de la potencia total `Σ P·Δf` del espectro completo. `potencia`
tiene las unidades de `x`²; `fraccion` es adimensional. La raíz de la potencia de una banda es el RMS de
la señal en esa banda.
"""
function potencia_bandas(f::AbstractVector, P::AbstractVector, bandas)
    Δf = f[2] - f[1]
    total = sum(P) * Δf
    pot = [sum(P[k] for k in eachindex(f) if fa <= f[k] < fb; init=0.0) * Δf for (fa, fb) in bandas]
    return pot, pot ./ total
end

"""
    psd_normalizada(f, P; banda=(f[1], f[end])) -> (fb, Pn)

PSD normalizada (NPSD) en la convención declarada en M3.6: se toman los bins con `fa ≤ f ≤ fb` y se
dividen por su suma, de modo que `sum(Pn) = 1`. `Pn[k]` es la **fracción de la potencia de la banda que
cae en el bin k** (adimensional); no es una densidad por hercio. Para obtener una densidad normalizada
(1/Hz) habría que dividir además por `Δf` (normalizar por la integral en lugar de por la suma).
"""
function psd_normalizada(f::AbstractVector, P::AbstractVector; banda=(f[1], f[end]))
    sel = findall(v -> banda[1] <= v <= banda[2], f)
    isempty(sel) && throw(ArgumentError("ningún bin dentro de la banda $banda"))
    s = sum(P[sel])
    s > 0 || throw(ArgumentError("la PSD es nula en la banda"))
    return f[sel], P[sel] ./ s
end

"""
    anpsd(f, Ps; banda=(f[1], f[end])) -> (fb, A)

Promedio de PSD normalizadas (ANPSD) de varios canales, en la convención declarada en M3.6: cada
columna de `Ps` (una PSD por canal, todas sobre la misma rejilla `f`) se normaliza con
`psd_normalizada` en la misma `banda` y después se promedian los canales bin a bin. El resultado
suma 1 y es adimensional: conserva **dónde** está la potencia, no cuánta hay; un canal débil o
ruidoso pesa tanto como uno fuerte.
"""
function anpsd(f::AbstractVector, Ps::AbstractMatrix; banda=(f[1], f[end]))
    size(Ps, 1) == length(f) || throw(ArgumentError("cada columna de Ps debe tener length(f) bins"))
    cols = [psd_normalizada(f, view(Ps, :, j); banda=banda) for j in axes(Ps, 2)]
    return cols[1][1], sum(c[2] for c in cols) ./ length(cols)
end

"""
    colorear(r, α) -> Vector{Float64}

Ruido «de color» a partir de un ruido blanco `r` (M3.1): multiplica la DFT de `r` por `|k|^(-α/2)` (con `k`
el índice de frecuencia con signo y el bin de DC anulado), vuelve al tiempo y escala el resultado a media 0
y desviación típica 1. La PSD queda proporcional a `1/f^α`: `α = 0` blanco, `α = 1` rosa (1/f),
`α = 2` marrón (1/f²). Es determinista dado `r`, de modo que las versiones en Julia, JavaScript y Python
se contrastan con la misma entrada.
"""
function colorear(r::AbstractVector{<:Real}, α::Real)
    N = length(r)
    N >= 2 || throw(ArgumentError("hacen falta al menos 2 muestras"))
    X = dft(r)
    X[1] = 0
    for k in 1:N-1
        X[k+1] *= min(k, N - k)^(-α / 2)
    end
    y = real.(conj.(dft(conj.(X)))) ./ N   # DFT inversa
    y .-= sum(y) / N
    return y ./ sqrt(sum(abs2, y) / N)
end
