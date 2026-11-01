# Pruebas de src/lscf.jl (M7.3, ampliación PolyMAX). Las incluye runtests.jl.
using LinearAlgebra, Random

# Tres modos con residuos complejos fijos (frecuencia natural en Hz, razón de amortiguamiento, residuo)
const LSCF_MODOS = [(3.2, 0.020, 0.8 - 0.3im), (5.1, 0.015, -0.5 + 0.6im), (7.4, 0.010, 0.4 + 0.2im)]
lscf_lam(fn, z) = 2π * fn * (-z + im * sqrt(1 - z^2))

@testset "lscf: verdad discreta (H racional exacta en z) con p = 2n" begin
    f = collect(range(0.5, 12.0; length=400)); f0 = 0.5
    dt = 1 / (2 * (f[end] - f0))
    # polos z = e^{(λ − j2πf0)Δt}: el desplazamiento de banda forma parte del modelo
    zi = [exp((lscf_lam(fn, z) - im * 2π * f0) * dt) for (fn, z, r) in LSCF_MODOS]
    zz = cis.(2π .* (f .- f0) .* dt)
    Hd = [sum(c / (zk - zp) + conj(c) / (zk - conj(zp)) for ((fn, z, c), zp) in zip(LSCF_MODOS, zi)) for zk in zz]
    alfa, beta, dt2 = lscf_coeficientes(f, Hd, 6; f0=f0)
    @test dt2 ≈ dt
    fp, zp = lscf_polos(alfa, dt2; f0=f0)
    @test length(fp) == 3
    @test fp ≈ [m[1] for m in LSCF_MODOS] rtol = 1e-9
    @test zp ≈ [m[2] for m in LSCF_MODOS] rtol = 1e-7
end

@testset "lscf: FRF continua (racional en s), orden sobreespecificado" begin
    f = collect(range(0.5, 12.0; length=400)); f0 = 0.5
    Hc = [sum(r / (2π * im * fk - lscf_lam(fn, z)) + conj(r) / (2π * im * fk - conj(lscf_lam(fn, z)))
              for (fn, z, r) in LSCF_MODOS) for fk in f]
    rng = MersenneTwister(7)
    Hr = Hc .* (1 .+ 0.01 .* (randn(rng, length(f)) .+ im .* randn(rng, length(f))))
    cercano(fp, zp, fn) = (j = argmin(abs.(fp .- fn)); (fp[j], zp[j]))
    # con p = 2n la FRF física (racional en s, no en z) solo se aproxima; con p = 10 el error es muy pequeño
    a6, _, d6 = lscf_coeficientes(f, Hc, 6; f0=f0); f6, z6 = lscf_polos(a6, d6; f0=f0)
    @test abs(f6[1] - 3.2) / 3.2 > 5e-3
    for H in (Hc, Hr)
        a, _, d = lscf_coeficientes(f, H, 10; f0=f0); fp, zp = lscf_polos(a, d; f0=f0)
        for (fn, z, r) in LSCF_MODOS
            fe, ze = cercano(fp, zp, fn)
            @test fe ≈ fn rtol = 1e-3
            @test ze ≈ z rtol = 0.05
        end
    end
end

@testset "lscf: la solución reducida coincide con la directa" begin
    f = collect(range(0.0, 10.0; length=300))
    λ = lscf_lam(4.0, 0.03); r = 0.7 - 0.2im
    Hm = [r / (2π * im * fk - λ) + conj(r) / (2π * im * fk - conj(λ)) for fk in f]
    p = 4
    alfa, beta, dt = lscf_coeficientes(f, Hm, p)
    ω = 2π .* f
    X = [cis(ω[k] * dt * rr) for k in eachindex(f), rr in 0:p]
    Y = -(Hm .* ones(1, p + 1)) .* X
    # directa: incógnitas [β; α₀…α_{p-1}] con α_p = 1 (partes real e imaginaria apiladas)
    A = [real(X) real(Y[:, 1:p]); imag(X) imag(Y[:, 1:p])]
    b = -[real(Y[:, p+1]); imag(Y[:, p+1])]
    θ = A \ b
    @test θ[p+2:end] ≈ alfa[1:p] rtol = 1e-6
    @test θ[1:p+1] ≈ beta rtol = 1e-6
end

@testset "lscf: casos límite y estabilidad de polos" begin
    f = collect(range(0.0, 10.0; length=50))
    @test_throws ArgumentError lscf_coeficientes(f, ones(ComplexF64, 50), 0)
    @test_throws ArgumentError lscf_coeficientes(f, ones(ComplexF64, 50), 40)
    @test_throws DimensionMismatch lscf_coeficientes(f, ones(ComplexF64, 49), 2)
    # polos_estables: coincide con el anterior (dentro de tolerancia) y exige amortiguamiento positivo
    @test polos_estables([3.0, 5.0], [0.02, 0.01], [3.01, 5.5, 8.0], [0.021, 0.01, 0.02]) == [true, false, false]
    @test polos_estables([3.0], [0.02], [3.0], [-0.02]) == [false]
end
