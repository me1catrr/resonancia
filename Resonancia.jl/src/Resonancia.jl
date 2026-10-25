"""
    Resonancia

Funciones reutilizables del curso Resonancia: lectura de registros reales de
`datos/reales-publicables/` y análisis espectral básico (FFT y densidad
espectral de potencia por el método de Welch).

Sin dependencias externas: la FFT es propia (radix-2) y está comprobada con
pruebas frente a la DFT directa.
"""
module Resonancia

export fft_radix2, psd_welch, buscar_picos, rms_por_ventana,
    leer_torroja, leer_aceleracion_csv

include("espectral.jl")
include("lectura.jl")

end # module
