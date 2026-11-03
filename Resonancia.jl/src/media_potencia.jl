# Método de la media potencia sobre un espectro de amplitud (M4.1 y M7.2).

"""
    amortiguamiento_media_potencia(f, A) -> NamedTuple

Estima la frecuencia y la razón de amortiguamiento de un modo aislado con el **método de la media potencia**
(M7.2) a partir del módulo `A` de una respuesta o de una FRF, tabulado en las frecuencias `f` (Hz, crecientes y
equiespaciadas o no). Toma el máximo de `A`, busca a cada lado los puntos donde `A` cae a `A_max/√2` (potencia mitad,
−3 dB) interpolando linealmente entre muestras y devuelve `fn` (la del máximo), `f1`, `f2` (los cruces) y
`zeta = (f2 - f1)/(2 fn)`, válida para amortiguamiento pequeño.

Necesita una rejilla en frecuencia **más fina que el ancho del pico** `2ζ fn`: con la resolución natural `1/T` de un
registro corto el ancho se sobrestima (el pico de la DFT queda limitado por la ventana, no por la estructura);
conviene rellenar con ceros para interpolar y comprobar que `1/T` es mucho menor que `2ζ fn`.
Lanza `ArgumentError` si el máximo está en un extremo o si el espectro no baja de la media potencia a algún lado.
"""
function amortiguamiento_media_potencia(f::AbstractVector{<:Real}, A::AbstractVector{<:Real})
    length(f) == length(A) || throw(DimensionMismatch("f y A deben tener la misma longitud"))
    length(f) >= 3 || throw(ArgumentError("hacen falta al menos 3 puntos"))
    k = argmax(A)
    1 < k < length(A) || throw(ArgumentError("el máximo está en un extremo del espectro"))
    h = A[k] / √2
    i = k
    while i > 1 && A[i] > h
        i -= 1
    end
    A[i] <= h || throw(ArgumentError("el espectro no baja a la media potencia por la izquierda"))
    j = k
    while j < length(A) && A[j] > h
        j += 1
    end
    A[j] <= h || throw(ArgumentError("el espectro no baja a la media potencia por la derecha"))
    f1 = f[i] + (h - A[i]) * (f[i+1] - f[i]) / (A[i+1] - A[i])
    f2 = f[j-1] + (A[j-1] - h) * (f[j] - f[j-1]) / (A[j-1] - A[j])
    return (fn=f[k], f1=f1, f2=f2, zeta=(f2 - f1) / (2 * f[k]))
end
