#!/usr/bin/env julia
# =============================================================================
# generar_caso.jl: cifras de referencia del caso integrado de M4 (Palma del Río,
# set1 con tráfico y set2 sin tráfico) calculadas con Resonancia.jl, para
# contrastar la pestaña Python (mse/m04-senales-ii/python/caso.py).
#
# Uso (desde la raíz):  julia --project=. scripts/m04/generar_caso.jl
# Escribe mse/m04-senales-ii/referencia/caso.json. Son los mismos pasos que el
# caso integrado de la página (mse/m04-senales-ii/index.qmd, «Práctica guiada»).
# =============================================================================
using Resonancia, Statistics

json(x::Bool) = x ? "true" : "false"
json(x::Integer) = string(x)
json(x::Real) = isfinite(x) ? string(Float64(x)) : "null"
json(x::AbstractString) = "\"" * x * "\""
json(x::AbstractVector) = "[" * join(json.(x), ",") * "]"
json(x::NamedTuple) = "{" * join(("\"$k\":" * json(v) for (k, v) in pairs(x)), ",") * "}"

const G0 = 9.80665
const PALMA = joinpath(@__DIR__, "..", "..", "datos", "reales-publicables", "palma-del-rio-puente", "2020-07-17-vibracion-operacional", "crudos")

_, a1, fs = leer_aceleracion_csv(joinpath(PALMA, "set1.csv"))
_, a2, _ = leer_aceleracion_csv(joinpath(PALMA, "set2.csv"))
x1, x2 = a1 .* G0, a2 .* G0

resumen(x) = (let d = descriptores_temporales(x); (media=d.media, rms_fluctuante=d.rms_fluctuante, cresta_fluctuante=d.cresta_fluctuante, curtosis=d.curtosis) end)

# PSD global y fracciones de potencia por bandas
f, P = psd_welch(x1, fs; nseg=8192)
bandas = [(0.0, 0.5), (0.5, 5.0), (5.0, 15.0), (15.0, 32.0), (32.0, 100.0), (100.0, 256.0)]
_, frac = potencia_bandas(f, P, bandas)
pk = buscar_picos(f, P; fmin=1.0, fmax=60.0, n=6, separacion=0.5)

# preprocesado: tendencia lineal, diezmado a 64 Hz y pasabanda de fase cero
q = 8
y, _ = quitar_tendencia(x1, 1)
yd = diezmar(y, q)
fsd = fs / q
filtro = filtro_butterworth(4, (0.5, 25.0), fsd; tipo=:pasabanda)
yf = filtrar_fase_cero(filtro, yd)

# integración con varios cortes
cortes = [0.3, 0.5, 1.0]
integ = [(fcorte=fc,
          v_rms_mms=1000 * std(integrar_frecuencia(yd, fsd; fcorte=fc, orden=1)),
          v_pico_mms=1000 * maximum(abs, integrar_frecuencia(yd, fsd; fcorte=fc, orden=1)),
          d_rms_mm=1000 * std(integrar_frecuencia(yd, fsd; fcorte=fc, orden=2)),
          d_pico_mm=1000 * maximum(abs, integrar_frecuencia(yd, fsd; fcorte=fc, orden=2))) for fc in cortes]

# contraste con el registro sin tráfico (set2), por bandas, con PSD de segmentos de 1024 a 64 Hz
yd2 = diezmar(quitar_tendencia(x2, 1)[1], q)
fa, Pa = psd_welch(yd, fsd; nseg=1024)
_, Pb = psd_welch(yd2, fsd; nseg=1024)
bandas2 = [(0.5, 5.0), (5.0, 15.0), (15.0, 30.0)]
cociente = [potencia_bandas(fa, Pa, [b])[1][1] / potencia_bandas(fa, Pb, [b])[1][1] for b in bandas2]

ref = (fs=fs, N=length(x1), set1=resumen(x1), set2=resumen(x2), bandas=[collect(b) for b in bandas], fraccion_potencia=frac,
       picos_Hz=f[pk], rms_diezmado=std(yd), N_diezmado=length(yd), rms_pasabanda=std(yf), integracion=integ,
       bandas_contraste=[collect(b) for b in bandas2], cociente_trafico_fondo=cociente)

salida = joinpath(@__DIR__, "..", "..", "mse", "m04-senales-ii", "referencia", "caso.json")
open(salida, "w") do io
    println(io, json(ref))
end
println("Escrito ", normpath(salida))
