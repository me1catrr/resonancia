using Test, DataFrames
include("analisis.jl")
include("excel.jl")

@testset "caso A: validación y totales" begin
    a = cargar("a_ventas.csv"; dateformat = "yyyy-mm-dd")
    @test validar_ventas(a) == (filas = 109, duplicadas = 1, ausentes = 5)
    t = ventas_por_region(a)
    @test sort(t.region) == ["Centro", "Norte", "Sur"]
    d = Dict(t.region .=> t.total_eur)
    @test d["Norte"] ≈ 1911061.69 atol = 0.01
    @test d["Centro"] ≈ 2539781.72 atol = 0.01
    @test d["Sur"] ≈ 1619001.97 atol = 0.01
    @test sum(t.total_eur) ≈ 6069845.38 atol = 0.01
end

@testset "caso B: fechas mixtas" begin
    b = cargar("b_absentismo.csv"; types = Dict(:fecha => String))
    @test count(s -> occursin('/', s), b.fecha) == 21
    @test count(ismissing, parsear_fecha.(b.fecha)) == 0
    @test parsear_fecha("05/03/2025") == Date(2025, 3, 5)
    @test parsear_fecha("2025-03-05") == Date(2025, 3, 5)
    @test ismissing(parsear_fecha("ayer"))
    @test sum(b.dias_ausencia) == 814
end

@testset "caso C y D" begin
    c = cargar("c_mantenimiento.csv")
    r = resumen_mantenimiento(c)
    @test Dict(r.tipo .=> r.ordenes) == Dict("correctivo" => 50, "preventivo" => 130)
    @test count(ismissing, c.coste_eur) == 3
    @test huecos(cargar("d_ambiental.csv").temperatura_C) == [(601, 613)]
    @test huecos([1, missing, missing, 4, missing]) == [(2, 3), (5, 5)]
end

@testset "caso E: FFT propia y espectro" begin
    x = randn(64)
    ref = [sum(x[k] * cis(-2π * (m - 1) * (k - 1) / 64) for k in 1:64) for m in 1:64]   # DFT directa
    @test fft2(x) ≈ ref
    @test_throws ArgumentError fft2(randn(10))
    t = (0:4095) ./ 200
    f, A = espectro(2.0 .* sin.(2π * 12.5 .* t), 200.0)
    @test f[argmax(A)] ≈ 12.5
    @test maximum(A) ≈ 2.0 rtol = 0.01
end

@testset "Excel de ida y vuelta" begin
    mktempdir() do dir
        ruta = escribir_libro(joinpath(dir, "v.xlsx"), cargar("a_ventas.csv"; dateformat = "yyyy-mm-dd"))
        @test XLSX.sheetnames(XLSX.readxlsx(ruta)) == ["resumen", "validacion"]
        @test nrow(leer_hoja(ruta, "resumen")) == 3
        @test leer_hoja(ruta, "validacion").ausentes == [5]
    end
end
