# Pruebas de src/optimizacion.jl (J3.7). Las incluye runtests.jl dentro de su `using Test` y `using Resonancia`.

@testset "frf_1gdl" begin
    f0, z, A = 2.5, 0.02, 3.0
    @test frf_1gdl(0.0, f0, z, A) ≈ A                                  # límite estático
    H = frf_1gdl(f0, f0, z, A)                                         # en resonancia: A / (2 i ζ)
    @test abs(H) ≈ A / (2z)
    @test angle(H) ≈ -π / 2
    @test frf_1gdl(10 * f0, f0, z, A) ≈ -A / 99 atol = 1e-3          # a frecuencias altas domina la masa: ≈ -A/r²
    @test frf_1gdl(1.0, f0, z) == frf_1gdl(1.0, f0, z, 1.0)
    f = collect(1.0:0.5:4.0)
    y = frf_1gdl_ri(f, [f0, z, A])
    @test length(y) == 2 * length(f)
    @test y[1:length(f)] ≈ real.(frf_1gdl.(f, f0, z, A))
    @test y[length(f)+1:end] ≈ imag.(frf_1gdl.(f, f0, z, A))
    @test_throws ArgumentError frf_1gdl_ri(f, [f0, z])
end

@testset "psd_modal_1gdl" begin
    f = collect(0.5:0.001:5.0)
    S = psd_modal_1gdl(f, [2.0, 0.01, 4.0, 0.1])
    @test f[argmax(S)] ≈ 2.0 atol = 0.01
    @test psd_modal_1gdl([2.0], [2.0, 0.01, 4.0, 0.1])[1] ≈ 4.0 / (4 * 0.01^2) + 0.1      # S0/(4ζ²) + suelo
    @test all(S .>= 0.1)
    @test_throws ArgumentError psd_modal_1gdl(f, [2.0, 0.01, 4.0])
end

@testset "frecuencias_cortante" begin
    f = frecuencias_cortante([1.0, 1.0, 1.0])
    @test f ≈ [1.1048, 2.9387, 4.3902] atol = 1e-4
    M, K = edificio_cortante(fill(2.0e5, 3), [5.0e7, 5.0e7, 4.0e7])
    @test f ≈ modos_propios(K, M)[1]
    # frecuencias ∝ √rigidez: multiplicar las tres rigideces por c multiplica las frecuencias por √c
    @test frecuencias_cortante(fill(1.21, 3)) ≈ 1.1 .* f
    # una rigidez menor baja todas las frecuencias
    @test all(frecuencias_cortante([1.0, 0.9, 1.0]) .< f)
    @test issorted(frecuencias_cortante([0.8, 1.3, 0.6]))
    @test_throws DomainError frecuencias_cortante([1.0, -0.1, 1.0])
    @test_throws ArgumentError frecuencias_cortante([1.0, 1.0])
end

@testset "residuos y coste de frecuencias" begin
    th = [1.0, 0.9, 1.0]
    fm = frecuencias_cortante(th)
    @test residuos_frecuencias(th, fm) ≈ zeros(3) atol = 1e-12
    @test coste_frecuencias(th, fm) < 1e-20
    @test coste_frecuencias([1.0, 1.0, 1.0], fm) > 1e-4
    # varias medidas: una columna por medida, el resultado apila las columnas
    F = hcat(fm, 1.01 .* fm)
    r = residuos_frecuencias(th, F)
    @test length(r) == 6
    @test r[1:3] ≈ zeros(3) atol = 1e-12
    @test r[4:6] ≈ fill(1 / 1.01 - 1, 3)
    @test coste_frecuencias(th, F) ≈ sum(abs2, r)
    @test_throws ArgumentError residuos_frecuencias(th, [1.0, 2.0])
    # identificabilidad: Gauss–Newton con jacobiano por diferencias finitas recupera theta desde 3 frecuencias
    x = [1.0, 1.0, 1.0]
    for _ in 1:20
        r0 = residuos_frecuencias(x, fm)
        J = hcat([(residuos_frecuencias(x .+ 1e-6 .* (1:3 .== j), fm) .- r0) ./ 1e-6 for j in 1:3]...)
        x = x .- J \ r0
    end
    @test x ≈ th atol = 1e-6
end

@testset "puntos_iniciales" begin
    P = puntos_iniciales([0.0, 10.0], [1.0, 20.0], 5)
    @test length(P) == 5
    @test P[1] ≈ [0.5, 10 + 10 / 3]            # primeros elementos de Halton: 1/2 (base 2) y 1/3 (base 3)
    @test P[2] ≈ [0.25, 10 + 20 / 3]
    @test P[3] ≈ [0.75, 10 + 10 / 9]
    @test all(p -> all(0.0 .<= p .<= [1.0, 20.0]) && p[2] >= 10.0, P)
    @test puntos_iniciales([0.0], [1.0], 3) == puntos_iniciales([0.0], [1.0], 3)   # reproducible
    @test length(unique(puntos_iniciales([0.0], [1.0], 50))) == 50                 # sin repeticiones
    @test_throws ArgumentError puntos_iniciales([0.0, 0.0], [1.0], 3)
    @test_throws ArgumentError puntos_iniciales([2.0], [1.0], 3)
end
