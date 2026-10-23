# Procesamiento por lotes: un resumen de calidad por cada CSV de una carpeta.
#   julia --project=. claude/c6-informes/_ejemplo/julia/lote.jl
using CSV, DataFrames

"Resumen de calidad de un fichero: filas, columnas, celdas ausentes y filas duplicadas."
function resumen_fichero(ruta)
    df = CSV.read(ruta, DataFrame)
    (fichero = basename(ruta), filas = nrow(df), columnas = ncol(df),
     ausentes = sum(count(ismissing, c) for c in eachcol(df)),
     duplicadas = nrow(df) - nrow(unique(df)))
end

function lote(carpeta)
    ficheros = sort(filter(f -> endswith(f, ".csv"), readdir(carpeta; join = true)))
    DataFrame(resumen_fichero.(ficheros))
end

if abspath(PROGRAM_FILE) == @__FILE__()
    carpeta = normpath(joinpath(@__DIR__, "..", "..", "..", "..", "datos", "sinteticos", "curso-claude"))
    println(lote(carpeta))
end
