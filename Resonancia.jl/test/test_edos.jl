# Pruebas de src/edos.jl (J3.6). Las incluye runtests.jl dentro de su `using Test` y `using Resonancia`.

@testset "respuesta_libre_1gdl" begin
    f0, z = 2.94, 0.02
    @test respuesta_libre_1gdl(0.0, f0, z) == 1.0                              # condición inicial x(0) = x0
    @test respuesta_libre_1gdl(0.0, f0, z; x0=3.0) == 3.0
    # sin amortiguamiento es un coseno puro y, con v0, un seno
    @test respuesta_libre_1gdl(0.1, 2.0, 0.0) ≈ cos(2π * 2.0 * 0.1)
    @test respuesta_libre_1gdl(0.1, 2.0, 0.0; x0=0.0, v0=2π * 2.0) ≈ sin(2π * 2.0 * 0.1)
    # derivada en t = 0 igual a v0 (diferencia centrada)
    h = 1e-6
    for v0 in (0.0, 0.7, -1.3)
        d = (respuesta_libre_1gdl(h, f0, z; v0=v0) - respuesta_libre_1gdl(-h, f0, z; v0=v0)) / 2h
        @test d ≈ v0 atol = 1e-6
    end
    # decrecimiento de los picos: cociente entre picos consecutivos = e^{-2π ζ/√(1-ζ²)}
    Td = 1 / (f0 * sqrt(1 - z^2))
    x1 = respuesta_libre_1gdl(Td, f0, z); x2 = respuesta_libre_1gdl(2Td, f0, z)
    @test x2 / x1 ≈ exp(-2π * z / sqrt(1 - z^2)) rtol = 1e-3
    # verifica la ecuación diferencial: x'' + 2ζω x' + ω² x = 0
    w = 2π * f0; t = 0.37; h = 1e-4
    x = t -> respuesta_libre_1gdl(t, f0, z; x0=1.0, v0=0.5)
    res = (x(t + h) - 2x(t) + x(t - h)) / h^2 + 2z * w * (x(t + h) - x(t - h)) / 2h + w^2 * x(t)
    @test abs(res) < 1e-3 * w^2
    @test_throws ArgumentError respuesta_libre_1gdl(0.0, f0, 1.0)
    @test_throws ArgumentError respuesta_libre_1gdl(0.0, f0, -0.1)
    @test_throws ArgumentError respuesta_libre_1gdl(0.0, 0.0, 0.02)
end

@testset "fuerza_multiseno y rms_respuesta_multiseno" begin
    f = [1.0, 2.0, 3.0]; A = [2.0, 1.0, 0.5]; ph = [0.0, π / 2, π]
    @test fuerza_multiseno(0.0, f, A, ph) ≈ 2.0 + 0.0 - 0.5
    @test fuerza_multiseno(0.25, f, A, ph) ≈ 2cos(π / 2) + cos(π + π / 2) + 0.5cos(1.5π + π) atol = 1e-12
    @test_throws DimensionMismatch fuerza_multiseno(0.0, f, A[1:2], ph)
    # un solo armónico: rms = A|H|/√2
    f0, z, k = 2.0, 0.01, 8.0e5
    @test rms_respuesta_multiseno([2.0], [10.0], f0, z, k) ≈ 10.0 * abs(frf_1gdl(2.0, f0, z, 1 / k)) / sqrt(2)
    # rejilla de armónicos: el rms de la fuerza es √(ΣA²/2) y es periódica de periodo 1/Δf
    Δf = 0.5; fk = collect(Δf:Δf:3.0); Ak = fill(1.0, length(fk)); phk = collect(range(0.3, 2.9, length=length(fk)))
    ts = range(0, 1 / Δf, length=4001)[1:end-1]
    F = [fuerza_multiseno(t, fk, Ak, phk) for t in ts]
    @test sqrt(sum(abs2, F) / length(F)) ≈ sqrt(sum(Ak .^ 2) / 2) rtol = 1e-9
    @test fuerza_multiseno(0.0, fk, Ak, phk) ≈ fuerza_multiseno(1 / Δf, fk, Ak, phk)
    # el rms de la respuesta no depende de las fases y la rigidez actúa como escala (∝ 1/k)
    @test rms_respuesta_multiseno(fk, Ak, 1.5, 0.05, k) ≈ rms_respuesta_multiseno(fk, Ak, 1.5, 0.05, 2k) * 2
    @test_throws ArgumentError rms_respuesta_multiseno(fk, Ak, 1.5, 0.05, 0.0)
    @test_throws DimensionMismatch rms_respuesta_multiseno(fk, Ak[1:2], 1.5, 0.05, k)
end

@testset "aceleracion_1gdl" begin
    f0, z, fs = 4.0, 0.015, 200.0
    w = 2π * f0; wd = w * sqrt(1 - z^2)
    t = collect(0:1/fs:5.0-1/fs)
    # escalón unitario (constante entre muestras: la discretización es exacta):
    # ẍ(t) = e^{-ζωt} (cos ω_d t - ζω/ω_d sin ω_d t)
    a = aceleracion_1gdl(ones(length(t)), f0, z, fs)
    @test a ≈ exp.(-z * w .* t) .* (cos.(wd .* t) .- z * w / wd .* sin.(wd .* t)) atol = 1e-10
    @test a[1] == 1.0                                              # en t = 0 solo actúa u: ẍ(0) = u(0)
    # sin fuerza no hay respuesta, y la respuesta es lineal en u
    @test all(iszero, aceleracion_1gdl(zeros(100), f0, z, fs))
    u = sin.(2π * 3.0 .* t[1:400]); v = cos.(2π * 5.0 .* t[1:400])
    @test aceleracion_1gdl(2u .+ 3v, f0, z, fs) ≈ 2aceleracion_1gdl(u, f0, z, fs) .+ 3aceleracion_1gdl(v, f0, z, fs) atol = 1e-10
    # armónica a la frecuencia natural: en régimen estacionario la aceleración llega a 1/(2ζ) veces la amplitud de u
    tt = collect(0:1/fs:60.0-1/fs)
    ar = aceleracion_1gdl(sin.(w .* tt), f0, z, fs)
    @test maximum(abs, ar[end-2000:end]) ≈ 1 / (2z) rtol = 2e-2
    @test_throws ArgumentError aceleracion_1gdl(u, f0, 1.0, fs)
    @test_throws ArgumentError aceleracion_1gdl(u, 0.0, z, fs)
    @test_throws ArgumentError aceleracion_1gdl(u, f0, z, 0.0)
end
