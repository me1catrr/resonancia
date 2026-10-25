# Tema común de las páginas del catálogo de datos (R1): paleta del curso, figuras en SVG
# y formato de números con coma decimal.
using CairoMakie, Printf

CairoMakie.activate!(type="svg")

const AZUL = colorant"#1B6CA8"
const NARANJA = colorant"#D95F02"
const VERDE = colorant"#2A9D8F"
const VIOLETA = colorant"#6F42C1"
const GRIS = colorant"#6B7280"
const TINTA = colorant"#1F2937"

set_theme!(Theme(
    fontsize=14,
    palette=(color=[AZUL, NARANJA, VERDE, VIOLETA, GRIS],),
    Axis=(xgridcolor=RGBAf(0.42, 0.45, 0.5, 0.18), ygridcolor=RGBAf(0.42, 0.45, 0.5, 0.18),
        topspinevisible=false, rightspinevisible=false),
    Lines=(linewidth=1.6,),
))

"""Número con `d` decimales y coma decimal: `coma(3.2641) == "3,26"`."""
coma(x; d=2) = replace(Printf.format(Printf.Format("%." * string(d) * "f"), x), "." => ",")
