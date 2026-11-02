# Transformada wavelet continua con la wavelet de Morlet (M4.7, introducción).

"""
    cwt_morlet(x, fs, frecuencias; w0=6.0) -> Matrix{Float64}

Módulo de la transformada *wavelet* continua de `x` (muestreada a `fs` Hz) con la *wavelet* de Morlet de parámetro
`w0` (M4.7): para cada frecuencia de `frecuencias` (Hz), se multiplica la DFT de `x` por la respuesta en
frecuencia gaussiana `exp(-(s·ω - w0)²/2)`, con `ω = 2π f_k` y escala `s = w0/(2π f)`, **solo en frecuencias positivas**,
y se vuelve al tiempo duplicando (como una señal analítica). El resultado es una matriz de `length(frecuencias) × length(x)`
con la **amplitud** local: una sinusoide de amplitud `a` en la frecuencia `f` da `≈ a` en la fila de `f`, lejos de los extremos.

A diferencia de la STFT (espectrograma), el ancho de banda **crece con la frecuencia**: la desviación típica en
frecuencia del filtro es `f/w0` (resolución relativa constante) y la de la envolvente de la *wavelet* en tiempo, `s = w0/(2π f)`
(ambas de la envolvente de amplitud; su producto es 1/(2π) en Hz·s). Esto da mejor resolución
temporal a altas frecuencias y mejor resolución en frecuencia a bajas. Con `w0 = 6` la media de la *wavelet* es despreciable
(`exp(-18)`). Cerca de los extremos del registro hay efectos de borde (el «cono de influencia»): en una escala `s` (en segundos) abarcan
unas `3s` desde cada extremo. Las frecuencias deben estar entre 0 y `fs/2`.
"""
function cwt_morlet(x::AbstractVector{<:Real}, fs::Real, frecuencias::AbstractVector{<:Real}; w0::Real=6.0)
    N = length(x)
    N >= 2 || throw(ArgumentError("hacen falta al menos 2 muestras"))
    fs > 0 || throw(ArgumentError("fs debe ser positiva"))
    w0 > 0 || throw(ArgumentError("w0 debe ser positivo"))
    all(0 .< frecuencias .< fs / 2) || throw(ArgumentError("las frecuencias deben estar entre 0 y fs/2"))
    X = dft(Float64.(x))
    positivas = 1:(N-1)÷2                                   # índices k = 1…⌊(N−1)/2⌋ (frecuencias estrictamente positivas)
    W = Matrix{Float64}(undef, length(frecuencias), N)
    Y = zeros(ComplexF64, N)
    for (i, f) in enumerate(frecuencias)
        s = w0 / (2π * f)
        fill!(Y, 0)
        for k in positivas
            Y[k+1] = X[k+1] * exp(-(s * 2π * k * fs / N - w0)^2 / 2)
        end
        y = 2 .* conj.(dft(conj.(Y))) ./ N                  # 2·DFT inversa
        W[i, :] .= abs.(y)
    end
    return W
end
