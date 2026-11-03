# Decremento aleatorio (M7.4): estimación de correlaciones y de sus derivadas por simple promediado de segmentos.

"""
    decremento_aleatorio(x, y, nlag; condicion=:nivel, a=0.0, v=0.0, fs=1.0) -> NamedTuple

Firma de decremento aleatorio (*random decrement*, M7.4) de la serie `x` condicionada a un suceso de la serie
`y` (de la misma longitud): se promedian los `nlag + 1` valores de `x` que siguen a cada instante `k` en que
`y` cumple la condición de disparo, `D[j+1] = media_k x[k + j]` para `j = 0, …, nlag`. Con `y = x` se obtiene la firma
automática. Devuelve `d` (la firma), `t` (retardos en s, `j/fs`) y `disparos` (número de segmentos promediados;
cuantos más, menos ruido).

`condicion` elige el suceso, con las cuatro que recoge la tabla de M7.4:

| `condicion` | Se dispara cuando… | La firma es proporcional a… |
|---|---|---|
| `:nivel` | `y` cruza el nivel `a` (en cualquier sentido) | la correlación `R(τ)` |
| `:punto_positivo` | `y[k] > a` | la correlación `R(τ)` |
| `:velocidad` | la velocidad de `y` cruza `v` | menos la derivada de la correlación, `-Ṙ(τ)` |
| `:velocidad_positiva` | la velocidad de `y` es mayor que `v` | menos la derivada de la correlación, `-Ṙ(τ)` |

Con `R(τ) = E[x(t+τ)y(t)]` la derivada entra con signo negativo, porque `Cov(x(t+τ), ẏ(t)) = -Ṙ(τ)`: se ha comprobado numéricamente con un oscilador. La velocidad de `y` es la diferencia hacia atrás `(y[k] - y[k-1])·fs`. Para procesos gaussianos y estacionarios, la
firma tiende a la correlación (o a su derivada) con el número de disparos. Se descartan los disparos que no dejan
`nlag` muestras posteriores. Lanza `ArgumentError` si no hay ningún disparo.
"""
function decremento_aleatorio(x::AbstractVector{<:Real}, y::AbstractVector{<:Real}, nlag::Integer;
                              condicion::Symbol=:nivel, a::Real=0.0, v::Real=0.0, fs::Real=1.0)
    N = length(x)
    length(y) == N || throw(DimensionMismatch("x e y deben tener la misma longitud"))
    0 <= nlag < N - 1 || throw(ArgumentError("nlag debe estar entre 0 y N-2"))
    fs > 0 || throw(ArgumentError("fs debe ser positiva"))
    condicion in (:nivel, :punto_positivo, :velocidad, :velocidad_positiva) ||
        throw(ArgumentError("condición desconocida: $condicion"))
    vel(k) = (y[k] - y[k-1]) * fs
    dispara = if condicion === :nivel
        k -> (y[k-1] - a) * (y[k] - a) < 0 || y[k] == a != y[k-1]
    elseif condicion === :punto_positivo
        k -> y[k] > a
    elseif condicion === :velocidad
        k -> k >= 3 && (vel(k-1) - v) * (vel(k) - v) < 0
    else
        k -> k >= 2 && vel(k) > v
    end
    d = zeros(nlag + 1)
    n = 0
    for k in 2:N-nlag
        dispara(k) || continue
        for j in 0:nlag
            d[j+1] += x[k+j]
        end
        n += 1
    end
    n > 0 || throw(ArgumentError("ningún instante cumple la condición de disparo; cambia `a` o `v`"))
    d ./= n
    return (d=d, t=collect(0:nlag) ./ fs, disparos=n)
end

"""
    correlacion_insesgada(x, kmax) -> Vector{Float64}

Autocorrelación muestral **insesgada** `r_k = (1/(N-k)) Σ_{t=1}^{N-k} (x_t-x̄)(x_{t+k}-x̄)` para `k = 0, …, kmax` (M7.4).
Su valor esperado es la correlación verdadera, pero a retardos grandes se promedian pocos productos y el
error aleatorio crece; además la matriz de Toeplitz que forma no tiene por qué ser semidefinida positiva. Por eso
[`autocorrelacion`](@ref), que divide por `N`, es la que usan los métodos de subespacios.
"""
function correlacion_insesgada(x::AbstractVector{<:Real}, kmax::Integer)
    N = length(x)
    0 <= kmax < N || throw(ArgumentError("kmax debe estar entre 0 y N-1"))
    z = x .- sum(x) / N
    return [sum(z[t] * z[t+k] for t in 1:N-k) / (N - k) for k in 0:kmax]
end
