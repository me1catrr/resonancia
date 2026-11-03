# Pruebas de psd_mejorada, fsdd_modo e indicador_armonico (M7.7, ampliación). Las incluye runtests.jl.
using LinearAlgebra, Random, Statistics

# dos modos próximos con formas de MAC conocido, medidos en 3 canales con un 10 % de ruido de medida
function fdd_cercanos(; f1=3.0, f2=3.3, ζ=0.01, mac=0.42, fs=50.0, T=3000.0, semilla=1)
    p1 = [1.0, 0.8, 0.3]; p1 ./= norm(p1)
    q = [0.5, -0.4, 1.0]; q .-= dot(q, p1) * p1; q ./= norm(q)
    Phi = hcat(p1, sqrt(mac) * p1 + sqrt(1 - mac) * q)
    rng = MersenneTwister(semilla)
    Y = respuesta_modal(Phi, [f1, f2], [ζ, ζ], randn(rng, Int(T * fs), 3), fs)
    Y .+= 0.1 .* std(Y; dims=1) .* randn(rng, size(Y))
    f, s, U = fdd(Y, fs; nseg=4096)
    return (; Y, Phi, f, s, U, fs)
end

@testset "psd_mejorada y fsdd_modo: modos próximos de formas no ortogonales" begin
    d = fdd_cercanos()
    for fm in (3.0, 3.3)
        k0 = argmin(abs.(d.f .- fm)); k = k0 - 4 + argmax(d.s[1, k0-4:k0+4])
        e = psd_mejorada(d.s, d.U, k)
        @test length(e) == length(d.f)
        @test all(e .>= -1e-12)
        @test e[k] ≈ d.s[1, k] rtol = 1e-9                  # en el pico, la PSD mejorada es la primera curva singular
        @test all(e .<= d.s[1, :] .+ 1e-12 .* d.s[1, :])    # filtrar con un vector unitario no puede superar a σ₁
        m = fsdd_modo(d.f, d.s, d.U, k)
        @test m.zeta ≈ 0.01 rtol = 0.25
        @test m.f_n ≈ fm rtol = 0.005
        @test m.banda[1] < k < m.banda[2] && m.lineas >= 4
        @test m.modelo(d.f[k]) ≈ e[k] rtol = 0.3        # la lorentziana ajustada pasa cerca del pico
    end
    k0 = argmin(abs.(d.f .- 3.0)); k = k0 - 4 + argmax(d.s[1, k0-4:k0+4])
    @test_throws ArgumentError fsdd_modo(d.f, d.s, d.U, k; frac=1.5)
    @test_throws ArgumentError psd_mejorada(d.s, d.U, 0)
end

@testset "fsdd_modo: un modo aislado con segmentos cortos" begin
    fs = 50.0
    Y = respuesta_modal(ones(1, 1), [3.0], [0.01], randn(MersenneTwister(2), 150_000, 1), fs)
    Y = hcat(Y, 0.7 .* Y .+ 0.0 .* Y)                                  # dos canales proporcionales: un solo modo
    f, s, U = fdd(Y, fs; nseg=2048)
    k = argmax(s[1, :])
    @test fsdd_modo(f, s, U, k).zeta ≈ 0.01 rtol = 0.3
end

@testset "indicador_armonico: un modo es gaussiano y una sinusoide, no" begin
    fs, N = 50.0, 2^16
    t = (0:N-1) ./ fs
    rng = MersenneTwister(5)
    Y = respuesta_modal([1.0 0.2; 0.7 -0.9; 0.3 1.0] ./ [1.2 1.0], [3.0, 5.0], [0.01, 0.01], randn(rng, N, 3), fs)
    Y .+= 0.1 .* std(Y; dims=1) .* randn(rng, size(Y))
    modo = indicador_armonico(Y, fs, 3.0; ancho=0.3)
    @test all(abs.(modo.exceso) .< 4 * modo.incertidumbre)
    Yh = Y .+ 0.35 * std(Y[:, 1]) .* sin.(2π * 4.0 .* t) * [1.0, 0.5, -0.7]'
    arm = indicador_armonico(Yh, fs, 4.0; ancho=0.3)
    @test all(arm.exceso .< -0.5)
    @test all(arm.exceso .> -1.6)
    @test arm.incertidumbre ≈ sqrt(24 / (N / fs * 0.3))
    # sinusoide casi pura: exceso ≈ −1,5
    puro = indicador_armonico(sin.(2π * 5.0 .* t) .+ 0.01 .* randn(rng, N), fs, 5.0; ancho=1.0)
    @test puro.exceso[1] ≈ -1.5 atol = 0.05
    # vector y matriz de una columna dan lo mismo
    @test indicador_armonico(Y[:, 1], fs, 3.0; ancho=0.3).exceso == indicador_armonico(Y[:, 1:1], fs, 3.0; ancho=0.3).exceso
    @test_throws ArgumentError indicador_armonico(Y, fs, 3.0; ancho=-1.0)
    @test_throws ArgumentError indicador_armonico(Y, fs, 24.9; ancho=1.0)
    @test_throws ArgumentError indicador_armonico(Y[1:32, :], fs, 3.0; ancho=0.3)
end
