"""
    ventana(nombre, N) -> Vector{Float64}

Ventana de `N` puntos (periódica, para análisis espectral): `:rectangular`, `:hann`, `:hamming`,
`:blackman` o `:flattop` (coeficientes de cinco términos que dan un lóbulo principal ancho y de amplitud casi plana).
"""
function ventana(nombre::Symbol, N::Integer)
    n = 0:N-1
    c(k) = cos.(2π * k .* n ./ N)
    nombre === :rectangular && return ones(N)
    nombre === :hann && return 0.5 .- 0.5 .* c(1)
    nombre === :hamming && return 0.54 .- 0.46 .* c(1)
    nombre === :blackman && return 0.42 .- 0.5 .* c(1) .+ 0.08 .* c(2)
    nombre === :flattop && return 0.21557895 .- 0.41663158 .* c(1) .+ 0.277263158 .* c(2) .- 0.083578947 .* c(3) .+ 0.006947368 .* c(4)
    throw(ArgumentError("ventana desconocida: $nombre"))
end

"""
    ganancia_coherente(w) / ancho_banda_ruido(w)

Ganancia coherente `Σw/N` (factor de amplitud de una sinusoide) y ancho de banda equivalente de ruido
`N Σw² / (Σw)²` en bins de la DFT (1 para la ventana rectangular, 1,5 para la de Hann).
"""
ganancia_coherente(w::AbstractVector) = sum(w) / length(w)
ancho_banda_ruido(w::AbstractVector) = length(w) * sum(abs2, w) / sum(w)^2

"""
    hilbert_analitica(x) -> Vector{ComplexF64}

Señal analítica `x + i H{x}` con el método de la FFT: se anulan las frecuencias negativas y se duplican las
positivas. La longitud debe ser potencia de 2. Su módulo es la envolvente y su argumento (desenrollado), la fase instantánea.
"""
function hilbert_analitica(x::AbstractVector{<:Real})
    N = length(x)
    X = fft_radix2(x)
    h = zeros(N)
    h[1] = 1
    h[2:N÷2] .= 2
    h[N÷2+1] = 1
    return ifft_radix2(X .* h)
end

"""
    fase_instantanea(z) -> Vector{Float64}

Argumento de la señal analítica `z` desenrollado (sin saltos de 2π).
"""
function fase_instantanea(z::AbstractVector{<:Complex})
    ph = angle.(z)
    for k in 2:length(ph)
        d = ph[k] - ph[k-1]
        ph[k:end] .-= 2π * round(d / 2π)
    end
    return ph
end

"""
    correlacion_cruzada(x, y, kmax) -> Vector{Float64}

Correlación cruzada muestral sesgada `r_xy[k] = (1/N) Σ_t (x_t-x̄)(y_{t+k}-ȳ)` para `k = -kmax, …, kmax`
(devuelve `2kmax+1` valores). Un máximo en `k>0` indica que `y` va retrasada `k` muestras respecto de `x`.
"""
function correlacion_cruzada(x::AbstractVector{<:Real}, y::AbstractVector{<:Real}, kmax::Integer)
    N = length(x)
    N == length(y) || throw(ArgumentError("x e y deben tener la misma longitud"))
    0 <= kmax < N || throw(ArgumentError("kmax debe estar entre 0 y N-1"))
    zx, zy = x .- sum(x) / N, y .- sum(y) / N
    return [k >= 0 ? sum(zx[t] * zy[t+k] for t in 1:N-k) / N : sum(zx[t-k] * zy[t] for t in 1:N+k) / N for k in -kmax:kmax]
end

"""
    autocorrelacion_fft(x, kmax) -> Vector{Float64}

Misma autocorrelación sesgada que `autocorrelacion`, calculada con la FFT (teorema de Wiener–Khinchin) y relleno de
ceros hasta la potencia de 2 siguiente a `2N`. Coste `O(N log N)` en lugar de `O(N·kmax)`.
"""
function autocorrelacion_fft(x::AbstractVector{<:Real}, kmax::Integer)
    N = length(x)
    0 <= kmax < N || throw(ArgumentError("kmax debe estar entre 0 y N-1"))
    M = nextpow(2, 2N)
    z = zeros(M)
    z[1:N] .= x .- sum(x) / N
    r = real(ifft_radix2(abs2.(fft_radix2(z))))
    return r[1:kmax+1] ./ N
end
