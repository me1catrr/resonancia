# Comprobación cruzada (M4.2): los filtros de Resonancia.jl frente a DSP.jl.
#
#   julia --project=. scripts/m04/comprobar_filtros_dsp.jl
#
# Compara la respuesta en frecuencia compleja de `filtro_butterworth` con la de `digitalfilter(..., Butterworth(n))`
# de DSP.jl (evaluada con `freqresp`) en una malla de diseños, y la de `filtro_fir` con `FIRWindow`. El filtrado
# causal y de fase cero se compara con `filt` y `filtfilt`. Sale con código 1 si alguna diferencia supera las tolerancias.
# Resonancia.jl no depende de DSP.jl: esta comprobación vive en el entorno del curso, que sí lo tiene.

using Resonancia, DSP, Random, Printf

const TIPOS = [(:pasabajos, Lowpass, 1), (:pasaaltos, Highpass, 1), (:pasabanda, Bandpass, 2), (:rechazabanda, Bandstop, 2)]
tipo_dsp(T, fc) = fc isa Tuple ? T(fc...) : T(fc)   # Bandpass(f1, f2), Lowpass(fc)
const FS = [100.0, 500.0, 512.0, 1000.0]
const FRACCIONES = [(0.004, 0.012), (0.02, 0.05), (0.05, 0.15), (0.1, 0.25), (0.3, 0.42)]   # (f1, f2) como fracción de fs

disenos = 0
peor_butter = 0.0   # máxima |H_mía − H_DSP| absoluta (la ganancia máxima es 1)
peor_fir = 0.0
for fs in FS, (tipo, T, nb) in TIPOS, N in 1:8, (a, b) in FRACCIONES
    global disenos, peor_butter
    fc = nb == 1 ? a * fs : (a * fs, b * fs)
    mia = filtro_butterworth(N, fc, fs; tipo=tipo)
    ref = digitalfilter(tipo_dsp(T, fc), Butterworth(N); fs=fs)
    f = exp.(range(log(1e-3 * fs), log(0.499 * fs); length=400))
    Hm = respuesta_frecuencia(mia, f, fs)
    Hr = freqresp(ref, 2π .* f ./ fs)
    peor_butter = max(peor_butter, maximum(abs.(Hm .- Hr)))
    disenos += 1
end
@printf "Butterworth: %d diseños (4 tipos, orden 1–8, 4 fs, 5 bandas), 400 frecuencias cada uno; diferencia máxima |ΔH| = %.2e\n" disenos peor_butter

disenos_fir = 0
invertidos = 0
for fs in FS, (tipo, T, nb) in TIPOS, nt in (51, 101, 201), (a, b) in FRACCIONES[2:end]
    global disenos_fir, peor_fir
    fc = nb == 1 ? a * fs : (a * fs, b * fs)
    mia = filtro_fir(nt, fc, fs; tipo=tipo, ventana=:hamming)
    # DSP.jl: FIRWindow(window; scale=true) normaliza la ganancia en la banda de paso, como `filtro_fir`
    hr = digitalfilter(tipo_dsp(T, fc), FIRWindow(hamming(nt; zerophase=false); scale=true); fs=fs)
    # `digitalfilter` con FIRWindow devuelve los coeficientes: se comparan directamente y, además, la respuesta
    f = range(0.001 * fs, 0.499 * fs; length=300)
    Hm = respuesta_frecuencia(mia, f, fs)
    Hr = freqresp(PolynomialRatio(hr, [1.0]), 2π .* f ./ fs)
    # DSP.jl normaliza dividiendo por la respuesta COMPLEJA en la frecuencia de referencia: si el retardo
    # (nt-1)/2 es impar, en Nyquist vale −1 y el pasaaltos sale con la polaridad invertida. SciPy (`firwin`) y
    # `filtro_fir` normalizan con la amplitud de fase cero y no la invierten. Se compara salvo ese signo.
    signo = sum(mia.b .* hr) < 0 ? -1.0 : 1.0
    global invertidos += signo < 0
    signo < 0 && tipo !== :pasaaltos && error("polaridad invertida en un $tipo: ya no es solo el pasaaltos")
    peor_fir = max(peor_fir, maximum(abs.(mia.b .- signo .* hr)), maximum(abs.(Hm .- signo .* Hr)))
    disenos_fir += 1
end
@printf "FIR por ventana (Hamming): %d diseños; diferencia máxima (coeficientes y respuesta, salvo el signo) = %.2e\n" disenos_fir peor_fir
@printf "  DSP.jl invierte la polaridad en %d de ellos (todos pasaaltos con (ntaps-1)/2 impar); `filtro_fir` coincide con SciPy.\n" invertidos

# filtrado: causal y de fase cero frente a filt y filtfilt, con una señal aleatoria de semilla fija
Random.seed!(20261101)
x = randn(4000)
peor_filt, peor_filtfilt = 0.0, 0.0
for (tipo, T, nb) in TIPOS, N in (2, 4, 6)
    fs = 500.0
    fc = nb == 1 ? 20.0 : (20.0, 60.0)
    mia = filtro_butterworth(N, fc, fs; tipo=tipo)
    ref = digitalfilter(tipo_dsp(T, fc), Butterworth(N); fs=fs)
    global peor_filt = max(peor_filt, maximum(abs.(filtrar(mia, x) .- filt(ref, x))))
    # el filtfilt de DSP.jl usa otras condiciones iniciales en los extremos: se compara el interior
    yd = filtfilt(ref, x)
    global peor_filtfilt = max(peor_filtfilt, maximum(abs.(filtrar_fase_cero(mia, x)[500:3500] .- yd[500:3500])))
end
@printf "Filtrado: causal vs filt, diferencia máxima %.2e; fase cero vs filtfilt (interior), %.2e\n" peor_filt peor_filtfilt

ok = peor_butter < 1e-9 && peor_fir < 1e-9 && peor_filt < 1e-9 && peor_filtfilt < 1e-6
println(ok ? "COMPROBACIÓN SUPERADA" : "COMPROBACIÓN NO SUPERADA")
exit(ok ? 0 : 1)
