using Test
using Resonancia

@testset "fft_radix2" begin
    x = [1.0, 2.0, 0.5, -1.0, 3.0, 0.0, -2.0, 1.5]
    n = length(x)
    dft = [sum(x[j+1] * cis(-2π * k * j / n) for j in 0:n-1) for k in 0:n-1]
    @test fft_radix2(x) ≈ dft
    @test fft_radix2([1.0]) == [1.0 + 0im]
    @test_throws ArgumentError fft_radix2(zeros(6))
end

@testset "psd_welch" begin
    fs = 100.0
    t = (0:fs*60-1) ./ fs
    f0, A = 5.0, 2.0
    x = A .* sin.(2π * f0 .* t)
    f, P = psd_welch(x, fs; nseg=1024)
    @test f[argmax(P)] ≈ f0 atol = fs / 1024
    # Parseval: la potencia total es la varianza (A²/2 para una senoide)
    @test sum(P) * (f[2] - f[1]) ≈ A^2 / 2 rtol = 0.02
    # ruido blanco de varianza 1: PSD plana ≈ 2/fs (unilateral)
    estado = UInt32(12345)  # LCG con semilla fija: ruido casi gaussiano de varianza 1
    uniforme() = (estado = estado * UInt32(1664525) + UInt32(1013904223); Float64(estado) / 2^32)
    r = [sum(uniforme() for _ in 1:12) - 6 for _ in 1:200_000]
    f, P = psd_welch(r, fs; nseg=1024)
    @test sum(P) * (f[2] - f[1]) ≈ 1 rtol = 0.03
    @test_throws ArgumentError psd_welch(zeros(10), fs; nseg=1024)
end

@testset "buscar_picos" begin
    f = collect(0.0:0.1:10.0)
    P = zeros(length(f))
    P[21], P[51], P[81] = 3.0, 5.0, 1.0   # 2,0 · 5,0 · 8,0 Hz
    @test f[buscar_picos(f, P; n=2)] ≈ [2.0, 5.0]
    @test f[buscar_picos(f, P; fmin=3, n=5)] ≈ [5.0, 8.0]
end

@testset "rms_por_ventana" begin
    fs = 10.0
    x = vcat(fill(1.0, 20), fill(3.0, 20))
    t, r = rms_por_ventana(x, fs, 2.0)
    @test r ≈ [1.0, 3.0]
    @test t ≈ [1.0, 3.0]
end

@testset "lectura" begin
    mktempdir() do d
        p = joinpath(d, "s.txt")
        write(p, """
        Station_code    GS9
        Sampling_rate   100.0000
        Start_date      22.06.2018
        Time   X0HNE,g    Y0HNN,g    Z0HNZ,g
        07:40:00.000   1.0e-003  2.0e-003  -3.0e-003
        07:40:00.010   4.0e-003  5.0e-003  -6.0e-003
        """)
        t, a, fs, est, ini = leer_torroja(p)
        @test t ≈ [0.0, 0.01]
        @test a ≈ [1e-3 2e-3 -3e-3; 4e-3 5e-3 -6e-3]
        @test (fs, est, ini) == (100.0, "GS9", "07:40:00.000")

        q = joinpath(d, "c.csv")
        write(q, "tiempo_s;aceleracion_g\n0.000000000;0.5\n0.001953125;-0.25\n0.003906250;0.125\n")
        t, a, fs = leer_aceleracion_csv(q)
        @test a == [0.5, -0.25, 0.125]
        @test fs ≈ 512.0
        t, a, _ = leer_aceleracion_csv(q; hasta=0.003)
        @test length(a) == 2
        write(q, "otra;cosa\n1;2\n")
        @test_throws ArgumentError leer_aceleracion_csv(q)
    end
end
