"""
    Resonancia

Funciones reutilizables del curso Resonancia: lectura de registros reales de
`datos/reales-publicables/` y análisis espectral básico (FFT y densidad
espectral de potencia por el método de Welch).

Solo usa las bibliotecas estándar de Julia (`LinearAlgebra` y `SparseArrays`): la FFT es propia
(radix-2) y está comprobada con pruebas frente a la DFT directa. Incluye también las matrices
estructuradas de M02 (Toeplitz, Hankel, circulantes), la autocorrelación, Yule–Walker, SSA, los
modelos de masas y muelles y de edificio de cortante, los modos propios y el MAC. Para M3, la DFT de longitud arbitraria (Bluestein), el periodograma, el
espectro de amplitud, la potencia por bandas, la PSD normalizada (NPSD/ANPSD), los descriptores
temporales, un convertidor ideal y la frecuencia aparente por aliasing.
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
    correlacion_cruzada, autocorrelacion_fft,
    ajustar_escala, escalar, ajustar_escalado, ajustar_knn, ajustar_lda, ajustar_logistica, predecir, probabilidades,
    pliegues, pliegues_estratificados, validacion_cruzada, matriz_confusion, exactitud, metricas_por_clase,
    curva_roc, auc_roc, frecuencias_modales, caracteristicas_evento, respuesta_libre, caracteristicas_por_ventanas,
    raiz_biseccion, raiz_newton, raiz_secante,
    ecuacion_viga, raices_viga, frecuencias_viga, forma_modal_viga,
    derivada_K_cortante, sensibilidad_frecuencias, jacobiana_frecuencias_cortante, actualizar_rigideces,
    frf_1gdl, frf_1gdl_ri, psd_modal_1gdl, frecuencias_cortante, residuos_frecuencias, coste_frecuencias, puntos_iniciales,
    red_sensores, reticulado_plano, adyacencia_barras, longitudes_barras, grafo_de_matriz, laplaciana,
    respuesta_libre_1gdl, fuerza_multiseno, rms_respuesta_multiseno, aceleracion_1gdl,
    descriptores_temporales, cuantizar, frecuencia_aparente,
    dft, periodograma, espectro_amplitud, potencia_bandas, psd_normalizada, anpsd, colorear

include("espectral.jl")
include("lectura.jl")
include("estructuradas.jl")
include("modal.jl")
include("senales.jl")
include("clasificacion.jl")
include("raices.jl")
include("viga.jl")
include("sensibilidad.jl")
include("optimizacion.jl")
include("grafos.jl")
include("edos.jl")
include("muestreo.jl")
include("espectro.jl")

export lscf_coeficientes, lscf_polos, polos_estables
include("lscf.jl")

export matriz_espectral, fdd, mac_complejo, efdd_modo, respuesta_modal
include("fdd.jl")

export correlaciones_salidas, toeplitz_bloques, ssi_cov_preparar, ssi_cov_desde_correlaciones, ssi_cov_orden, modos_estables
include("ssicov.jl")

export semiespectro, corregir_amortiguamiento_exponencial
include("semiespectro.jl")

end # module
