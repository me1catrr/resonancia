# Espectros cruzados, coherencia y FRF H1/H2 (M4.6) y espectrograma (M4.7).

# Índices de inicio (base 1) de los segmentos de Welch.
function _inicios(N, nseg, solape)
    N >= nseg || throw(ArgumentError("la señal ($N muestras) es más corta que un segmento ($nseg)"))
    0 <= solape < 1 || throw(ArgumentError("el solape debe estar en [0, 1)"))
    nseg >= 2 || throw(ArgumentError("nseg debe ser al menos 2"))
    return collect(1:max(1, round(Int, nseg * (1 - solape))):N-nseg+1)
end

"""
    espectros_cruzados(x, y, fs; nseg=1024, solape=0.5, ventana=:hann) -> (f, Gxx, Gyy, Gxy)

Autoespectros `Gxx` y `Gyy` y espectro cruzado `Gxy` unilaterales de la entrada `x` y la salida `y` (M4.6), por
el método de Welch con la misma convención que `psd_welch`: media restada a cada segmento y
`Gxy = promedio(conj(X)·Y)·c/(fs·Σw²)`, con `c = 2` salvo en continua y Nyquist. Con esta convención la FRF es
`H1 = Gxy/Gxx`: la fase de `Gxy` es la que **adelanta** `y` respecto de `x`. Unidades: las de `x·y` por hercio.
"""
function espectros_cruzados(x::AbstractVector{<:Real}, y::AbstractVector{<:Real}, fs::Real;
        nseg::Int=1024, solape::Real=0.5, ventana::Symbol=:hann)
    length(x) == length(y) || throw(ArgumentError("x e y deben tener la misma longitud"))
    inicios = _inicios(length(x), nseg, solape)
    w = Resonancia.ventana(ventana, nseg)
    nf, doble = _unilateral(nseg)
    Gxx, Gyy = zeros(nf), zeros(nf)
    Gxy = zeros(ComplexF64, nf)
    for ini in inicios
        sx = Float64.(x[ini:ini+nseg-1])
        sy = Float64.(y[ini:ini+nseg-1])
        sx .-= sum(sx) / nseg
        sy .-= sum(sy) / nseg
        X, Y = dft(sx .* w), dft(sy .* w)
        for k in 1:nf
            Gxx[k] += abs2(X[k])
            Gyy[k] += abs2(Y[k])
            Gxy[k] += conj(X[k]) * Y[k]
        end
    end
    c = doble ./ (length(inicios) * fs * sum(abs2, w))
    return collect(0:nf-1) .* (fs / nseg), Gxx .* c, Gyy .* c, Gxy .* c
end

"""
    coherencia(Gxx, Gyy, Gxy) -> Vector{Float64}

Coherencia `γ² = |Gxy|²/(Gxx·Gyy)` (M4.6), entre 0 y 1: fracción de la potencia de la salida que se explica
linealmente por la entrada en cada frecuencia. Vale 1 si la salida es una función lineal de la entrada sin ruido y
baja con ruido de medida, no linealidad o entradas no medidas. **Con un solo segmento vale siempre 1**: hay que
promediar varios (`espectros_cruzados` con registro largo) para que signifique algo.
"""
function coherencia(Gxx::AbstractVector, Gyy::AbstractVector, Gxy::AbstractVector)
    length(Gxx) == length(Gyy) == length(Gxy) || throw(ArgumentError("los tres espectros deben tener la misma longitud"))
    return abs2.(Gxy) ./ (Gxx .* Gyy)
end

"""
    frf_h1(Gxx, Gxy) -> Vector{ComplexF64}

Estimador `H1 = Gxy/Gxx` de la FRF (M4.6): insesgado si el ruido está en la **salida** (no correlado con la entrada);
se subestima si hay ruido en la entrada, en un factor igual a la coherencia debida a ese ruido. Es el habitual
con excitación por martillo o excitador cuando la fuerza se mide bien.
"""
frf_h1(Gxx::AbstractVector, Gxy::AbstractVector) = Gxy ./ Gxx

"""
    frf_h2(Gyy, Gxy) -> Vector{ComplexF64}

Estimador `H2 = Gyy/conj(Gxy)` de la FRF (M4.6): insesgado si el ruido está en la **entrada**; se sobrestima si hay
ruido en la salida. Se cumple `H1/H2 = γ²` en cada frecuencia, de modo que `H1` y `H2` coinciden donde la coherencia
es 1 y `H1 ≤ H2` en módulo en general.
"""
frf_h2(Gyy::AbstractVector, Gxy::AbstractVector) = Gyy ./ conj.(Gxy)

"""
    estimar_frf(x, y, fs; nseg=1024, solape=0.5, ventana=:hann) -> NamedTuple

Atajo de M4.6: calcula `espectros_cruzados` y devuelve `(f, H1, H2, coherencia, Gxx, Gyy, Gxy)` con la FRF
`H = Y/X` entre la entrada `x` y la salida `y` (mismas unidades de salida por unidad de entrada).
"""
function estimar_frf(x::AbstractVector{<:Real}, y::AbstractVector{<:Real}, fs::Real; kwargs...)
    f, Gxx, Gyy, Gxy = espectros_cruzados(x, y, fs; kwargs...)
    return (f=f, H1=frf_h1(Gxx, Gxy), H2=frf_h2(Gyy, Gxy), coherencia=coherencia(Gxx, Gyy, Gxy),
            Gxx=Gxx, Gyy=Gyy, Gxy=Gxy)
end

"""
    espectrograma(x, fs; nseg=256, solape=0.75, ventana=:hann) -> (t, f, P)

Espectrograma de `x` (M4.7): la PSD unilateral de cada segmento de `nseg` muestras, con la misma convención y
escalado que `psd_welch` (unidades²/Hz). `P[k, j]` es la PSD en la frecuencia `f[k]` del segmento `j`, centrado
en el instante `t[j]` (s, contando desde la primera muestra). El **promedio de las columnas de `P`** es exactamente la PSD
de Welch con los mismos parámetros. Compromiso tiempo-frecuencia: la resolución en frecuencia es `fs/nseg` y la
temporal, del orden de `nseg/fs`; mejorar una empeora la otra (no hay forma de tener ambas).
"""
function espectrograma(x::AbstractVector{<:Real}, fs::Real; nseg::Int=256, solape::Real=0.75, ventana::Symbol=:hann)
    inicios = _inicios(length(x), nseg, solape)
    w = Resonancia.ventana(ventana, nseg)
    nf, doble = _unilateral(nseg)
    c = doble ./ (fs * sum(abs2, w))
    P = zeros(nf, length(inicios))
    for (j, ini) in enumerate(inicios)
        s = Float64.(x[ini:ini+nseg-1])
        s .-= sum(s) / nseg
        X = dft(s .* w)
        P[:, j] .= c .* abs2.(X[1:nf])
    end
    return (inicios .- 1 .+ nseg / 2) ./ fs, collect(0:nf-1) .* (fs / nseg), P
end
