#!/usr/bin/env julia
# =============================================================================
# generar_referencia.jl: datos de referencia de M3 (entradas fijas y resultados
# calculados con Resonancia.jl) para contrastar las implementaciones en
# JavaScript (recursos/js/senales.js) y Python (mse/m03-senales-i/python/).
#
# Uso (desde la raíz):  julia --project=. scripts/m03/generar_referencia.jl
# Escribe mse/m03-senales-i/referencia/senales.json. Sin aleatoriedad.
# =============================================================================
using Resonancia

json(x::Bool) = x ? "true" : "false"
json(x::Integer) = string(x)
json(x::Real) = isfinite(x) ? string(Float64(x)) : "null"
json(x::AbstractString) = "\"" * x * "\""
json(x::AbstractVector) = "[" * join(json.(x), ",") * "]"
json(x::AbstractMatrix) = "[" * join((json(x[i, :]) for i in axes(x, 1)), ",") * "]"
json(x::NamedTuple) = "{" * join(("\"$k\":" * json(v) for (k, v) in pairs(x)), ",") * "}"

ref = Dict{String,Any}()

# 1. Descriptores temporales
xd = [1.0, -1.0, 2.0, -2.0, 0.5, 3.0]
ref["descriptores"] = merge((x=xd,), descriptores_temporales(xd))

# 2. Convertidor ideal (3 bits, ±1, offset 0,1)
xc = [0.0, 0.26, -0.26, 0.6, 0.9, -1.2, -0.95]
yc, sc, qc = cuantizar(xc; bits=3, rango=1.0, offset=0.1)
ref["cuantizar"] = (x=xc, bits=3, rango=1.0, offset=0.1, y=yc, saturada=sc, q=qc)

# 3. Frecuencia aparente
fa = [3.0, 7.0, 30.0, 50.0, 80.0, 117.0, 130.0, 199.0]
ref["alias"] = (f=fa, fs=100.0, aparente=[frecuencia_aparente(f, 100.0) for f in fa])

# 4. DFT de longitud no potencia de 2 (Bluestein) y la del ejercicio a mano
x6 = [1.0, 2.0, 0.0, -1.0, 3.0, 0.5]
X6 = dft(x6)
x12 = [sin(0.7k) + 0.3cos(2.1k) for k in 1:12]
X12 = dft(x12)
ref["dft"] = (x6=x6, re6=real.(X6), im6=imag.(X6), x12=x12, re12=real.(X12), im12=imag.(X12),
    mano=[1.0, 0.0, -1.0, 0.0], mano_re=real.(dft([1.0, 0.0, -1.0, 0.0])))

# 5. Periodograma y espectro de amplitud (fs = 10 Hz, N = 20)
fs = 10.0
tp = (0:19) ./ fs
xp = 0.3 .+ 1.2 .* cos.(2π * 2.0 .* tp .+ 0.4) .+ 0.5 .* sin.(2π * 3.3 .* tp)
f1, P1 = periodograma(xp, fs)
_, P2 = periodograma(xp, fs; quitar_media=false)
fh, Ph = periodograma(xp, fs; ventana=:hann, nfft=32)
fa_, A, fase = espectro_amplitud(xp, fs)
_, Ah, _ = espectro_amplitud(xp, fs; ventana=:hann, nfft=32)
ref["periodograma"] = (x=xp, fs=fs, f=f1, P=P1, P_con_media=P2, f_hann32=fh, P_hann32=Ph,
    A=A, fase=fase, A_hann32=Ah)

# 6. Welch (Hann periódica, solape 0,5), fs = 50 Hz, N = 256, nseg = 64
tw = (0:255) ./ 50
xw = [sin(2π * 6.25 * t) + 0.4sin(2π * 11.0 * t + 1) + 0.2cos(37.3t^1.2) for t in tw]
fw, Pw = psd_welch(xw, 50.0; nseg=64, solape=0.5)
ref["welch"] = (x=xw, fs=50.0, nseg=64, solape=0.5, f=fw, P=Pw)

# 7. Potencia por bandas, NPSD y ANPSD (sobre la PSD de Welch anterior)
bandas = [(0.0, 5.0), (5.0, 10.0), (10.0, 25.1)]
pot, frac = potencia_bandas(fw, Pw, bandas)
fb, Pn = psd_normalizada(fw, Pw; banda=(2.0, 15.0))
Ps = hcat(Pw, 0.01 .* reverse(Pw), Pw .+ 0.05)
fan, An = anpsd(fw, Ps; banda=(2.0, 15.0))
ref["bandas"] = (bandas=[collect(b) for b in bandas], potencia=pot, fraccion=frac,
    banda_n=[2.0, 15.0], f_n=fb, Pn=Pn, Ps=Ps, anpsd=An)

# 8. Ruido de color a partir de una entrada fija (no potencia de 2: pasa por Bluestein)
rc = [sin(1.3k) + 0.4cos(0.37k^1.3) for k in 1:24]
ref["colorear"] = (r=rc, rosa=colorear(rc, 1.0), marron=colorear(rc, 2.0))

salida = joinpath(@__DIR__, "..", "..", "mse", "m03-senales-i", "referencia", "senales.json")
open(salida, "w") do io
    println(io, "{")
    claves = sort(collect(keys(ref)))
    for (i, k) in enumerate(claves)
        println(io, "  \"", k, "\": ", json(ref[k]), i < length(claves) ? "," : "")
    end
    println(io, "}")
end
println("Escrito ", normpath(salida))
