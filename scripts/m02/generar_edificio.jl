# Genera los registros sintéticos del edificio de cortante de tres plantas (caso transversal de M02).
#   julia --project=. scripts/m02/generar_edificio.jl
# Escenarios (véase Resonancia.edificio_tres_plantas): A referencia, B variabilidad ambiental (-1 % de rigidez),
# C daño (-10 % de rigidez en el entrepiso 2). Excitación ambiental: fuerza de ruido blanco independiente en cada
# planta; sensores: aceleración absoluta de las tres plantas con ruido blanco. Semillas fijas.
using Resonancia, LinearAlgebra, Random, Printf

const FS = 100.0
const DT = 1 / FS
const DURACION = 600.0          # s
const SIGMA_FUERZA = 2.0e4      # N (desviación típica por muestra)
const SIGMA_SENSOR = 0.002      # m/s²
const SEMILLAS = Dict(:A => 20261025, :B => 20261026, :C => 20261027)
const SALIDA = joinpath(@__DIR__, "..", "..", "datos", "sinteticos", "edificio-3-plantas")

"Simula `N` pasos del sistema con fuerza de ruido blanco (retenedor de orden cero) y devuelve la aceleración absoluta."
function simular(escenario, N, semilla)
    M, C, K = edificio_tres_plantas(escenario=escenario)
    A, B = espacio_estados(M, C, K, Matrix(1.0I, 3, 3))
    Ad, Bd = discretizar_zoh(A, B, DT)
    rng = MersenneTwister(semilla)
    Minv = inv(M)
    x = zeros(6)
    acc = zeros(N, 3)
    for k in 1:N
        u = SIGMA_FUERZA .* randn(rng, 3)
        # aceleración instantánea: M a = u - C v - K q, con el estado al comienzo del paso
        acc[k, :] = Minv * (u - C * x[4:6] - K * x[1:3])
        x = Ad * x + Bd * u
    end
    return acc .+ SIGMA_SENSOR .* randn(rng, N, 3)
end

N = Int(DURACION * FS)
mkpath(SALIDA)
for esc in (:A, :B, :C)
    acc = simular(esc, N, SEMILLAS[esc])
    ruta = joinpath(SALIDA, "escenario_$(esc).csv")
    open(ruta, "w") do io
        println(io, "tiempo_s;a1_ms2;a2_ms2;a3_ms2")
        for k in 1:N
            @printf(io, "%.2f;%.6f;%.6f;%.6f\n", (k - 1) * DT, acc[k, 1], acc[k, 2], acc[k, 3])
        end
    end
    println(esc, ": ", filesize(ruta) ÷ 1024, " kB")
end
