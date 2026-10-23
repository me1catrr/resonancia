# Genera las figuras de la página C6 (SVG) a partir de los datos sintéticos.
#   julia --project=. claude/c6-informes/_ejemplo/julia/figuras.jl
using CairoMakie, CSV, DataFrames, Statistics, Dates
include(joinpath(@__DIR__, "analisis.jl"))
const SALIDA = normpath(joinpath(@__DIR__, "..", "..", "fig"))
CairoMakie.activate!(type = "svg")
set_theme!(fontsize = 13)

# 1) Ventas mensuales por región (caso A, sin duplicados; los ausentes dejan hueco)
a = unique(cargar("a_ventas.csv"; dateformat = "yyyy-mm-dd"))
fig = Figure(size = (760, 340))
ax = Axis(fig[1, 1]; xlabel = "mes", ylabel = "ventas (miles de €)", xticks = (1:6:36, string.(Date(2023, 1, 1) .+ Month.(0:6:35))))
colores = Dict("Norte" => :steelblue, "Centro" => :darkorange, "Sur" => :seagreen)
marcas = Dict("Norte" => :circle, "Centro" => :rect, "Sur" => :utriangle)
for (r, g) in pairs(groupby(a, :region))
    reg = r.region
    y = [ismissing(v) ? NaN : v / 1000 for v in g.ventas_eur]
    lines!(ax, 1:length(y), y; color = colores[reg], label = reg)
    scatter!(ax, 1:length(y), y; color = colores[reg], marker = marcas[reg], markersize = 7)
end
axislegend(ax; position = :lt, orientation = :horizontal)
save(joinpath(SALIDA, "ventas.svg"), fig)

# 2) Espectro del caso E con la separación entre bins señalada
e = cargar("e_vibracion.csv")
f, A = espectro(e.aceleracion_m_s2, 200.0)
fig = Figure(size = (760, 340))
ax = Axis(fig[1, 1]; xlabel = "frecuencia (Hz)", ylabel = "amplitud (m/s²)")
m = f .<= 60
lines!(ax, f[m], A[m]; color = :steelblue)
vlines!(ax, [12.5, 41.0]; color = :gray40, linestyle = :dash)
text!(ax, 12.9, 0.14; text = "12,5 Hz", align = (:left, :center))
text!(ax, 41.4, 0.03; text = "41,0 Hz", align = (:left, :center))
xlims!(ax, 0, 60)
save(joinpath(SALIDA, "espectro.svg"), fig)

# 3) Temperatura del caso D con el hueco del sensor
d = cargar("d_ambiental.csv")
fig = Figure(size = (760, 300))
ax = Axis(fig[1, 1]; xlabel = "muestra (cada 10 min)", ylabel = "temperatura (°C)")
t = [ismissing(v) ? NaN : v for v in d.temperatura_C]
lines!(ax, 1:length(t), t; color = :firebrick)
vspan!(ax, 601, 613; color = (:gray, 0.4))
ylims!(ax, 15.5, 29.5)
text!(ax, 625, 29.0; text = "hueco: 13 muestras", align = (:left, :center))
save(joinpath(SALIDA, "ambiental.svg"), fig)
println("Figuras escritas en ", SALIDA)
