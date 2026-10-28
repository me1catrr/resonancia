# Clasificación supervisada sencilla (J2.8): k-NN, análisis discriminante lineal y regresión logística,
# validación cruzada y métricas. Solo usa `LinearAlgebra`; el barajado de los datos se delega en quien
# llama (se pasa una permutación `perm`, p. ej. `randperm(Xoshiro(1), n)`), de modo que no hay
# generadores aleatorios ocultos y los resultados son reproducibles.

# ---------------------------------------------------------------------------
# Escalado
# ---------------------------------------------------------------------------

"""
    ajustar_escala(X) -> (mu, sigma)

Media y desviación típica muestral de cada columna de `X` (muestras × características). Una columna
constante recibe `sigma = 1` para no dividir por cero.
"""
function ajustar_escala(X::AbstractMatrix{<:Real})
    n = size(X, 1)
    n >= 2 || throw(ArgumentError("hacen falta al menos dos muestras"))
    mu = vec(sum(X, dims=1)) ./ n
    sigma = [sqrt(sum(abs2, X[:, j] .- mu[j]) / (n - 1)) for j in axes(X, 2)]
    sigma[sigma .== 0] .= 1.0
    return mu, sigma
end

"""
    escalar(X, mu, sigma) -> Matrix

Resta `mu` y divide por `sigma` en cada columna de `X`. Los parámetros se calculan **solo con los datos
de entrenamiento** (`ajustar_escala`) y se aplican igual al conjunto de prueba.
"""
escalar(X::AbstractMatrix{<:Real}, mu::AbstractVector, sigma::AbstractVector) = (X .- mu') ./ sigma'

# ---------------------------------------------------------------------------
# Modelos
# ---------------------------------------------------------------------------

"""
    ModeloEscalado(mu, sigma, modelo)

Envuelve un modelo entrenado con características estandarizadas: `predecir` y `probabilidades` escalan
antes de llamar al modelo interno. Se crea con [`ajustar_escalado`](@ref).
"""
struct ModeloEscalado{M}
    mu::Vector{Float64}
    sigma::Vector{Float64}
    modelo::M
end

"""
    ajustar_escalado(ajustar, X, y) -> ModeloEscalado

Estandariza `X` con sus propias medias y desviaciones, entrena con `ajustar(Z, y)` y devuelve el modelo
con el escalado incorporado. Usado dentro de la validación cruzada evita la **fuga de información**: el
escalado se calcula en cada pliegue solo con los datos de entrenamiento.
"""
function ajustar_escalado(ajustar, X::AbstractMatrix{<:Real}, y)
    mu, sigma = ajustar_escala(X)
    return ModeloEscalado(mu, sigma, ajustar(escalar(X, mu, sigma), y))
end

"""
    KNN

Modelo k vecinos más próximos (distancia euclídea). Se crea con [`ajustar_knn`](@ref).
"""
struct KNN{T}
    X::Matrix{Float64}
    y::Vector{T}
    clases::Vector{T}
    k::Int
end

"""
    ajustar_knn(X, y; k=5) -> KNN

«Entrena» un clasificador de `k` vecinos: solo guarda los datos (X: muestras × características).
La predicción es la clase más votada entre los `k` vecinos más próximos; en un empate gana la clase
cuyos vecinos están, en conjunto, más cerca. Conviene estandarizar antes las características.
"""
function ajustar_knn(X::AbstractMatrix{<:Real}, y::AbstractVector; k::Integer=5)
    size(X, 1) == length(y) || throw(ArgumentError("X e y deben tener el mismo número de muestras"))
    1 <= k <= length(y) || throw(ArgumentError("k debe estar entre 1 y el número de muestras"))
    return KNN(Matrix{Float64}(X), collect(y), sort(unique(y)), Int(k))
end

"""
    LDA

Análisis discriminante lineal (covarianza común a todas las clases). Se crea con [`ajustar_lda`](@ref).
"""
struct LDA{T}
    clases::Vector{T}
    medias::Matrix{Float64}      # clases × características
    Sinv::Matrix{Float64}        # inversa de la covarianza común
    logprior::Vector{Float64}
end

"""
    ajustar_lda(X, y; reg=1e-8) -> LDA

Estima la media de cada clase y la covarianza común (combinada, con `n - c` grados de libertad); `reg`
se suma a la diagonal (relativa a su traza media) por si la matriz fuese casi singular.
"""
function ajustar_lda(X::AbstractMatrix{<:Real}, y::AbstractVector; reg::Real=1e-8)
    n, p = size(X)
    n == length(y) || throw(ArgumentError("X e y deben tener el mismo número de muestras"))
    clases = sort(unique(y))
    c = length(clases)
    n > c || throw(ArgumentError("hay menos muestras que clases"))
    medias = zeros(c, p)
    S = zeros(p, p)
    prior = zeros(c)
    for (i, cl) in enumerate(clases)
        Xi = Matrix{Float64}(X[y .== cl, :])
        medias[i, :] = vec(sum(Xi, dims=1)) ./ size(Xi, 1)
        D = Xi .- medias[i:i, :]
        S .+= D' * D
        prior[i] = size(Xi, 1) / n
    end
    S ./= (n - c)
    S += (reg * tr(S) / p) * I
    return LDA(clases, medias, Matrix(inv(Symmetric(S))), log.(prior))
end

"""
    Logistica

Regresión logística binaria. Se crea con [`ajustar_logistica`](@ref).
"""
struct Logistica
    beta::Vector{Float64}        # término independiente y coeficientes
    iteraciones::Int
end

"""
    ajustar_logistica(X, y; lambda=1e-6, maxiter=100, tol=1e-10) -> Logistica

Ajusta `P(y = 1 | x) = 1/(1 + exp(-(β₀ + βᵀx)))` por mínimos cuadrados ponderados iterados (IRLS, que es el
método de Newton), con `y` en {0, 1} (o `Bool`). `lambda` penaliza los coeficientes (no el término
independiente): evita que diverjan cuando las clases son perfectamente separables.
"""
function ajustar_logistica(X::AbstractMatrix{<:Real}, y::AbstractVector; lambda::Real=1e-6, maxiter::Integer=100, tol::Real=1e-10)
    n, p = size(X)
    n == length(y) || throw(ArgumentError("X e y deben tener el mismo número de muestras"))
    yy = Float64.(y)
    all(v -> v == 0 || v == 1, yy) || throw(ArgumentError("y debe contener solo 0 y 1"))
    A = hcat(ones(n), Matrix{Float64}(X))
    pen = Diagonal([0.0; fill(float(lambda), p)])
    beta = zeros(p + 1)
    it = 0
    for k in 1:maxiter
        it = k
        eta = A * beta
        mu = @. 1 / (1 + exp(-eta))
        W = @. max(mu * (1 - mu), 1e-10)
        g = A' * (yy .- mu) .- pen * beta
        H = A' * (W .* A) + pen
        paso = H \ g
        beta += paso
        norm(paso, Inf) < tol && break
    end
    return Logistica(beta, it)
end

# ---------------------------------------------------------------------------
# Predicción
# ---------------------------------------------------------------------------

"""
    probabilidades(modelo, X) -> Matrix

Probabilidad (o fracción de votos, en k-NN) de cada clase para cada fila de `X`: una columna por clase,
en el orden de `modelo.clases`. En la regresión logística hay dos columnas, `P(y=0)` y `P(y=1)`.
"""
function probabilidades(m::KNN, X::AbstractMatrix{<:Real})
    P = zeros(size(X, 1), length(m.clases))
    idx = Dict(c => i for (i, c) in enumerate(m.clases))
    for i in axes(X, 1)
        d = [sqrt(sum(abs2, m.X[j, :] .- X[i, :])) for j in axes(m.X, 1)]
        for j in sortperm(d)[1:m.k]
            P[i, idx[m.y[j]]] += 1 / m.k
        end
    end
    return P
end

function probabilidades(m::LDA, X::AbstractMatrix{<:Real})
    c = size(m.medias, 1)
    L = zeros(size(X, 1), c)
    for i in 1:c
        w = m.Sinv * m.medias[i, :]
        L[:, i] = Matrix{Float64}(X) * w .- 0.5 * dot(m.medias[i, :], w) .+ m.logprior[i]
    end
    L .-= maximum(L, dims=2)
    P = exp.(L)
    return P ./ sum(P, dims=2)
end

function probabilidades(m::Logistica, X::AbstractMatrix{<:Real})
    eta = m.beta[1] .+ Matrix{Float64}(X) * m.beta[2:end]
    p1 = 1 ./ (1 .+ exp.(-eta))
    return hcat(1 .- p1, p1)
end

probabilidades(m::ModeloEscalado, X::AbstractMatrix{<:Real}) = probabilidades(m.modelo, escalar(X, m.mu, m.sigma))

"""
    predecir(modelo, X) -> Vector

Clase predicha para cada fila de `X`. En [`KNN`](@ref) desempata por distancia total; en [`LDA`](@ref) toma la
clase de mayor probabilidad a posteriori y en [`Logistica`](@ref) devuelve 0 o 1 con umbral 0,5.
"""
function predecir(m::KNN, X::AbstractMatrix{<:Real})
    P = probabilidades(m, X)
    out = similar(m.clases, size(X, 1))
    for i in axes(X, 1)
        mejores = findall(==(maximum(P[i, :])), P[i, :])
        if length(mejores) == 1
            out[i] = m.clases[mejores[1]]
        else  # empate: gana la clase con los vecinos más cercanos en conjunto
            d = [sqrt(sum(abs2, m.X[j, :] .- X[i, :])) for j in axes(m.X, 1)]
            vecinos = sortperm(d)[1:m.k]
            tot = [sum(d[j] for j in vecinos if m.y[j] == m.clases[b]) for b in mejores]
            out[i] = m.clases[mejores[argmin(tot)]]
        end
    end
    return out
end

function predecir(m::LDA, X::AbstractMatrix{<:Real})
    P = probabilidades(m, X)
    return [m.clases[argmax(P[i, :])] for i in axes(P, 1)]
end

predecir(m::Logistica, X::AbstractMatrix{<:Real}) = Int.(probabilidades(m, X)[:, 2] .>= 0.5)
predecir(m::ModeloEscalado, X::AbstractMatrix{<:Real}) = predecir(m.modelo, escalar(X, m.mu, m.sigma))

# ---------------------------------------------------------------------------
# Validación cruzada
# ---------------------------------------------------------------------------

"""
    pliegues(n, k; perm=1:n) -> Vector{Vector{Int}}

Reparte las `n` muestras en `k` pliegues (listas de índices de **prueba**) recorriendo la permutación
`perm`: el pliegue `j` toma `perm[j], perm[j+k], …`. Los tamaños difieren como mucho en uno.
"""
function pliegues(n::Integer, k::Integer; perm::AbstractVector{<:Integer}=1:n)
    2 <= k <= n || throw(ArgumentError("k debe estar entre 2 y n"))
    sort(perm) == 1:n || throw(ArgumentError("perm debe ser una permutación de 1:n"))
    return [sort(collect(perm[j:k:n])) for j in 1:k]
end

"""
    pliegues_estratificados(y, k; perm=1:length(y)) -> Vector{Vector{Int}}

Como [`pliegues`](@ref) pero conservando en cada pliegue (casi) la misma proporción de cada clase de `y`:
recorre `perm` y asigna cíclicamente al pliegue siguiente los elementos de cada clase por separado.
Necesario cuando una clase es rara (p. ej. eventos).
"""
function pliegues_estratificados(y::AbstractVector, k::Integer; perm::AbstractVector{<:Integer}=1:length(y))
    n = length(y)
    2 <= k <= n || throw(ArgumentError("k debe estar entre 2 y n"))
    sort(perm) == 1:n || throw(ArgumentError("perm debe ser una permutación de 1:n"))
    out = [Int[] for _ in 1:k]
    sig = 0
    for cl in sort(unique(y))
        for i in perm
            y[i] == cl || continue
            push!(out[sig%k+1], i)
            sig += 1
        end
    end
    return sort!.(out)
end

"""
    validacion_cruzada(ajustar, X, y; k=5, perm=1:size(X,1), estratificada=true, salida=predecir) -> Vector | Matrix

Validación cruzada de `k` pliegues. En cada pliegue entrena con `ajustar(Xentrenamiento, yentrenamiento)`
(que devuelve un modelo; use [`ajustar_escalado`](@ref) para estandarizar sin fuga) y aplica `salida(modelo, Xprueba)`
a los datos reservados. Devuelve las salidas de **todas** las muestras, cada una obtenida con un modelo que
no la vio al entrenar (con `salida=predecir`, las clases predichas; con `salida=probabilidades`, una matriz).
"""
function validacion_cruzada(ajustar, X::AbstractMatrix{<:Real}, y::AbstractVector; k::Integer=5,
        perm::AbstractVector{<:Integer}=1:size(X, 1), estratificada::Bool=true, salida=predecir)
    n = size(X, 1)
    n == length(y) || throw(ArgumentError("X e y deben tener el mismo número de muestras"))
    folds = estratificada ? pliegues_estratificados(y, k; perm=perm) : pliegues(n, k; perm=perm)
    out = nothing
    for test in folds
        train = setdiff(1:n, test)
        s = salida(ajustar(X[train, :], y[train]), X[test, :])
        if out === nothing
            out = s isa AbstractMatrix ? zeros(eltype(s), n, size(s, 2)) : similar(s, n)
        end
        s isa AbstractMatrix ? (out[test, :] = s) : (out[test] = s)
    end
    return out
end

# ---------------------------------------------------------------------------
# Métricas
# ---------------------------------------------------------------------------

"""
    matriz_confusion(real, predicho; clases=sort(unique(real))) -> (C, clases)

Matriz de confusión `C[i, j]` = número de muestras de clase real `clases[i]` predichas como `clases[j]`.
"""
function matriz_confusion(real::AbstractVector, predicho::AbstractVector; clases=sort(unique(vcat(real, predicho))))
    length(real) == length(predicho) || throw(ArgumentError("real y predicho deben tener la misma longitud"))
    idx = Dict(c => i for (i, c) in enumerate(clases))
    C = zeros(Int, length(clases), length(clases))
    for (a, b) in zip(real, predicho)
        C[idx[a], idx[b]] += 1
    end
    return C, collect(clases)
end

"""
    exactitud(C) -> Float64

Fracción de aciertos: traza de la matriz de confusión entre el total.
"""
exactitud(C::AbstractMatrix) = sum(diag(C)) / sum(C)

"""
    metricas_por_clase(C) -> NamedTuple

Precisión (`C[j,j]` / suma de la columna `j`), exhaustividad (*recall*: `C[i,i]` / suma de la fila `i`) y F1
(media armónica) de cada clase, como vectores. Si una cantidad no está definida (0/0) vale 0.
"""
function metricas_por_clase(C::AbstractMatrix)
    div0(a, b) = b == 0 ? 0.0 : a / b
    prec = [div0(C[j, j], sum(C[:, j])) for j in axes(C, 1)]
    rec = [div0(C[i, i], sum(C[i, :])) for i in axes(C, 1)]
    f1 = [div0(2 * prec[i] * rec[i], prec[i] + rec[i]) for i in eachindex(prec)]
    return (precision=prec, exhaustividad=rec, f1=f1)
end

"""
    curva_roc(puntuacion, y) -> (fpr, tpr, umbrales)

Curva ROC para `y` en {0, 1} y una `puntuacion` (mayor = más probable la clase 1). Recorre los umbrales
de mayor a menor agrupando las puntuaciones iguales; empieza en (0, 0) y termina en (1, 1).
"""
function curva_roc(puntuacion::AbstractVector{<:Real}, y::AbstractVector)
    length(puntuacion) == length(y) || throw(ArgumentError("puntuacion e y deben tener la misma longitud"))
    yy = Float64.(y)
    P, N = sum(yy), sum(1 .- yy)
    (P > 0 && N > 0) || throw(ArgumentError("hacen falta muestras de las dos clases"))
    o = sortperm(puntuacion; rev=true)
    s, yo = puntuacion[o], yy[o]
    fpr, tpr, um = [0.0], [0.0], [Inf]
    tp = fp = 0.0
    for i in eachindex(s)
        tp += yo[i]
        fp += 1 - yo[i]
        if i == length(s) || s[i+1] != s[i]
            push!(fpr, fp / N); push!(tpr, tp / P); push!(um, s[i])
        end
    end
    return fpr, tpr, um
end

"""
    auc_roc(puntuacion, y) -> Float64

Área bajo la curva ROC (regla del trapecio). Equivale a la probabilidad de que una muestra positiva
reciba mayor puntuación que una negativa (contando los empates como 1/2).
"""
function auc_roc(puntuacion::AbstractVector{<:Real}, y::AbstractVector)
    fpr, tpr, _ = curva_roc(puntuacion, y)
    return sum((fpr[i+1] - fpr[i]) * (tpr[i+1] + tpr[i]) / 2 for i in 1:length(fpr)-1)
end

# ---------------------------------------------------------------------------
# Características de señales (J2.8)
# ---------------------------------------------------------------------------

"""
    frecuencias_modales(x, fs, bandas; nseg=1024, solape=0.5) -> Vector{Float64}

Frecuencia (Hz) del pico del espectro de Welch de `x` dentro de cada banda `(fmin, fmax)` de `bandas`,
refinada con una parábola ajustada a los logaritmos de los tres puntos del pico (la resolución de la FFT es
`fs/nseg`, pero el refinado da frecuencias mucho más finas).
"""
function frecuencias_modales(x::AbstractVector{<:Real}, fs::Real, bandas; nseg::Int=1024, solape::Real=0.5)
    f, P = psd_welch(x, fs; nseg=nseg, solape=solape)
    df = f[2] - f[1]
    out = Float64[]
    for (lo, hi) in bandas
        k = buscar_picos(f, P; fmin=lo, fmax=hi, n=1)[1]
        a, b, c = log(P[k-1]), log(P[k]), log(P[k+1])
        push!(out, f[k] + 0.5 * (a - c) / (a - 2b + c) * df)
    end
    return out
end

"""
    caracteristicas_evento(x) -> Vector{Float64}

Tres características temporales de una ventana de señal: `log₁₀` del valor eficaz (RMS), factor de cresta
(`máx|x| / RMS`) y curtosis en exceso (0 para una distribución normal; crece si hay picos aislados).
"""
function caracteristicas_evento(x::AbstractVector{<:Real})
    n = length(x)
    m = sum(x) / n
    rms = sqrt(sum(abs2, x) / n)
    s2 = sum(abs2, x .- m) / n
    k = sum((x .- m) .^ 4) / n / s2^2 - 3
    return [log10(rms), maximum(abs, x) / rms, k]
end

"""
    respuesta_libre(n, fs, t0, frecuencias, amplitudes, zeta) -> Vector{Float64}

Suma de respuestas libres amortiguadas de varios modos tras un impacto en `t0` s: para cada modo
`A e^{-ζωt} sin(ω_d t)` con `t = muestra/fs - t0` (cero antes del impacto), `ω = 2πf` y `ω_d = ω√(1-ζ²)`.
Sirve para fabricar eventos sintéticos de prueba.
"""
function respuesta_libre(n::Integer, fs::Real, t0::Real, frecuencias::AbstractVector, amplitudes::AbstractVector, zeta::Real)
    length(frecuencias) == length(amplitudes) || throw(ArgumentError("una amplitud por frecuencia"))
    y = zeros(n)
    for (f, A) in zip(frecuencias, amplitudes), i in 1:n
        t = (i - 1) / fs - t0
        t < 0 && continue
        w = 2π * f
        y[i] += A * exp(-zeta * w * t) * sin(w * sqrt(1 - zeta^2) * t)
    end
    return y
end

"""
    caracteristicas_por_ventanas(f, x, fs, seg_s) -> Matrix{Float64}

Aplica la función `f` (que recibe un tramo de `x` y devuelve un vector de características) a cada ventana
consecutiva (sin solape) de `seg_s` segundos de `x`, muestreada a `fs` Hz, y apila los resultados por filas: una fila
por ventana y una columna por característica. El resto final que no completa una ventana se descarta.
"""
function caracteristicas_por_ventanas(f, x::AbstractVector{<:Real}, fs::Real, seg_s::Real)
    m = round(Int, fs * seg_s)
    m >= 1 || throw(ArgumentError("la ventana debe tener al menos una muestra"))
    nv = length(x) ÷ m
    nv >= 1 || throw(ArgumentError("el registro es más corto que una ventana"))
    filas = [Float64.(f(view(x, (i-1)*m+1:i*m))) for i in 1:nv]
    return Matrix(reduce(hcat, filas)')
end
