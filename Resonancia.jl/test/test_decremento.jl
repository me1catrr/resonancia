# Pruebas de src/decremento.jl y de las ventanas del ensayo de impacto (M4.1 y M7.4). Las incluye runtests.jl.
using Random, Statistics

@testset "ventana exponencial, amortiguamiento añadido y ventana de fuerza" begin
    w = ventana_exponencial(64, 100.0, 0.5)
    @test w[1] == 1.0
    @test w[end] ≈ exp(-0.63 / 0.5)
    @test issorted(w; rev=true)
    # σ₀ = −ln w(T) / T: con w(T)=0,10 y T=0,64 s sale 3,598 rad/s (0,573 Hz); τ = 1/σ₀
    σ0 = amortiguamiento_ventana_exponencial(0.10, 0.64)
    @test σ0 ≈ 3.5978 atol = 1e-3
    @test σ0 / 2π ≈ 0.5726 atol = 1e-3
    @test amortiguamiento_ventana_exponencial(exp(-1), 0.1) ≈ 10.0     # τ = 0,1 s ⇒ σ₀ = 10 rad/s
    # la ventana y la fórmula son coherentes: el valor final de la ventana de N muestras (T = N/fs)
    N, fs, tau = 640, 1000.0, 0.25
    @test amortiguamiento_ventana_exponencial(exp(-N / fs / tau), N / fs) ≈ 1 / tau
    @test_throws ArgumentError amortiguamiento_ventana_exponencial(1.2, 1.0)
    @test_throws ArgumentError amortiguamiento_ventana_exponencial(0.5, -1.0)
    @test_throws ArgumentError ventana_exponencial(0, 100.0, 1.0)
    @test_throws ArgumentError ventana_exponencial(10, 100.0, -1.0)
    @test ventana_fuerza(8, 3, 2) == [0, 0, 1, 1, 0, 0, 0, 0]
    @test_throws ArgumentError ventana_fuerza(8, 7, 3)
    @test_throws ArgumentError ventana_fuerza(8, 0, 2)
end

@testset "decremento aleatorio: la firma tiende a la correlación o a su derivada" begin
    fn, ζ, fs = 3.0, 0.02, 50.0
    rng = MersenneTwister(11)
    x = vec(respuesta_modal(ones(1, 1), [fn], [ζ], randn(rng, 200_000, 1), fs))
    nlag = 150
    r = autocorrelacion(x, nlag + 1)
    σ, σv = std(x), std(diff(x) .* fs)
    dr = [(r[j+2] - r[j]) * fs / 2 for j in 1:nlag]          # Ṙ en los retardos 1, …, nlag (diferencia central)
    # condiciones que dan R(τ)
    rd = decremento_aleatorio(x, x, nlag; condicion=:punto_positivo, a=σ, fs=fs)
    @test cor(rd.d, r[1:nlag+1]) > 0.99
    @test rd.t[end] ≈ nlag / fs
    @test rd.disparos == count(>(σ), x[2:end-nlag]) 
    rd = decremento_aleatorio(x, x, nlag; condicion=:nivel, a=σ, fs=fs)
    @test cor(rd.d, r[1:nlag+1]) > 0.95
    # a nivel 0 la firma no tiene señal (D ∝ a)
    @test maximum(abs, decremento_aleatorio(x, x, nlag; condicion=:nivel, a=0.0).d) < 0.05σ
    # condiciones que dan −Ṙ(τ) (convención R(τ) = E[x(t+τ)y(t)])
    rd = decremento_aleatorio(x, x, nlag; condicion=:velocidad_positiva, v=σv, fs=fs)
    @test cor(rd.d[2:end], -dr) > 0.95
    rd = decremento_aleatorio(x, x, nlag; condicion=:velocidad, v=σv, fs=fs)
    @test cor(rd.d[2:end], -dr) > 0.9
    # firma cruzada: se promedia x cuando dispara y (y = x desfasada no cambia el número de disparos)
    rd = decremento_aleatorio(x, x, 10; condicion=:punto_positivo, a=0.0)
    @test length(rd.d) == 11 && rd.disparos > 0
    @test_throws ArgumentError decremento_aleatorio(x, x, nlag; condicion=:nivel, a=100σ)
    @test_throws ArgumentError decremento_aleatorio(x, x, nlag; condicion=:otra)
    @test_throws ArgumentError decremento_aleatorio(x, x, length(x))
    @test_throws DimensionMismatch decremento_aleatorio(x, x[1:end-1], 10)
end

@testset "correlación insesgada frente a la sesgada" begin
    rng = MersenneTwister(3)
    x = randn(rng, 5000)
    N, kmax = length(x), 200
    rs, ri = autocorrelacion(x, kmax), correlacion_insesgada(x, kmax)
    # mismas sumas: la sesgada es la insesgada por (N−k)/N
    @test rs ≈ ri .* ((N .- (0:kmax)) ./ N)
    @test ri[1] == rs[1]
    @test_throws ArgumentError correlacion_insesgada(x, N)
end
