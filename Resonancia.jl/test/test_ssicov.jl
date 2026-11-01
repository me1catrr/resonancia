# Pruebas de src/ssicov.jl (M7.8: SSI-COV). Las incluye runtests.jl.
using LinearAlgebra, Random, Statistics

@testset "correlaciones_salidas: definición y referencias" begin
    rng = MersenneTwister(2)
    Y = randn(rng, 500, 3)
    R = correlaciones_salidas(Y, 4)
    X = Y .- mean(Y; dims=1)
    for j in 1:4
        @test R[:, :, j] ≈ X[1+j:end, :]' * X[1:end-j, :] ./ 500
    end
    Rr = correlaciones_salidas(Y, 4; refs=[1, 3])
    @test size(Rr) == (3, 2, 4)
    @test Rr == R[:, [1, 3], :]
    # el retardo 0 de un ruido blanco es la varianza; los demás, casi nulos
    Yb = randn(rng, 200000, 1)
    Rb = correlaciones_salidas(Yb, 3)
    @test all(abs.(Rb[1, 1, :]) .< 0.01)
    @test_throws ArgumentError correlaciones_salidas(Y, 500)
end

@testset "toeplitz_bloques: estructura" begin
    R = reshape(collect(1.0:2*3*5), 2, 3, 5)             # no = 2, r = 3, 5 retardos
    T = toeplitz_bloques(R, 3)
    @test size(T) == (6, 9)
    @test T[1:2, 1:3] == R[:, :, 3]                       # bloque (1,1) = R_jb
    @test T[1:2, 7:9] == R[:, :, 1]                       # esquina superior derecha = R_1
    @test T[5:6, 1:3] == R[:, :, 5]                       # esquina inferior izquierda = R_{2jb-1}
    @test T[3:4, 4:6] == T[1:2, 1:3] == T[5:6, 7:9]       # diagonales de bloques constantes
    @test_throws ArgumentError toeplitz_bloques(R, 4)
end

# sistema de estado discreto conocido con dos modos: R_j = C A^{j-1} G exactamente
function ssi_modelo_conocido(; dt=0.02, fn=[2.0, 5.0], ζ=[0.02, 0.01], no=3, r=3, jb=12, semilla=4)
    rng = MersenneTwister(semilla)
    n = 2 * length(fn)
    A = zeros(n, n)
    for (m, (f, z)) in enumerate(zip(fn, ζ))
        λ = 2π * f * (-z + im * sqrt(1 - z^2))
        a, b = real(exp(λ * dt)), imag(exp(λ * dt))
        A[2m-1:2m, 2m-1:2m] = [a -b; b a]
    end
    S = randn(rng, n, n); A = S * A * inv(S)              # cambio de base: los polos no cambian
    C = randn(rng, no, n); G = randn(rng, n, r)
    R = zeros(no, r, 2jb - 1)
    for j in 1:2jb-1
        R[:, :, j] = C * A^(j - 1) * G
    end
    return (; A, C, G, R, dt, fn, ζ, jb)
end

@testset "SSI-COV con correlaciones teóricas: rango n y recuperación exacta" begin
    m = ssi_modelo_conocido()
    mod = ssi_cov_desde_correlaciones(m.R, m.jb, m.dt)
    @test count(>(1e-10 * mod.S[1]), mod.S) == 4          # rango = orden del modelo
    f, z, P = ssi_cov_orden(mod, 4)
    @test f ≈ m.fn rtol = 1e-8
    @test z ≈ m.ζ rtol = 1e-6
    # formas: C Ψ coincide (salvo escala) con las de la base original
    E = eigen(m.A)
    for (i, fi) in enumerate(m.fn)
        λ = 2π * fi * (-m.ζ[i] + im * sqrt(1 - m.ζ[i]^2))
        j = argmin(abs.(E.values .- exp(λ * m.dt)))
        @test mac_complejo(P[:, i], m.C * E.vectors[:, j]) ≈ 1 atol = 1e-8
    end
    @test_throws ArgumentError ssi_cov_orden(mod, 0)
    @test_throws ArgumentError ssi_cov_orden(mod, length(mod.S) + 1)
end

@testset "SSI-COV de extremo a extremo con modos próximos y pocas referencias" begin
    fn = [3.26, 3.68, 3.80, 5.16]; ζ = [0.010, 0.012, 0.012, 0.015]
    x = (1:6) ./ 7
    Phi = hcat([sin.(i * π .* x) for i in 1:4]...)
    fs = 50.0; rng = MersenneTwister(11)
    Y = respuesta_modal(Phi, fn, ζ, randn(rng, 90000, 6), fs)
    Y .+= 0.05 * std(Y) .* randn(rng, size(Y))
    for refs in (1:6, [1, 4])
        m = ssi_cov_preparar(Y, fs; jb=60, refs=refs)
        @test m.S[9] / m.S[1] < 0.02                      # salto tras 8 valores singulares (2 por modo)
        f, z, P = ssi_cov_orden(m, 12)
        for i in 1:4
            j = argmin(abs.(f .- fn[i]))
            @test f[j] ≈ fn[i] rtol = 0.005
            @test z[j] ≈ ζ[i] rtol = 0.2
            @test mac_complejo(Phi[:, i], real.(P[:, j])) > 0.99
        end
    end
end

@testset "modos_estables" begin
    P = [1.0 0.0; 0.0 1.0]
    prev = ([3.0, 5.0], [0.02, 0.01], P)
    act = ([3.01, 5.5, 7.0], [0.021, 0.01, -0.02], [1.0 0.0 1.0; 0.0 1.0 0.0])
    @test modos_estables(prev, act) == [true, false, false]
    # misma frecuencia y amortiguamiento, pero forma distinta (MAC bajo): no estable
    act2 = ([3.0], [0.02], reshape([0.0, 1.0], 2, 1))
    @test modos_estables(prev, act2) == [false]
end
