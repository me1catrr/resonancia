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

using LinearAlgebra, SparseArrays

@testset "Toeplitz, Hankel y circulantes: definición" begin
    @test toeplitz([1, 2, 3], [1, 5, 6]) == [1 5 6; 2 1 5; 3 2 1]
    @test toeplitz([1, 2, 3]) == [1 2 3; 2 1 2; 3 2 1]
    @test_throws ArgumentError toeplitz([1, 2], [9, 3])
    @test hankel([1, 2, 3], [3, 4, 5]) == [1 2 3; 2 3 4; 3 4 5]
    @test hankel([1, 2, 3]) == [1 2 3; 2 3 0; 3 0 0]
    @test_throws ArgumentError hankel([1, 2, 3], [9, 4, 5])
    @test hankel_trayectoria(1:5, 3) == [1 2 3; 2 3 4; 3 4 5]
    @test hankel_trayectoria(1:5, 2) == [1 2 3 4; 2 3 4 5]
    @test_throws ArgumentError hankel_trayectoria(1:5, 6)
    @test circulante([1, 2, 3]) == [1 3 2; 2 1 3; 3 2 1]
    @test vandermonde([1, 2, 3]) == [1 1 1; 1 2 4; 1 3 9]
end

@testset "promediado antidiagonal y SSA" begin
    x = [1.0, 2.0, 3.0, 4.0, 5.0]
    @test promedio_antidiagonal(hankel_trayectoria(x, 3)) ≈ x     # una matriz de Hankel se reproduce
    @test promedio_antidiagonal([1.0 2.0; 3.0 4.0]) ≈ [1.0, 2.5, 4.0]
    fs = 100.0
    t = (0:199) ./ fs
    s1 = sin.(2π * 5 .* t)
    rec, S = ssa(s1, 50, 2)
    @test maximum(abs, rec .- s1) < 1e-10                          # sinusoide: rango 2
    @test count(>(1e-8 * S[1]), S) == 2
    s2 = s1 .+ 0.5 .* sin.(2π * 12 .* t)
    _, S2 = ssa(s2, 50, 4)
    @test count(>(1e-8 * S2[1]), S2) == 4                          # dos sinusoides: rango 4
    @test_throws ArgumentError ssa(s1, 50, 0)
end

@testset "convolución circular y circulantes" begin
    a = [1.0, 2.0, 0.0, -1.0, 3.0, 0.5, 0.0, 1.0]
    b = [0.5, -1.0, 2.0, 0.0, 1.0, 1.0, -2.0, 0.0]
    @test conv_circular(a, b) ≈ circulante(a) * b
    @test conv_circular_fft(a, b) ≈ conv_circular(a, b)
    @test ifft_radix2(fft_radix2(a)) ≈ a
    # los valores propios de una circulante son la DFT de su primera columna
    @test sort(abs.(eigvals(circulante(a)))) ≈ sort(abs.(fft_radix2(a))) atol = 1e-10
    # lineal frente a circular: con ceros suficientes coinciden (z-padding)
    x = [1.0, 2.0, 3.0]; h = [1.0, -1.0]
    lineal = [sum(x[j] * h[k-j+1] for j in max(1, k - 1):min(3, k)) for k in 1:4]
    @test conv_circular(vcat(x, 0.0), vcat(h, 0.0, 0.0)) ≈ lineal
    @test conv_circular(x, vcat(h, 0.0)) ≉ lineal[1:3]
end

@testset "autocorrelación y Yule–Walker" begin
    # AR(1) con autocorrelación teórica r_k = σ² φ^k / (1-φ²)
    phi, sigma2 = 0.7, 2.0
    r = [sigma2 * phi^k / (1 - phi^2) for k in 0:5]
    p, s2 = yule_walker(r, 1)
    @test p ≈ [phi]
    @test s2 ≈ sigma2
    p2, _ = yule_walker(r, 2)
    @test p2 ≈ [phi, 0.0] atol = 1e-12                             # un AR(1) visto como AR(2)
    @test minimum(eigvals(toeplitz(r))) > 0
    @test_throws ArgumentError yule_walker(r[1:2], 2)
    # autocorrelación muestral de una sinusoide: r_k ≈ (A²/2) cos(2π f k/fs) para N grande
    fs = 100.0; N = 20_000
    x = sin.(2π * 5 .* (0:N-1) ./ fs)
    rk = autocorrelacion(x, 10)
    @test rk[1] ≈ 0.5 atol = 1e-3
    @test rk[11] ≈ 0.5cos(2π * 5 * 10 / fs) atol = 5e-3
    @test_throws ArgumentError autocorrelacion(x, N)
    # la matriz de autocorrelación sesgada es semidefinida positiva
    z = [0.3, -1.2, 0.8, 0.1, -0.4, 1.5, -0.9, 0.2]
    @test minimum(eigvals(Symmetric(toeplitz(autocorrelacion(z, 5))))) > -1e-12
end

@testset "cadena de masas y muelles, edificio de cortante y modos" begin
    M, K = cadena_masas_muelles(2; m=1.0, k=1.0)
    @test M isa SparseMatrixCSC && K isa SparseMatrixCSC
    @test Matrix(K) == [2.0 -1.0; -1.0 1.0]
    f, Phi = modos_propios(K, M)
    @test (2π .* f) .^ 2 ≈ [(3 - √5) / 2, (3 + √5) / 2]            # ω² analíticos
    @test Phi' * M * Phi ≈ I atol = 1e-12
    @test Matrix(K) * Phi ≈ Matrix(M) * Phi * Diagonal((2π .* f) .^ 2) atol = 1e-10
    # n masas iguales, empotrada-libre: ω_j² = 2 (k/m) [1 - cos((2j-1)π/(2n+1))]
    n = 3; m0 = 2.0; k0 = 5.0
    Mc, Kc = cadena_masas_muelles(n; m=m0, k=k0)
    fc, _ = modos_propios(Kc, Mc)
    @test (2π .* fc) .^ 2 ≈ [2 * k0 / m0 * (1 - cos((2j - 1) * π / (2n + 1))) for j in 1:n]
    # el edificio de cortante con valores iguales es la misma cadena
    Me, Ke = edificio_cortante(fill(m0, n), fill(k0, n))
    @test Ke ≈ Matrix(Kc)
    @test Me ≈ Matrix(Mc)
    # patrón tridiagonal disperso: 3n-2 elementos no nulos
    _, K100 = cadena_masas_muelles(100)
    @test nnz(K100) == 3 * 100 - 2
    @test_throws ArgumentError edificio_cortante([1.0, 2.0], [1.0])
end

@testset "MAC" begin
    φ1 = [1.0, 2.0, 3.0]
    @test mac(φ1, φ1) ≈ 1
    @test mac(φ1, -4.2 .* φ1) ≈ 1                                  # independiente de escala y signo
    @test mac([1.0, 0.0], [0.0, 1.0]) == 0
    @test 0 < mac([1.0, 2.0, 3.0], [1.0, 2.5, 2.0]) < 1
end

@testset "ERA: recupera frecuencias y amortiguamientos de un sistema conocido" begin
    # dos osciladores desacoplados (f = 2 y 5 Hz; ζ = 0,02 y 0,05) observados con C = [1 0 1 0]
    dt = 0.01
    sistema(f, z) = (ω = 2π * f; [0.0 1.0; -ω^2 -2z * ω])
    A = [sistema(2.0, 0.02) zeros(2, 2); zeros(2, 2) sistema(5.0, 0.05)]
    B = [0.0, 1.0, 0.0, 1.0]
    C = [1.0 0.0 1.0 0.0]
    Ad = exp(A * dt)
    Bd = A \ ((Ad - I) * B)
    h = [(C * Ad^(k - 1) * Bd)[1] for k in 1:80]
    f, z = era(h, 4, dt)
    @test f ≈ [2.0, 5.0] atol = 1e-8
    @test z ≈ [0.02, 0.05] atol = 1e-8
    @test_throws ArgumentError era(h[1:6], 4, dt)
end

@testset "Levinson–Durbin" begin
    phi_ar, s2_ar = 0.7, 2.0
    r = [s2_ar * phi_ar^k / (1 - phi_ar^2) for k in 0:6]
    phi, s2, kappa = levinson_durbin(r, 1)
    @test phi ≈ [phi_ar]
    @test s2 ≈ s2_ar
    @test kappa ≈ [phi_ar]
    # coincide con Yule–Walker para un AR(3) arbitrario y su autocorrelación muestral
    z = [0.3, -1.2, 0.8, 0.1, -0.4, 1.5, -0.9, 0.2, 0.6, -0.7, 1.1, -0.3]
    rz = autocorrelacion(z, 6)
    pw, sw = yule_walker(rz, 3)
    pl, sl, kl = levinson_durbin(rz, 3)
    @test pl ≈ pw
    @test sl ≈ sw
    @test all(abs.(kl) .< 1)                                       # matriz definida positiva
    @test_throws ArgumentError levinson_durbin(r[1:2], 3)
end

@testset "observabilidad, controlabilidad y matriz MAC" begin
    # cadena empotrada-empotrada de 3 masas (k = m = 1), sin amortiguamiento
    K = [2.0 -1.0 0.0; -1.0 2.0 -1.0; 0.0 -1.0 2.0]
    A = [zeros(3, 3) I(3); -K zeros(3, 3)]
    C_centro = [0.0 1.0 0.0 0.0 0.0 0.0]       # sensor de desplazamiento en la masa central
    C_extremo = [1.0 0.0 0.0 0.0 0.0 0.0]      # sensor en la primera masa
    @test rank(matriz_observabilidad(A, C_centro)) == 4            # el modo antisimétrico tiene un nodo en el centro
    @test rank(matriz_observabilidad(A, C_extremo)) == 6
    B_centro = [0.0, 0.0, 0.0, 0.0, 1.0, 0.0]  # fuerza en la masa central
    @test rank(matriz_controlabilidad(A, reshape(B_centro, :, 1))) == 4
    @test size(matriz_observabilidad(A, C_extremo)) == (6, 6)
    M3, K3 = cadena_masas_muelles(3)
    _, Phi = modos_propios(K3, M3)
    @test matriz_mac(Phi, Phi) ≈ I atol = 1e-12                    # los modos de una matriz simétrica son ortogonales
    @test matriz_mac(Phi, Phi[:, [2, 1, 3]])[1, 2] ≈ 1
end

@testset "Rayleigh, amortiguamiento proporcional y polos" begin
    M, C, K = edificio_tres_plantas()
    f, Phi = modos_propios(K, M)
    @test cociente_rayleigh(K, M, Phi[:, 2]) ≈ (2π * f[2])^2
    x = [1.0, 2.0, 3.0]
    @test (2π * f[1])^2 - 1e-6 <= cociente_rayleigh(K, M, x) <= (2π * f[3])^2 + 1e-6
    A, _ = espacio_estados(M, C, K, [0.0, 0.0, 1.0])
    fp, zp = polos_modales(A)
    @test fp ≈ f rtol = 1e-3
    @test zp[1:2] ≈ [0.01, 0.01] atol = 1e-6                        # los dos fijados
    @test 0.005 < zp[3] < 0.02                                      # el tercero queda fijado por α y β
    @test_throws ArgumentError edificio_tres_plantas(escenario=:Z)
end

@testset "exponencial matricial y discretización exacta" begin
    A = [0.0 1.0; -4.0 -0.4]
    @test expm(A) ≈ exp(A) rtol = 1e-12
    @test expm(zeros(3, 3)) ≈ I
    @test expm([0.0 50.0; -50.0 0.0]) ≈ exp([0.0 50.0; -50.0 0.0]) rtol = 1e-10
    B = reshape([0.0, 1.0], 2, 1)
    Ad, Bd = discretizar_zoh(A, B, 0.05)
    @test Ad ≈ exp(A * 0.05)
    @test Bd ≈ A \ (Ad - I) * B                                     # A invertible: Bd = A⁻¹(Ad − I)B
    # A singular (integrador): x' = u → Ad = 1, Bd = dt
    Ai, Bi = discretizar_zoh(zeros(1, 1), ones(1, 1), 0.3)
    @test Ai ≈ ones(1, 1) && Bi ≈ fill(0.3, 1, 1)
    # los polos discretos son z = e^{s dt}
    z = eigvals(Ad)
    @test sort(abs.(z)) ≈ sort(abs.(exp.(eigvals(A) .* 0.05)))
end

@testset "pseudoinversa y rango numérico" begin
    A = [1.0 2.0; 2.0 4.0; 3.0 6.0]                                # rango 1
    @test rango_numerico(A) == 1
    P = pseudoinversa_svd(A)
    @test A * P * A ≈ A
    @test P * A * P ≈ P
    @test pseudoinversa_svd([2.0 0.0; 0.0 4.0]) ≈ [0.5 0.0; 0.0 0.25]
    B = [3.0 1.0; 1.0 2.0; 0.0 1.0]
    @test pseudoinversa_svd(B) ≈ pinv(B)
    @test pseudoinversa_svd(B; tol=1.0) != pinv(B)                  # con tolerancia alta se trunca
end

@testset "polos de un modelo AR" begin
    # AR(2) de un oscilador discreto: z = ρ e^{±jθ}  ⇒  phi = (2ρcosθ, -ρ²)
    dt = 0.05
    f0, z0 = 2.0, 0.03
    s0 = -z0 * 2π * f0 + 1im * 2π * f0 * sqrt(1 - z0^2)
    z = exp(s0 * dt)
    phi = [2 * real(z), -abs2(z)]
    f, zeta = polos_ar(phi, dt)
    @test f ≈ [f0] atol = 1e-10
    @test zeta ≈ [z0] atol = 1e-10
    # a la frecuencia de Nyquist o por encima se pliega: 2 Hz y 18 Hz con dt = 0.05 (fs = 20 Hz) dan el mismo polo
    @test exp(1im * 2π * 18 * dt) ≈ exp(1im * 2π * (-2) * dt)
    @test length(polos_ar([0.5], dt)[1]) == 0                  # un polo real no da oscilación
end

@testset "ventanas y Hilbert" begin
    @test ventana(:rectangular, 8) == ones(8)
    w = ventana(:hann, 64)
    @test ganancia_coherente(w) ≈ 0.5
    @test ancho_banda_ruido(w) ≈ 1.5 rtol = 1e-12
    @test ancho_banda_ruido(ventana(:rectangular, 64)) ≈ 1
    @test ganancia_coherente(ventana(:flattop, 128)) ≈ 0.21557895 atol = 1e-8
    @test_throws ArgumentError ventana(:xx, 4)
    # Hilbert de un coseno entero de periodos es el seno; envolvente 1; frecuencia instantánea constante
    N = 256; t = (0:N-1) ./ N
    x = cos.(2π * 8 .* t)
    z = hilbert_analitica(x)
    @test real.(z) ≈ x atol = 1e-12
    @test imag.(z) ≈ sin.(2π * 8 .* t) atol = 1e-12
    @test abs.(z) ≈ ones(N) atol = 1e-12
    ph = fase_instantanea(z)
    @test (ph[end] - ph[1]) / (N - 1) * N / (2π) ≈ 8 rtol = 1e-3
    @test_throws ArgumentError hilbert_analitica(ones(6))
end

@testset "correlación cruzada y autocorrelación por FFT" begin
    x = [0.3, -1.2, 0.8, 0.1, -0.4, 1.5, -0.9, 0.2, 0.6, -0.7, 1.1, -0.3]
    @test autocorrelacion_fft(x, 6) ≈ autocorrelacion(x, 6)
    c = correlacion_cruzada(x, x, 4)
    @test c[5:end] ≈ autocorrelacion(x, 4)
    @test c ≈ reverse(c)                                           # la autocorrelación es par
    y = circshift(x, 3)
    cc = correlacion_cruzada(x, y, 6)
    @test argmax(cc) - 7 == 3                                      # y va retrasada 3 muestras
    @test_throws ArgumentError correlacion_cruzada(x, x[1:5], 2)
end

@testset "frecuencia_pico_por_segmentos" begin
    fs = 100.0
    t = (0:11999) ./ fs
    x = sin.(2π * 4.4 .* t) .+ 0.3 .* sin.(2π * 1.1 .* t)
    f = frecuencia_pico_por_segmentos(x, fs; seg=6000, banda=(3.8, 5.0))
    @test length(f) == 2
    @test all(abs.(f .- 4.4) .<= fs / 2048)                       # dentro de la resolución
    f1 = frecuencia_pico_por_segmentos(x, fs; seg=6000, banda=(0.8, 1.5))
    @test all(abs.(f1 .- 1.1) .<= fs / 2048)
    @test length(frecuencia_pico_por_segmentos(x[1:11000], fs; seg=6000, banda=(3.8, 5.0))) == 1   # el resto se descarta
    @test_throws ArgumentError frecuencia_pico_por_segmentos(x, fs; seg=1000, banda=(3.8, 5.0))
    @test_throws ArgumentError frecuencia_pico_por_segmentos(x[1:3000], fs; seg=6000, banda=(3.8, 5.0))
end
