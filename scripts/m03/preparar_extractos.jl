#!/usr/bin/env julia
# =============================================================================
# preparar_extractos.jl: extracto del puente de Torroja para los laboratorios
# interactivos de M3 (el navegador no puede leer los 5 ficheros completos).
#
# Uso (desde la raíz):  julia --project=. scripts/m03/preparar_extractos.jl
#
# Lee crudos/sN_medida01.txt (N = 1…5), comprueba fs, número de muestras y
# marcas de tiempo de cada estación y escribe extractos/m01_z_300s_mg.csv con
# el canal vertical (Z0HNZ) de las cinco estaciones durante los primeros 300 s,
# convertido de g a mg (×1000) con 5 decimales (resolución 10⁻⁵ mg, muy por
# debajo de la amplitud de las señales, del orden de 0,1 mg). No se filtra,
# no se diezma y no se quita la media: es el dato original recortado.
#
# Sincronización: el fichero de cada estación trae su propia columna de tiempo.
# El script comprueba que coinciden muestra a muestra, pero eso solo demuestra
# que las marcas son iguales, no que los relojes de las estaciones lo estuvieran
# (la ficha de la campaña no documenta cómo se sincronizaron).
# =============================================================================
using Printf, Resonancia

const DIR = joinpath(@__DIR__, "..", "..", "datos", "reales-publicables", "torroja-puente",
    "2018-06-22-vibracion-ambiental")
const DURACION = 300.0

zs = Vector{Vector{Float64}}()
tref = Float64[]
for n in 1:5
    t, a, fs, est, inicio = leer_torroja(joinpath(DIR, "crudos", "s$(n)_medida01.txt"))
    fs == 100.0 || error("estación $est: fs = $fs, se esperaban 100 Hz")
    length(t) == 60_000 || error("estación $est: $(length(t)) muestras, se esperaban 60 000")
    dt = diff(t)
    maximum(abs, dt .- 0.01) < 1e-6 || error("estación $est: paso de tiempo irregular")
    if n == 1
        append!(tref, t)
    else
        maximum(abs, t .- tref) < 1e-9 || error("estación $est: marcas de tiempo distintas de GS1")
    end
    @printf("%s  inicio %s  fs %.0f Hz  N %d  media Z %.4f mg  desv. Z %.4f mg\n", est, inicio, fs, length(t),
        1000 * sum(a[:, 3]) / length(t), 1000 * sqrt(sum(abs2, a[:, 3] .- sum(a[:, 3]) / length(t)) / length(t)))
    push!(zs, a[:, 3])
end

m = round(Int, DURACION * 100)
mkpath(joinpath(DIR, "extractos"))
salida = joinpath(DIR, "extractos", "m01_z_300s_mg.csv")
open(salida, "w") do io
    println(io, "t_s,GS1_Z_mg,GS2_Z_mg,GS3_Z_mg,GS4_Z_mg,GS5_Z_mg")
    for i in 1:m
        @printf(io, "%.2f", tref[i])
        for z in zs
            @printf(io, ",%.5f", 1000 * z[i])
        end
        println(io)
    end
end
println("Escrito ", normpath(salida), " (", filesize(salida) ÷ 1024, " KiB)")
