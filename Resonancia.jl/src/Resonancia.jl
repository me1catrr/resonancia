"""
    Resonancia

Funciones reutilizables del curso Resonancia: lectura de registros reales de
`datos/reales-publicables/` y análisis espectral básico (FFT y densidad
espectral de potencia por el método de Welch).

Solo usa las bibliotecas estándar de Julia (`LinearAlgebra` y `SparseArrays`): la FFT es propia
(radix-2) y está comprobada con pruebas frente a la DFT directa. Incluye también las matrices
estructuradas de M02 (Toeplitz, Hankel, circulantes), la autocorrelación, Yule–Walker, SSA, los
modelos de masas y muelles y de edificio de cortante, los modos propios y el MAC.
"""
module Resonancia

using LinearAlgebra, SparseArrays

export fft_radix2, ifft_radix2, psd_welch, buscar_picos, rms_por_ventana, frecuencia_pico_por_segmentos,
    leer_torroja, leer_aceleracion_csv,
    toeplitz, hankel, hankel_trayectoria, promedio_antidiagonal, ssa, circulante,
    conv_circular, conv_circular_fft, vandermonde, autocorrelacion, yule_walker,
    cadena_masas_muelles, edificio_cortante, modos_propios, mac, era,
    levinson_durbin, matriz_observabilidad, matriz_controlabilidad, matriz_mac,
    cociente_rayleigh, rayleigh_amortiguamiento, expm, espacio_estados, discretizar_zoh, polos_modales,
    pseudoinversa_svd, rango_numerico, edificio_tres_plantas, polos_ar,
    ventana, ganancia_coherente, ancho_banda_ruido, hilbert_analitica, fase_instantanea,
    correlacion_cruzada, autocorrelacion_fft

include("espectral.jl")
include("lectura.jl")
include("estructuradas.jl")
include("modal.jl")
include("senales.jl")

end # module
