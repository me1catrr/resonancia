# Pruebas de src/semiespectro.jl (M7.1 y M7.9). Las incluye runtests.jl.
using LinearAlgebra, Random, Statistics

@testset "semiespectro: definición y relación con la PSD" begin
    rng = MersenneTwister(8)
    x = randn(rng, 200000)
    f = [0.0, 5.0, 12.5, 24.0]
    S = semiespectro(x, 50.0, f; L=50)
    # ruido blanco de varianza 1 a 50 Hz: PSD unilateral = 2/fs, y Re S⁺ = S/2 = PSD_unilateral/4
    @test 4 .* real.(S) ≈ fill(2 / 50, 4) rtol = 0.1
    # coincide con la definición explícita
    r = autocorrelacion(x, 50)
    dt = 1 / 50
    ref(fk) = dt * (r[1] / 2 + sum(r[j+1] * cis(-2π * fk * j * dt) for j in 1:50))
    @test S ≈ ref.(f)
    # con ventana exponencial, cada retardo se pondera por exp(-jΔt/τ)
    Se = semiespectro(x, 50.0, f; L=50, tau=2.0)
    ref_e(fk) = dt * (r[1] / 2 + sum(exp(-j * dt / 2.0) * r[j+1] * cis(-2π * fk * j * dt) for j in 1:50))
    @test Se ≈ ref_e.(f)
    @test_throws ArgumentError semiespectro(x[1:30], 50.0, f; L=50)
end

@testset "ventana exponencial: el amortiguamiento estimado excede en 1/(τω) y se corrige" begin
    fn0, ζ0, fs = 3.7, 0.012, 50.0
    rng = MersenneTwister(5)
    y = vec(respuesta_modal(ones(1, 1), [fn0], [ζ0], randn(rng, 90000, 1), fs))
    f = collect(range(2.7, 4.7; length=300))
    for tau in (20.0, 8.0, 4.0)
        S = semiespectro(y, fs, f; L=1500, tau=tau)
        a, _, dt = lscf_coeficientes(f, S, 8; f0=f[1])
        fp, zp = lscf_polos(a, dt; f0=f[1])
        j = argmin(abs.(fp .- fn0))
        esperado = ζ0 + 1 / (tau * 2π * fn0)
        @test fp[j] ≈ fn0 rtol = 0.005
        @test zp[j] ≈ esperado atol = 0.0015                      # 0,15 puntos porcentuales
        @test corregir_amortiguamiento_exponencial(zp[j], fp[j], tau) ≈ ζ0 atol = 0.0015
    end
    @test corregir_amortiguamiento_exponencial(0.03, 2.0, 5.0) ≈ 0.03 - 1 / (5.0 * 2π * 2.0)
end
