"""
    fft_radix2(x) -> Vector{ComplexF64}

Transformada discreta de Fourier de `x` por Cooley–Tukey iterativo (radix-2).
La longitud de `x` debe ser una potencia de 2. Convención de signo: `X[k] = Σ x[n] e^{-2πi kn/N}`.
"""
function fft_radix2(x::AbstractVector{<:Number})
    n = length(x)
    (n > 0 && count_ones(n) == 1) || throw(ArgumentError("la longitud debe ser una potencia de 2, no $n"))
    a = ComplexF64.(x)
    # ordenación por inversión de bits
    j = 0
    for i in 1:n-1
        bit = n >> 1
        while j & bit != 0
            j ⊻= bit
            bit >>= 1
        end
        j ⊻= bit
        i < j && ((a[i+1], a[j+1]) = (a[j+1], a[i+1]))
    end
    len = 2
    while len <= n
        w_len = cis(-2π / len)
        for i in 0:len:n-1
            w = 1.0 + 0.0im
            for k in 0:len÷2-1
                u = a[i+k+1]
                v = a[i+k+len÷2+1] * w
                a[i+k+1] = u + v
                a[i+k+len÷2+1] = u - v
                w *= w_len
            end
        end
        len <<= 1
    end
    return a
end

"""
    psd_welch(x, fs; nseg=4096, solape=0.5) -> (f, P)

Densidad espectral de potencia unilateral de `x` (muestreada a `fs` Hz) por el
método de Welch: segmentos de `nseg` muestras (potencia de 2), ventana de Hann,
solape relativo `solape`, media restada a cada segmento. `P` está en unidades²/Hz y
cumple `sum(P)*(f[2]-f[1]) ≈ var(x)` (teorema de Parseval).
"""
function psd_welch(x::AbstractVector{<:Real}, fs::Real; nseg::Int=4096, solape::Real=0.5)
    length(x) >= nseg || throw(ArgumentError("la señal ($(length(x)) muestras) es más corta que un segmento ($nseg)"))
    0 <= solape < 1 || throw(ArgumentError("el solape debe estar en [0, 1)"))
    w = [0.5 - 0.5cos(2π * n / nseg) for n in 0:nseg-1]  # Hann periódica
    paso = max(1, round(Int, nseg * (1 - solape)))
    nf = nseg ÷ 2 + 1
    P = zeros(nf)
    nsegs = 0
    for ini in 1:paso:length(x)-nseg+1
        s = Float64.(view(x, ini:ini+nseg-1))
        s .-= sum(s) / nseg
        X = fft_radix2(s .* w)
        @inbounds for k in 1:nf
            P[k] += abs2(X[k])
        end
        nsegs += 1
    end
    P .*= 1 / (nsegs * fs * sum(abs2, w))
    P[2:nf-1] .*= 2  # lado unilateral: se duplica todo salvo DC y Nyquist
    f = collect(0:nf-1) .* (fs / nseg)
    return f, P
end

"""
    buscar_picos(f, P; fmin=0, fmax=Inf, n=5, separacion=0.0) -> Vector{Int}

Índices de los `n` máximos locales más altos de `P` con `fmin ≤ f ≤ fmax`, separados al
menos `separacion` (Hz) entre sí, ordenados por frecuencia creciente.
"""
function buscar_picos(f::AbstractVector, P::AbstractVector; fmin=0.0, fmax=Inf, n::Int=5, separacion=0.0)
    candidatos = [k for k in 2:length(P)-1 if fmin <= f[k] <= fmax && P[k] > P[k-1] && P[k] >= P[k+1]]
    sort!(candidatos; by=k -> -P[k])
    elegidos = Int[]
    for k in candidatos
        all(abs(f[k] - f[j]) >= separacion for j in elegidos) && push!(elegidos, k)
        length(elegidos) == n && break
    end
    return sort(elegidos)
end

"""
    rms_por_ventana(x, fs, ventana_s) -> (t, r)

Valor eficaz (RMS) de `x` en ventanas consecutivas de `ventana_s` segundos. `t` es el
instante central de cada ventana, en segundos desde el inicio de `x`.
"""
function rms_por_ventana(x::AbstractVector{<:Real}, fs::Real, ventana_s::Real)
    m = max(1, round(Int, fs * ventana_s))
    nv = length(x) ÷ m
    r = [sqrt(sum(abs2, view(x, (i-1)*m+1:i*m)) / m) for i in 1:nv]
    t = [((i - 1) * m + m / 2) / fs for i in 1:nv]
    return t, r
end

"""
    frecuencia_pico_por_segmentos(x, fs; seg, banda, nseg=2048, solape=0.5) -> Vector{Float64}

Frecuencia (Hz) del pico más alto dentro de `banda = (fmin, fmax)` del espectro de Welch de cada segmento
consecutivo de `seg` muestras de `x` (muestreada a `fs` Hz); el resto final que no completa un segmento se
descarta. Cada segmento se analiza con `psd_welch(…; nseg, solape)`, de modo que la resolución en frecuencia
es `fs/nseg`. Sirve para estimar la dispersión de la frecuencia de un modo a lo largo de un registro.
"""
function frecuencia_pico_por_segmentos(x::AbstractVector{<:Real}, fs::Real; seg::Integer, banda::Tuple{<:Real,<:Real},
        nseg::Int=2048, solape::Real=0.5)
    seg >= nseg || throw(ArgumentError("seg ($seg) debe ser al menos nseg ($nseg)"))
    length(x) >= seg || throw(ArgumentError("el registro es más corto que un segmento"))
    return map(1:length(x)÷seg) do k
        f, P = psd_welch(view(x, (k-1)*seg+1:k*seg), fs; nseg=nseg, solape=solape)
        f[buscar_picos(f, P; fmin=banda[1], fmax=banda[2], n=1)[1]]
    end
end
