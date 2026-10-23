# Leer y escribir Excel (XLSX) con XLSX.jl y DataFrames (caso A). Uso:
#   julia --project=. claude/c6-informes/_ejemplo/julia/excel.jl [carpeta_de_salida]
using XLSX, DataFrames, CSV
include(joinpath(@__DIR__, "analisis.jl"))

"Escribe el resumen por región en un libro con una hoja «resumen» y otra «validacion»."
function escribir_libro(ruta, df)
    res = ventas_por_region(df)
    val = DataFrame([validar_ventas(df)])          # un vector de NamedTuple es una tabla de una fila
    XLSX.writetable(ruta, "resumen" => res, "validacion" => val; overwrite = true)
    return ruta
end

"Lee una hoja de un libro XLSX como DataFrame."
leer_hoja(ruta, hoja) = DataFrame(XLSX.readtable(ruta, hoja))

if abspath(PROGRAM_FILE) == @__FILE__()
    salida = isempty(ARGS) ? mktempdir() : ARGS[1]
    ruta = escribir_libro(joinpath(salida, "ventas_resumen.xlsx"), cargar("a_ventas.csv"; dateformat = "yyyy-mm-dd"))
    println("Hojas: ", XLSX.sheetnames(XLSX.readxlsx(ruta)))
    println(leer_hoja(ruta, "resumen"))
    println(leer_hoja(ruta, "validacion"))
end
