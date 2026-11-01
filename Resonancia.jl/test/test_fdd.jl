# Pruebas de src/fdd.jl (M7.7: FDD y EFDD). Las incluye runtests.jl.
using LinearAlgebra, Random, Statistics

# viga con 6 canales y formas sin(iπx/L); modos 1 a 4, los dos centrales separados 0,12 Hz
function fdd_caso(; fn=[3.26, 3.68, 3.80, 5.16], ζ=[0.010, 0.012, 0.012, 0.015], fs=50.0, T=1800.0, semilla=11, nseg=4096)
    x = (1:6) ./ 7
    Phi = hcat([sin.(i * π .* x) for i in 1:length(fn)]...)
    rng = MersenneTwister(semilla)
    Y = respuesta_modal(Phi, fn, ζ, randn(rng, Int(T * fs), 6), fs)
    Y .+= 0.05 * std(Y) .* randn(rng, size(Y))
    f, s, U = fdd(Y, fs; nseg=nseg)
    return (; Y, Phi, f, s, U, fs, fn, ζ)
end

@testset "matriz_espectral: hermítica, semidefinida positiva y coherente con psd_welch" begin
    rng = MersenneTwister(3)
    Y = cumsum(randn(rng, 20000, 3); dims=1) .* 0.01 .+ randn(rng, 20000, 3)
    f, S = matriz_espectral(Y, 100.0; nseg=1024)
    @test size(S) == (3, 3, 513)
    for c in 1:3
        _, P = psd_welch(Y[:, c], 100.0; nseg=1024)
        @test real.(S[c, c, :]) ≈ P rtol = 1e-10
    end
    for k in (1, 7, 100, 513)
        @test S[:, :, k] ≈ S[:, :, k]' atol = 1e-12 * maximum(abs, S[:, :, k])
        @test minimum(eigvals(Hermitian(S[:, :, k]))) >= -1e-10 * maximum(abs, S[:, :, k])
    end
    @test_throws ArgumentError matriz_espectral(Y[1:500, :], 100.0; nseg=1024)
    @test_throws ArgumentError matriz_espectral(Y, 100.0; nseg=1024, solape=1.0)
end

@testset "respuesta_modal: un modo tiene su pico en fn y su ancho 2ζ·fn" begin
    rng = MersenneTwister(5)
    fs = 200.0
    y = respuesta_modal(ones(1, 1), [5.0], [0.05], randn(rng, 400000, 1), fs)
    f, P = psd_welch(vec(y), fs; nseg=4096)
    k = argmax(P)
    @test f[k] ≈ 5.0 atol = 0.1
    # ancho de media potencia
    mitad = P[k] / 2
    ia = k; while P[ia] > mitad; ia -= 1; end
    ib = k; while P[ib] > mitad; ib += 1; end
    @test (f[ib] - f[ia]) ≈ 2 * 0.05 * 5.0 rtol = 0.3
    @test_throws DimensionMismatch respuesta_modal(ones(2, 1), [5.0, 6.0], [0.05], zeros(10, 2), fs)
    @test_throws DimensionMismatch respuesta_modal(ones(2, 1), [5.0], [0.05], zeros(10, 3), fs)
end

@testset "fdd: valores singulares decrecientes, un modo aislado da rango casi uno" begin
    d = fdd_caso()
    @test all(d.s[1:end-1, :] .>= d.s[2:end, :])
    @test size(d.U) == (6, 6, length(d.f))
    k = argmin(abs.(d.f .- 5.16))
    @test d.s[2, k] / d.s[1, k] < 0.02
    @test abs(dot(d.U[:, 1, k], d.U[:, 1, k])) ≈ 1 atol = 1e-10
end

@testset "mac_complejo" begin
    a = [1.0 + 0im, 2.0, -1.0]
    @test mac_complejo(a, a) ≈ 1
    @test mac_complejo(a, (2 - 3im) .* a) ≈ 1
    @test mac_complejo([1.0, 0, 0], [0, 1.0, 0]) ≈ 0 atol = 1e-15
end

@testset "efdd_modo: recupera cuatro modos conocidos, dos de ellos próximos" begin
    d = fdd_caso()
    pk(i) = d.s[1, i] > d.s[1, i-1] && d.s[1, i] > d.s[1, i+1]
    tolζ = [0.25, 0.4, 0.4, 0.25]      # el amortiguamiento de modos próximos se subestima (véase M7.7)
    for (m, fm) in enumerate(d.fn)
        c = [i for i in 2:length(d.f)-1 if pk(i) && abs(d.f[i] - fm) <= 0.04]
        @test !isempty(c)
        k = c[argmin(abs.(d.f[c] .- fm))]
        e = efdd_modo(d.f, d.s, d.U, k)
        @test e.f_n ≈ fm rtol = 0.007
        @test e.zeta ≈ d.ζ[m] rtol = tolζ[m]
        @test mac_complejo(d.Phi[:, m], real.(e.forma)) > 0.99
        @test d.f[e.banda[1]] <= d.f[k] <= d.f[e.banda[2]]
        @test abs(e.r[1]) ≈ 1
    end
    @test_throws ArgumentError efdd_modo(d.f, d.s, d.U, 1)
end
