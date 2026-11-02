#!/usr/bin/env julia
# =============================================================================
# generar_referencia.jl: datos de referencia de M4 (entradas fijas y resultados
# calculados con Resonancia.jl) para contrastar las implementaciones en
# JavaScript (recursos/js/procesado.js) y Python (mse/m04-senales-ii/python/).
#
# Uso (desde la raíz):  julia --project=. scripts/m04/generar_referencia.jl
# Escribe mse/m04-senales-ii/referencia/procesado.json. Sin aleatoriedad: las
# entradas son fórmulas deterministas y quedan guardadas en el propio fichero.
# Los números complejos se guardan como {re, im}; los filtros IIR, como la
# matriz `sos` (filas [b0 b1 b2 1 a1 a2]).
# =============================================================================
using Resonancia

json(x::Bool) = x ? "true" : "false"
json(x::Integer) = string(x)
json(x::Real) = isfinite(x) ? string(Float64(x)) : "null"
json(x::AbstractString) = "\"" * x * "\""
json(x::Symbol) = json(String(x))
json(x::Tuple) = json(collect(x))
json(x::AbstractVector) = "[" * join(json.(x), ",") * "]"
json(x::AbstractMatrix) = "[" * join((json(x[i, :]) for i in axes(x, 1)), ",") * "]"
json(x::NamedTuple) = "{" * join(("\"$k\":" * json(v) for (k, v) in pairs(x)), ",") * "}"
json(x::AbstractDict) = "{" * join(("\"$k\":" * json(x[k]) for k in sort(collect(keys(x)))), ",") * "}"
cx(v) = (re=real.(v), im=imag.(v))

# «ruido» determinista (misma fórmula que un generador de números aleatorios barato): fracción de sin(k)·43758,5453
ruido(k) = (u = sin(12.9898k) * 43758.5453; u - floor(u) - 0.5)

ref = Dict{String,Any}()

# 1. Propiedades de las ventanas (N = 64) y varianza de Welch
N = 64
nombres = [:rectangular, :hann, :hamming, :blackman, :flattop]
prop = Dict(String(n) => (perdida=perdida_escalonamiento(ventana(n, N)), ancho3db=ancho_banda_3db(ventana(n, N)),
    lobulo=nivel_lobulo_lateral(ventana(n, N)), enbw=ancho_banda_ruido(ventana(n, N)),
    gcoh=ganancia_coherente(ventana(n, N))) for n in nombres)
wh, wr = ventana(:hann, N), ventana(:rectangular, N)
vw = [(nombre=String(n), solape=s, K=varianza_welch(ventana(n, N), s, 8N)[1], var=varianza_welch(ventana(n, N), s, 8N)[2])
      for n in (:rectangular, :hann, :hamming) for s in (0.0, 0.5, 0.75)]
ref["ventanas"] = (N=N, nombres=String.(nombres), propiedades=prop,
    solape_hann_32=correlacion_solape(wh, 32), solape_rect_32=correlacion_solape(wr, 32),
    solape_hann_0=correlacion_solape(wh, 0), solape_hann_64=correlacion_solape(wh, 64),
    longitud=8N, varianza_welch=vw)

# 2. Tendencia
tt = collect(0:29) ./ 29
xt = 2.0 .+ 1.5 .* tt .- 0.8 .* tt .^ 2 .+ 0.3 .* sin.(2π .* 3.0 .* tt) .+ 0.05 .* ruido.(1:30)
tend = Dict(string(g) => (let (y, p) = quitar_tendencia(xt, g); (y=y, tendencia=p) end) for g in 0:2)
ref["tendencia"] = (x=xt, resultados=tend)

# 3. Interpolación uniforme (instantes irregulares y un hueco)
ti = [0.0, 0.4, 1.1, 1.5, 2.0, 3.0, 3.4, 4.0, 4.6, 5.0]
xi = sin.(1.3 .* ti) .+ 0.2 .* ti
tu, xu, hu = interpolar_uniforme(ti, xi, 2.0)
ref["interpolar"] = (t=ti, x=xi, fs=2.0, tu=tu, xu=xu, hueco=hu)

# 4. Integración (fs = 16 Hz, N = 64: 4 s)
fsi = 16.0
ta = collect(0:63) ./ fsi
xa = 0.2 .+ cos.(2π .* 2.0 .* ta) .+ 0.5 .* sin.(2π .* 3.5 .* ta .+ 0.3) .+ 0.1 .* cos.(2π .* 0.25 .* ta)
ref["integracion"] = (x=xa, fs=fsi, fcorte=1.0, trapecio=integrar_trapecio(xa, fsi),
    frecuencia1=integrar_frecuencia(xa, fsi; fcorte=1.0, orden=1),
    frecuencia2=integrar_frecuencia(xa, fsi; fcorte=1.0, orden=2))

# 5. SNR y ruido
xs = [2.0sin(0.31k) + 0.5 for k in 1:60]
rs = [0.2ruido(k) for k in 1:60]
fb = collect(0.0:0.5:10.0)
Pb = [1.0 + 8exp(-((f - 4)^2) / 0.5) for f in fb]
Pn = fill(0.5, length(fb))
ref["snr"] = (x=xs, ruido=rs, snr_db=snr_db(xs, rs), f=fb, P=Pb, Pruido=Pn, banda=[3.0, 5.0],
    snr_banda=snr_banda(fb, Pb, Pn, (3.0, 5.0)), snr_banda_total=snr_banda(fb, Pb, Pn, (0.0, 10.5)),
    densidad=100e-6, fa=0.0, fb=100.0, rms_banda=rms_ruido_banda(100e-6, 0.0, 100.0))

# 6. Espectros cruzados, coherencia, H1 y H2 (fs = 100 Hz, N = 512, nseg = 64)
fsc, Nc = 100.0, 512
xc = [sin(0.9k) + 0.6cos(2.3k + 0.4) + 1.2ruido(k) for k in 1:Nc]
bp = filtro_butterworth(2, (8.0, 12.0), fsc; tipo=:pasabanda)
yc = filtrar(bp, xc) .+ 0.4 .* [ruido(k + 1000) for k in 1:Nc]
fc_, Gxx, Gyy, Gxy = espectros_cruzados(xc, yc, fsc; nseg=64, solape=0.5)
e = estimar_frf(xc, yc, fsc; nseg=64, solape=0.5)
ref["cruzados"] = (x=xc, y=yc, fs=fsc, nseg=64, solape=0.5, f=fc_, Gxx=Gxx, Gyy=Gyy, Gxy=cx(Gxy),
    coherencia=e.coherencia, H1=cx(e.H1), H2=cx(e.H2))

# 7. Espectrograma de un barrido (fs = 50 Hz, N = 256, nseg = 64, solape 0,75)
fse, Ne = 50.0, 256
te = collect(0:Ne-1) ./ fse
xe = sin.(2π .* (2.0 .* te .+ 0.5 .* 3.0 .* te .^ 2)) .+ 0.1 .* [ruido(k) for k in 1:Ne]
tg, fg, Pg = espectrograma(xe, fse; nseg=64, solape=0.75)
ref["espectrograma"] = (x=xe, fs=fse, nseg=64, solape=0.75, t=tg, f=fg, P=Pg)

# 8. Filtros: Butterworth (cuatro tipos), FIR (cuatro tipos), respuesta, retardo de grupo y filtrado
disenos = [(orden=4, fc=0.5, fs=500.0, tipo=:pasaaltos), (orden=3, fc=10.0, fs=100.0, tipo=:pasabajos),
           (orden=2, fc=(8.0, 12.0), fs=100.0, tipo=:pasabanda), (orden=2, fc=(49.0, 51.0), fs=500.0, tipo=:rechazabanda)]
fprueba = [[0.1, 0.25, 0.5, 1.0, 2.0, 5.0], [1.0, 5.0, 10.0, 20.0, 40.0], [2.0, 8.0, 10.0, 12.0, 30.0], [20.0, 49.0, 50.0, 51.0, 100.0]]
butter = map(zip(disenos, fprueba)) do (d, fr)
    h = filtro_butterworth(d.orden, d.fc, d.fs; tipo=d.tipo)
    # el retardo de grupo no está definido cerca de un cero de la respuesta: no se evalúa en el centro del rechazabanda
    frt = d.tipo === :rechazabanda ? [20.0, 100.0] : fr
    (orden=d.orden, fc=d.fc, fs=d.fs, tipo=d.tipo, sos=h.sos, f=fr, H=cx(respuesta_frecuencia(h, fr, d.fs)),
     f_retardo=frt, retardo=retardo_grupo(h, frt, d.fs))
end
fdis = [(ntaps=21, fc=10.0, fs=100.0, tipo=:pasabajos, ventana=:hamming), (ntaps=21, fc=10.0, fs=100.0, tipo=:pasaaltos, ventana=:hann),
        (ntaps=31, fc=(10.0, 20.0), fs=100.0, tipo=:pasabanda, ventana=:blackman), (ntaps=31, fc=(10.0, 20.0), fs=100.0, tipo=:rechazabanda, ventana=:hamming)]
fir = map(fdis) do d
    h = filtro_fir(d.ntaps, d.fc, d.fs; tipo=d.tipo, ventana=d.ventana)
    fr = [0.0, 5.0, 10.0, 15.0, 30.0, 50.0]
    (ntaps=d.ntaps, fc=d.fc, fs=d.fs, tipo=d.tipo, ventana=d.ventana, b=h.b, f=fr, H=cx(respuesta_frecuencia(h, fr, d.fs)),
     retardo=retardo_grupo(h, 5.0, d.fs))
end
xf = [sin(2π * 1.0 * k / 100) + 0.5sin(2π * 15.0 * k / 100) + 0.3ruido(k) + 0.4 for k in 0:119]
lp = filtro_butterworth(3, 10.0, 100.0)
hp = filtro_fir(21, 10.0, 100.0)
ref["filtros"] = (butterworth=butter, fir=fir, x=xf,
    iir_causal=filtrar(lp, xf), iir_fase_cero=filtrar_fase_cero(lp, xf),
    fir_causal=filtrar(hp, xf), fir_compensado=filtrar(hp, xf; compensar=true), fir_fase_cero=filtrar_fase_cero(hp, xf),
    diezmar_q=4, x_diezmar=[sin(2π * 1.0 * k / 100) + 0.4sin(2π * 40.0 * k / 100) for k in 0:199],
    diezmado=diezmar([sin(2π * 1.0 * k / 100) + 0.4sin(2π * 40.0 * k / 100) for k in 0:199], 4))

# 9. Oscilador de 1 GDL (aceleración con retenedor de orden cero), para fabricar respuestas conocidas en M4.6
uo = [ruido(k) * 3 for k in 1:60]
ref["oscilador"] = (u=uo, f0=2.5, zeta=0.03, fs=50.0, a=aceleracion_1gdl(uo, 2.5, 0.03, 50.0))

# 10. Wavelet de Morlet (introducción de M4.7): barrido de 2 a 9 Hz en 5 s a 50 Hz, longitud 250 (no potencia de 2: Bluestein)
tw = (0:249) ./ 50
xw = sin.(2π .* (2.0 .* tw .+ 0.7 .* tw .^ 2)) .+ 0.2 .* [ruido(k) for k in 1:250]
frw = [2.0, 3.5, 5.0, 7.0, 9.0]
ref["wavelet"] = (x=xw, fs=50.0, frecuencias=frw, w0=6.0, W=cwt_morlet(xw, 50.0, frw; w0=6.0))

salida = joinpath(@__DIR__, "..", "..", "mse", "m04-senales-ii", "referencia", "procesado.json")
mkpath(dirname(salida))
open(salida, "w") do io
    println(io, "{")
    claves = sort(collect(keys(ref)))
    for (i, k) in enumerate(claves)
        println(io, "  \"", k, "\": ", json(ref[k]), i < length(claves) ? "," : "")
    end
    println(io, "}")
end
println("Escrito ", normpath(salida))
