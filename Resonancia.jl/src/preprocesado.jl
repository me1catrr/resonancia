# Preprocesado de registros (M4.3). La detección de huecos, planos y valores atípicos (Hampel, MAD)
# es limpieza de datos y se trata en J2.3; aquí solo lo que es propio de la señal.

"""
    quitar_tendencia(x, grado=1) -> (y, tendencia)

Resta a `x` el polinomio de `grado` que mejor lo ajusta por mínimos cuadrados (M4.3): `grado = 0` quita solo el offset
(la media), `1` una recta (deriva lineal), `2` una parábola. El ajuste se hace sobre una abscisa normalizada a `[-1, 1]`
para que esté bien condicionado. Devuelve la señal sin tendencia `y = x − tendencia` y la `tendencia` ajustada.
Si la deriva real no es polinómica, no se elimina del todo: eso se resuelve con un filtro pasa-altos.
"""
function quitar_tendencia(x::AbstractVector{<:Real}, grado::Integer=1)
    N = length(x)
    grado >= 0 || throw(ArgumentError("el grado no puede ser negativo"))
    N > grado || throw(ArgumentError("hacen falta más de $grado muestras para ajustar un polinomio de grado $grado"))
    s = N == 1 ? [0.0] : collect(range(-1, 1; length=N))
    A = [s[i]^j for i in 1:N, j in 0:grado]
    tendencia = A * (A \ Float64.(x))
    return Float64.(x) .- tendencia, tendencia
end

"""
    interpolar_uniforme(t, x, fs; tolerancia=1.5) -> (tu, xu, hueco)

Remuestrea un registro de instantes `t` crecientes (posiblemente irregulares o con huecos) a una rejilla uniforme de
`fs` Hz entre `t[1]` y `t[end]` por interpolación lineal (M4.3). Las muestras con `NaN` se descartan antes. `hueco[k]`
es `true` si el punto `tu[k]` cae entre dos muestras originales separadas más de `tolerancia/fs` s: ahí el valor es
una recta inventada, no una medida, y conviene excluirlo o no calcular espectros que lo atraviesen. La interpolación
lineal atenúa las frecuencias altas; para **cambiar** la frecuencia de muestreo de un registro ya uniforme hay que
filtrar antes (antialiasing).
"""
function interpolar_uniforme(t::AbstractVector{<:Real}, x::AbstractVector{<:Real}, fs::Real; tolerancia::Real=1.5)
    length(t) == length(x) || throw(ArgumentError("t y x deben tener la misma longitud"))
    fs > 0 || throw(ArgumentError("fs debe ser positiva"))
    ok = findall(i -> isfinite(t[i]) && isfinite(x[i]), eachindex(t))
    length(ok) >= 2 || throw(ArgumentError("hacen falta al menos 2 muestras válidas"))
    tt, xx = Float64.(t[ok]), Float64.(x[ok])
    all(diff(tt) .> 0) || throw(ArgumentError("los instantes deben ser estrictamente crecientes"))
    tu = collect(tt[1]:1/fs:tt[end])
    xu = similar(tu)
    hueco = falses(length(tu))
    j = 1
    for (k, τ) in enumerate(tu)
        while j < length(tt) - 1 && tt[j+1] < τ
            j += 1
        end
        a, b = tt[j], tt[j+1]
        xu[k] = xx[j] + (xx[j+1] - xx[j]) * (τ - a) / (b - a)
        hueco[k] = (b - a) > tolerancia / fs
    end
    return tu, xu, hueco
end
