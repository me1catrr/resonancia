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

@testset "clasificación: escalado y modelos" begin
    X = [1.0 10.0; 2.0 14.0; 3.0 18.0; 4.0 22.0]
    mu, sigma = ajustar_escala(X)
    Z = escalar(X, mu, sigma)
    @test mu ≈ [2.5, 16.0]
    @test vec(sum(Z, dims=1)) ≈ [0, 0] atol = 1e-12
    @test [sqrt(sum(abs2, Z[:, j]) / 3) for j in 1:2] ≈ [1, 1]
    @test ajustar_escala([1.0 2.0; 1.0 4.0])[2] == [1.0, sqrt(2)]      # columna constante: sigma = 1

    # dos nubes bien separadas, sin azar
    A = [0.0 0.0; 0.2 0.1; 0.1 0.3; 0.3 0.2; 0.25 0.05]
    B = A .+ 3.0
    Xc = vcat(A, B)
    yc = vcat(fill("a", 5), fill("b", 5))
    knn = ajustar_knn(Xc, yc; k=3)
    @test predecir(knn, Xc) == yc
    @test predecir(knn, [0.1 0.1; 3.2 3.1]) == ["a", "b"]
    P = probabilidades(knn, [0.1 0.1; 1.6 1.6])
    @test all(sum(P, dims=2) .≈ 1)
    @test P[1, :] ≈ [1.0, 0.0]
    @test_throws ArgumentError ajustar_knn(Xc, yc; k=0)
    # k = 1 reproduce siempre las etiquetas de entrenamiento
    r = [sin(7i) for i in 1:12, j in 1:2]; yr = [i % 2 for i in 1:12]
    @test predecir(ajustar_knn(r, yr; k=1), r) == yr
    # empate (k=2, un vecino de cada clase): gana la clase más cercana
    kk = ajustar_knn([0.0 0.0; 1.0 0.0], ["a", "b"]; k=2)
    @test predecir(kk, [0.3 0.0; 0.8 0.0]) == ["a", "b"]

    # LDA unidimensional con varianza común: la frontera está en el punto medio de las medias (priors iguales)
    x1 = [-1.2, -1.0, -0.8, -1.1, -0.9]; x2 = x1 .+ 4
    lda = ajustar_lda(reshape(vcat(x1, x2), :, 1), vcat(fill(0, 5), fill(1, 5)))
    @test predecir(lda, reshape([-1.0, 0.9, 1.1, 3.0], :, 1)) == [0, 0, 1, 1]
    @test probabilidades(lda, reshape([1.0], :, 1))[1, :] ≈ [0.5, 0.5] atol = 1e-6
    @test predecir(ajustar_lda(Xc, yc), Xc) == yc

    # logística: en el óptimo (sin penalización) el gradiente Xᵀ(y − p) se anula
    xl = collect(-3.0:0.5:3.0)
    yl = [0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1, 1]            # no separable
    lg = ajustar_logistica(reshape(xl, :, 1), yl; lambda=0.0)
    p1 = probabilidades(lg, reshape(xl, :, 1))[:, 2]
    @test sum(yl .- p1) ≈ 0 atol = 1e-8
    @test sum(xl .* (yl .- p1)) ≈ 0 atol = 1e-8
    @test lg.beta[2] > 0
    @test lg.iteraciones < 20
    # separable + penalización: coeficientes finitos
    ls = ajustar_logistica(reshape(vcat(x1, x2), :, 1), vcat(fill(0, 5), fill(1, 5)))
    @test all(isfinite, ls.beta)
    @test predecir(ls, reshape(vcat(x1, x2), :, 1)) == vcat(fill(0, 5), fill(1, 5))
    @test_throws ArgumentError ajustar_logistica(reshape(xl, :, 1), fill(2, 13))

    # escalado incorporado
    me = ajustar_escalado((Z, y) -> ajustar_knn(Z, y; k=3), Xc .* [1000.0 1.0], yc)
    @test predecir(me, Xc .* [1000.0 1.0]) == yc
end

@testset "clasificación: validación cruzada" begin
    n = 23
    p = pliegues(n, 5; perm=reverse(1:n))
    @test sort(vcat(p...)) == 1:n
    @test extrema(length.(p)) == (4, 5)
    @test p[1] == sort(reverse(1:n)[1:5:n])
    y = vcat(fill(0, 17), fill(1, 6))
    pe = pliegues_estratificados(y, 3)
    @test sort(vcat(pe...)) == 1:n
    @test all(sum(y[f]) == 2 for f in pe)                          # 6 eventos repartidos 2-2-2
    @test_throws ArgumentError pliegues(5, 6)
    @test_throws ArgumentError pliegues(5, 2; perm=[1, 1, 2, 3, 4])

    # cada muestra se predice con un modelo que no la vio: un modelo que devuelve la media de y de entrenamiento
    struct MediaModelo; m::Float64; end
    Resonancia.predecir(m::MediaModelo, X) = fill(m.m, size(X, 1))
    X = reshape(Float64.(1:n), :, 1)
    yv = Float64.(1:n)
    pr = validacion_cruzada((Xt, yt) -> MediaModelo(sum(yt) / length(yt)), X, yv; k=n, estratificada=false)   # dejar uno fuera
    @test pr ≈ [(sum(yv) - v) / (n - 1) for v in yv]

    # datos separables: la validación cruzada acierta todo; con probabilidades devuelve una matriz
    A = [0.0 0.0; 0.2 0.1; 0.1 0.3; 0.3 0.2; 0.25 0.05; 0.05 0.15]
    Xc = vcat(A, A .+ 3.0); yc = vcat(fill(1, 6), fill(2, 6))
    perm = [3, 9, 1, 12, 5, 7, 2, 11, 4, 8, 6, 10]
    @test validacion_cruzada((X, y) -> ajustar_knn(X, y; k=1), Xc, yc; k=3, perm=perm) == yc
    Pp = validacion_cruzada((X, y) -> ajustar_lda(X, y), Xc, yc; k=3, perm=perm, salida=probabilidades)
    @test size(Pp) == (12, 2) && all(sum(Pp, dims=2) .≈ 1)
end

@testset "clasificación: métricas" begin
    real = [1, 1, 1, 1, 1, 1, 2, 2, 2, 2]
    pred = [1, 1, 1, 1, 1, 2, 1, 1, 2, 2]
    C, cl = matriz_confusion(real, pred)
    @test cl == [1, 2]
    @test C == [5 1; 2 2]
    @test exactitud(C) ≈ 0.7
    m = metricas_por_clase(C)
    @test m.precision ≈ [5 / 7, 2 / 3]
    @test m.exhaustividad ≈ [5 / 6, 0.5]
    @test m.f1 ≈ [2 * (5 / 7) * (5 / 6) / (5 / 7 + 5 / 6), 2 * (2 / 3) * 0.5 / (2 / 3 + 0.5)]
    # una clase nunca predicha: precisión 0, sin NaN
    @test all(isfinite, metricas_por_clase([4 0; 3 0]).f1)
    # el clasificador que nunca detecta nada: exactitud alta, exhaustividad nula
    C0, _ = matriz_confusion(vcat(fill(0, 90), fill(1, 10)), fill(0, 100); clases=[0, 1])
    @test exactitud(C0) ≈ 0.9
    @test metricas_por_clase(C0).exhaustividad[2] == 0

    # ROC: ejemplo clásico de cuatro puntuaciones (AUC = 0,75)
    s = [0.1, 0.4, 0.35, 0.8]; yb = [0, 0, 1, 1]
    @test auc_roc(s, yb) ≈ 0.75
    fpr, tpr, um = curva_roc(s, yb)
    @test (fpr[1], tpr[1], fpr[end], tpr[end]) == (0.0, 0.0, 1.0, 1.0)
    @test issorted(fpr) && issorted(tpr)
    @test auc_roc([0.1, 0.2, 0.8, 0.9], yb) == 1.0
    @test auc_roc([0.9, 0.8, 0.2, 0.1], yb) == 0.0
    @test auc_roc(fill(0.5, 4), yb) ≈ 0.5                         # empates: azar
    # AUC = probabilidad de que un positivo puntúe más que un negativo
    sc = [0.2, 0.5, 0.7, 0.3, 0.9, 0.6, 0.4, 0.8]; yy = [0, 0, 1, 0, 1, 1, 0, 0]
    pares = [(a > b) + 0.5 * (a == b) for a in sc[yy .== 1], b in sc[yy .== 0]]
    @test auc_roc(sc, yy) ≈ sum(pares) / length(pares)
    @test_throws ArgumentError curva_roc([0.1, 0.2], [1, 1])
end

@testset "clasificación: características de señales" begin
    fs = 100.0
    t = (0:6000-1) ./ fs
    f0 = 3.037
    x = sin.(2π * f0 .* t) .+ 0.4 .* sin.(2π * 1.213 .* t)
    fm = frecuencias_modales(x, fs, ((0.8, 1.6), (2.5, 3.5)); nseg=1024)
    @test fm ≈ [1.213, 3.037] atol = 0.01                         # mejor que la resolución fs/nseg ≈ 0.098 Hz
    # senoide con periodos enteros: RMS = 1/√2, factor de cresta √2 y curtosis en exceso −1,5
    s = sin.(2π * 5 .* (0:999) ./ 1000)
    c = caracteristicas_evento(s)
    @test c ≈ [log10(1 / sqrt(2)), sqrt(2), -1.5] atol = 1e-9
    # un pico aislado sube el factor de cresta y la curtosis
    z = zeros(1000); z[500] = 1.0
    cz = caracteristicas_evento(z)
    @test cz[2] ≈ sqrt(1000) && cz[3] > 900

    W = caracteristicas_por_ventanas(w -> [sum(w), length(w)], collect(1.0:25.0), 2.0, 5.0)   # ventanas de 10 muestras
    @test W == [55.0 10; 155.0 10]                                 # sobran 5 muestras: se descartan
    @test_throws ArgumentError caracteristicas_por_ventanas(sum∘vcat, [1.0, 2.0], 1.0, 5.0)

    y = respuesta_libre(400, 100.0, 1.0, [2.0], [0.5], 0.02)
    @test all(y[1:100] .== 0)                                      # nada antes del impacto
    tt = 2.5                                                        # muestra 351 → t = 3,5 s − 1 s
    w = 2π * 2.0
    @test y[351] ≈ 0.5 * exp(-0.02 * w * tt) * sin(w * sqrt(1 - 0.02^2) * tt)
    @test maximum(abs, y[101:200]) > maximum(abs, y[301:400])      # decae
    @test_throws ArgumentError respuesta_libre(10, 100.0, 0.0, [1.0, 2.0], [1.0], 0.01)
end

@testset "viga de Euler–Bernoulli" begin
    @test raices_viga(:biapoyada, 3) ≈ [π, 2π, 3π]
    @test raices_viga(:voladizo, 3) ≈ [1.8751040687119611, 4.694091132974175, 7.854757438237613] rtol = 1e-12
    @test raices_viga(:libre_libre, 2) ≈ [4.730040744862704, 7.853204624095838] rtol = 1e-12
    @test raices_viga(:biempotrada, 1) ≈ raices_viga(:libre_libre, 1)
    @test raices_viga(:empotrada_apoyada, 2) ≈ [3.926602312047045, 7.068582745628732] rtol = 1e-11
    @test raices_viga(:voladizo_masa, 1; mu=0.0) ≈ raices_viga(:voladizo, 1)
    @test raices_viga(:voladizo_masa, 1; mu=1.0)[1] ≈ 1.2479 atol = 1e-4
    @test issorted(raices_viga(:voladizo_masa, 5; mu=0.5))
    # las raíces anulan la ecuación y, para n grande, tienden a (n − 1/2)π
    for tipo in (:voladizo, :libre_libre, :empotrada_apoyada)
        r = raices_viga(tipo, 6)
        @test all(abs(ecuacion_viga(tipo, x)) < 1e-12 for x in r)
    end
    @test raices_viga(:voladizo, 8)[8] ≈ 7.5π atol = 1e-6
    @test_throws ArgumentError raices_viga(:otra)
    @test_throws ArgumentError ecuacion_viga(:otra, 1.0)

    # frecuencias de una viga de acero 0,1 m × 0,02 m (flexión en el plano de menor rigidez) de 1 m
    E, rho, L, b, h = 210e9, 7850.0, 1.0, 0.1, 0.02
    A, I = b * h, b * h^3 / 12
    f = frecuencias_viga(:voladizo; E=E, I=I, rho=rho, A=A, L=L, n=3)
    @test f[1] ≈ 1.8751040687^2 / (2π) * sqrt(E * I / (rho * A)) rtol = 1e-9
    @test f[2] / f[1] ≈ (4.694091133 / 1.875104069)^2 rtol = 1e-9
    fb = frecuencias_viga(:biapoyada; E=E, I=I, rho=rho, A=A, L=L, n=3)
    @test fb ≈ fb[1] .* [1, 4, 9]
    # una masa en el extremo baja la frecuencia
    @test frecuencias_viga(:voladizo_masa; E=E, I=I, rho=rho, A=A, L=L, n=1, mu=0.3)[1] < f[1]

    # formas modales: condiciones de contorno del voladizo (φ(0) = φ'(0) = 0, φ''(1) = φ'''(1) = 0)
    for n in 1:3
        bL = raices_viga(:voladizo, 3)[n]
        φ(x) = forma_modal_viga(:voladizo, bL, x)
        h = 1e-3
        @test φ(0.0) == 0
        @test abs((φ(h) - φ(-h)) / (2h)) < 1e-4
        @test abs((φ(1 + h) - 2φ(1) + φ(1 - h)) / h^2) < 1e-3 * bL^2
        @test φ(1.0) ≈ 1
    end
    @test forma_modal_viga(:biapoyada, 2π, 0.25) ≈ 1
    @test_throws ArgumentError forma_modal_viga(:libre_libre, 4.73, 0.5)
end

@testset "sensibilidades y actualización de rigideces" begin
    m = fill(2.0e5, 3)
    k = [5.0e7, 5.0e7, 4.0e7]
    M, K = edificio_cortante(m, k)
    # ∂K/∂kⱼ es exacta porque K es lineal en k
    for j in 1:3
        e = zeros(3); e[j] = 1
        _, K2 = edificio_cortante(m, k .+ 1000 .* e)
        @test (K2 - K) / 1000 ≈ derivada_K_cortante(3, j)
    end
    @test_throws ArgumentError derivada_K_cortante(3, 4)
    # sensibilidad frente a diferencias centrales
    S = jacobiana_frecuencias_cortante(m, k)
    for j in 1:3
        e = zeros(3); e[j] = 1
        fp, _ = modos_propios(edificio_cortante(m, k .+ 1e3 .* e)[2], M)
        fm, _ = modos_propios(edificio_cortante(m, k .- 1e3 .* e)[2], M)
        @test S[:, j] ≈ (fp - fm) ./ 2e3 rtol = 1e-6
    end
    @test all(S .> 0)                                              # más rigidez, más frecuencia
    # homogeneidad: f ∝ √k si todas las rigideces escalan a la vez ⇒ Σⱼ kⱼ ∂f/∂kⱼ = f/2
    f0, _ = modos_propios(K, M)
    @test S * k ≈ f0 ./ 2 rtol = 1e-9
    # sensibilidad respecto de la masa: Σ mᵢ ∂f/∂mᵢ = −f/2 (con dM = I·1 para todas las masas a la vez)
    @test sensibilidad_frecuencias(K, M, zeros(3, 3), Matrix(1.0I, 3, 3)) .* 2e5 ≈ -f0 ./ 2 rtol = 1e-9

    # actualización: recupera una pérdida de rigidez del 10 % en el entrepiso 2 a partir de tres frecuencias
    kreal = [5.0e7, 4.5e7, 4.0e7]
    fobj, _ = modos_propios(edificio_cortante(m, kreal)[2], M)
    kest, hist = actualizar_rigideces(m, k, fobj)
    @test kest ≈ kreal rtol = 1e-8
    @test hist[end] < 1e-10 && hist[1] > 1e-3
    # con una sola frecuencia el problema está indeterminado: la penalización de Tikhonov da una solución acotada
    k1, _ = actualizar_rigideces(m, k, fobj[1:1]; lambda=1e-6)
    @test all(isfinite, k1)
    @test_throws ArgumentError actualizar_rigideces(m, k, [1.0, 2.0, 3.0, 4.0])
end

@testset "raíces: bisección, Newton y secante" begin
    f(x) = x^3 - 2x - 5                                            # raíz real: 2,0945514815423265
    r = 2.0945514815423265
    xb, hb = raiz_biseccion(f, 2.0, 3.0)
    @test xb ≈ r atol = 1e-13
    @test abs(hb[end] - hb[end-1]) < 1e-13 && length(hb) < 60
    # cada iteración de la bisección reduce el intervalo a la mitad: error ≤ (b − a)/2ⁿ
    @test all(abs(hb[n] - r) <= 1.0 / 2^n + 1e-15 for n in 1:30)
    xn, hn = raiz_newton(f, x -> 3x^2 - 2, 2.0)
    @test xn ≈ r atol = 1e-14
    @test length(hn) <= 8
    # orden 2: el error de cada paso es ≈ C·(error anterior)²
    e = abs.(hn .- r)
    C = 3r / (3r^2 - 2)                                            # f''/(2f') en la raíz
    @test e[3] ≈ C * e[2]^2 rtol = 0.05
    @test e[4] ≈ C * e[3]^2 rtol = 0.05
    xs, hs = raiz_secante(f, 2.0, 3.0)
    @test xs ≈ r atol = 1e-13
    @test length(hs) < length(hb)
    # raíz triple: Newton converge, pero solo linealmente (el error se multiplica por 2/3)
    g(x) = (x - 1)^3
    _, hg = raiz_newton(g, x -> 3 * (x - 1)^2, 2.0; tol=1e-12, maxiter=100)
    @test (hg[11] - 1) / (hg[10] - 1) ≈ 2 / 3 atol = 1e-6
    @test_throws ArgumentError raiz_biseccion(f, 3.0, 4.0)
    @test_throws ErrorException raiz_newton(x -> x^2 + 1, x -> 2x, 0.0)
    # raíces de la ecuación característica del voladizo
    @test raiz_biseccion(x -> ecuacion_viga(:voladizo, x), 1.0, 3.0)[1] ≈ raices_viga(:voladizo, 1)[1] atol = 1e-12
end

include("test_optimizacion.jl")
include("test_grafos.jl")
