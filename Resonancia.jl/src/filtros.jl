# Filtros digitales FIR e IIR (M4.2), sin dependencias: solo la biblioteca estándar.
# Un filtro FIR se guarda como sus coeficientes `b`; uno IIR, como una cascada de secciones de segundo orden
# (SOS), que es la forma numéricamente robusta: con cortes muy bajos frente a `fs` (p. ej. 0,5 Hz a 500 Hz) la forma
# directa de orden alto pierde precisión.

"""
    FIR(b)

Filtro de respuesta impulsional finita (M4.2) con coeficientes `b`: `y[n] = Σ b[k]·x[n-k]`. Se construye con
`filtro_fir`. Si es simétrico, su fase es lineal (retardo constante de `(length(b)-1)/2` muestras).
"""
struct FIR
    b::Vector{Float64}
end

"""
    IIR(sos)

Filtro de respuesta impulsional infinita (M4.2) como cascada de secciones de segundo orden. Cada fila de `sos`
es `[b0 b1 b2 1 a1 a2]` y la sección implementa `H(z) = (b0 + b1 z⁻¹ + b2 z⁻²)/(1 + a1 z⁻¹ + a2 z⁻²)`.
Se construye con `filtro_butterworth`.
"""
struct IIR
    sos::Matrix{Float64}
end

_sinc(x) = x == 0 ? 1.0 : sin(π * x) / (π * x)

# Ventana simétrica de L puntos (la que se usa para diseñar filtros): la periódica de L-1 puntos más su primer valor.
function _ventana_simetrica(nombre::Symbol, L::Integer)
    L == 1 && return [1.0]
    w = ventana(nombre, L - 1)
    push!(w, w[1])
    return w
end

"""
    filtro_fir(ntaps, fc, fs; tipo=:pasabajos, ventana=:hamming) -> FIR

Diseña un filtro FIR de `ntaps` coeficientes por el método de la ventana (M4.2): la respuesta impulsional ideal (una
sinc) truncada y multiplicada por una ventana simétrica (`:hamming`, `:hann`, `:blackman`, `:rectangular`…).
`tipo` es `:pasabajos`, `:pasaaltos`, `:pasabanda` o `:rechazabanda`; `fc` es la frecuencia de corte (Hz), o
una tupla `(f1, f2)` para los tipos de banda. El filtro queda normalizado a ganancia 1 en la banda de paso. Los
tipos `:pasaaltos` y `:rechazabanda` exigen `ntaps` impar. La anchura de la transición es del orden de
`fs/ntaps` multiplicada por una constante que depende de la ventana (unos 3,3 para Hamming): más coeficientes,
transición más estrecha y más retardo.
"""
function filtro_fir(ntaps::Integer, fc, fs::Real; tipo::Symbol=:pasabajos, ventana::Symbol=:hamming)
    ntaps >= 3 || throw(ArgumentError("ntaps debe ser al menos 3"))
    fs > 0 || throw(ArgumentError("fs debe ser positiva"))
    tipo in (:pasabajos, :pasaaltos, :pasabanda, :rechazabanda) || throw(ArgumentError("tipo desconocido: $tipo"))
    if tipo in (:pasaaltos, :rechazabanda) && iseven(ntaps)
        throw(ArgumentError("para $tipo ntaps debe ser impar (un filtro de longitud par no puede dejar pasar Nyquist)"))
    end
    bordes = fc isa Tuple ? collect(Float64.(fc)) : [Float64(fc)]
    banda = tipo in (:pasabanda, :rechazabanda)
    length(bordes) == (banda ? 2 : 1) || throw(ArgumentError("$tipo necesita " * (banda ? "(f1, f2)" : "una sola frecuencia de corte")))
    all(0 .< bordes .< fs / 2) || throw(ArgumentError("las frecuencias de corte deben estar entre 0 y fs/2"))
    banda && !(bordes[1] < bordes[2]) && throw(ArgumentError("hace falta f1 < f2"))
    n = collect(0:ntaps-1) .- (ntaps - 1) / 2
    pasabajos(f) = (2f / fs) .* _sinc.(2f / fs .* n)
    delta = Float64.(n .== 0)
    h = tipo === :pasabajos ? pasabajos(bordes[1]) :
        tipo === :pasaaltos ? delta .- pasabajos(bordes[1]) :
        tipo === :pasabanda ? pasabajos(bordes[2]) .- pasabajos(bordes[1]) :
        delta .- (pasabajos(bordes[2]) .- pasabajos(bordes[1]))
    h = h .* _ventana_simetrica(ventana, ntaps)
    f_ref = tipo === :pasabajos || tipo === :rechazabanda ? 0.0 : tipo === :pasaaltos ? fs / 2 : sum(bordes) / 2
    return FIR(h ./ abs(respuesta_frecuencia(FIR(h), f_ref, fs)))
end

# Prototipo analógico de Butterworth de orden N con frecuencia de corte 1 rad/s: sus polos están en el semicírculo
# izquierdo, separados por π/N.
_polos_butterworth(N) = [cis(π * (2k + N - 1) / (2N)) for k in 1:N]

# Transformación del prototipo (cero, polos, ganancia) al tipo de filtro y a las frecuencias analógicas `w`
# (rad/s, ya «prewarped»): un valor para pasabajos y pasaaltos, dos para los tipos de banda.
function _prototipo_a_analogico(N, tipo, w)
    pk = _polos_butterworth(N)
    if tipo === :pasabajos
        return ComplexF64[], w[1] .* pk, w[1]^N
    elseif tipo === :pasaaltos
        return zeros(ComplexF64, N), w[1] ./ pk, 1.0
    end
    B, w02 = w[2] - w[1], w[1] * w[2]
    if tipo === :pasabanda
        p = ComplexF64[]
        for q in pk
            d = sqrt(complex((B * q)^2 - 4w02))
            append!(p, ((B * q + d) / 2, (B * q - d) / 2))
        end
        return zeros(ComplexF64, N), p, B^N
    else # :rechazabanda
        p = ComplexF64[]
        for q in pk
            d = sqrt(complex(B^2 - 4 * q^2 * w02))
            append!(p, ((B + d) / (2q), (B - d) / (2q)))
        end
        return vcat(fill(im * sqrt(w02), N), fill(-im * sqrt(w02), N)), p, 1.0
    end
end

# Agrupa raíces en polinomios de segundo orden [1, c1, c2] (en z⁻¹): un par conjugado da un polinomio; dos reales,
# otro; si sobra una real, queda un polinomio de primer orden.
function _agrupar_raices(r; ordenar_por_modulo=false)
    tol(q) = 1e-9 * max(1.0, abs(q))
    complejas = [q for q in r if imag(q) > tol(q)]
    reales = sort([real(q) for q in r if abs(imag(q)) <= tol(q)])
    ordenar_por_modulo && sort!(complejas; by=abs)
    pol = [[1.0, -2real(q), abs2(q)] for q in complejas]
    i, j = 1, length(reales)
    while i < j
        push!(pol, [1.0, -(reales[i] + reales[j]), reales[i] * reales[j]])
        i += 1
        j -= 1
    end
    i == j && push!(pol, [1.0, -reales[i], 0.0])
    return pol
end

"""
    filtro_butterworth(orden, fc, fs; tipo=:pasabajos) -> IIR

Filtro IIR de Butterworth (M4.2): respuesta de módulo máximamente plana en la banda de paso,
`|H|² = 1/(1 + (f/fc)^(2·orden))` en un pasabajos, con −3,01 dB en la frecuencia de corte `fc`. `tipo` es `:pasabajos`,
`:pasaaltos`, `:pasabanda` o `:rechazabanda`; para los dos últimos, `fc = (f1, f2)` y el filtro tiene orden total
`2·orden`. Se parte del prototipo analógico, se transforma al tipo pedido y se pasa al plano `z` con la transformación
bilineal, deformando las frecuencias de corte («prewarping») para que el corte digital caiga justo en `fc`. La
pendiente asintótica es de `6·orden` dB por octava (20·orden dB por década).
"""
function filtro_butterworth(orden::Integer, fc, fs::Real; tipo::Symbol=:pasabajos)
    orden >= 1 || throw(ArgumentError("el orden debe ser al menos 1"))
    fs > 0 || throw(ArgumentError("fs debe ser positiva"))
    tipo in (:pasabajos, :pasaaltos, :pasabanda, :rechazabanda) || throw(ArgumentError("tipo desconocido: $tipo"))
    bordes = fc isa Tuple ? collect(Float64.(fc)) : [Float64(fc)]
    banda = tipo in (:pasabanda, :rechazabanda)
    length(bordes) == (banda ? 2 : 1) || throw(ArgumentError("$tipo necesita " * (banda ? "(f1, f2)" : "una sola frecuencia de corte")))
    all(0 .< bordes .< fs / 2) || throw(ArgumentError("las frecuencias de corte deben estar entre 0 y fs/2"))
    banda && !(bordes[1] < bordes[2]) && throw(ArgumentError("hace falta f1 < f2"))
    fs2 = 2fs
    w = fs2 .* tan.(π .* bordes ./ fs)                   # frecuencias analógicas deformadas
    z, p, k = _prototipo_a_analogico(orden, tipo, w)
    zd = vcat((fs2 .+ z) ./ (fs2 .- z), fill(-1.0 + 0im, length(p) - length(z)))   # ceros en infinito → z = −1
    pd = (fs2 .+ p) ./ (fs2 .- p)
    kd = k * real(prod(fs2 .- z; init=1.0 + 0im) / prod(fs2 .- p))
    num, den = _agrupar_raices(zd), _agrupar_raices(pd; ordenar_por_modulo=true)
    nsec = max(length(num), length(den))
    sos = zeros(nsec, 6)
    for s in 1:nsec
        sos[s, 1:3] .= s <= length(num) ? num[s] : [1.0, 0.0, 0.0]
        sos[s, 4:6] .= s <= length(den) ? den[s] : [1.0, 0.0, 0.0]
    end
    sos[1, 1:3] .*= kd
    return IIR(sos)
end

"""
    respuesta_frecuencia(filtro, f, fs) -> Complex / Vector{ComplexF64}

Respuesta en frecuencia `H(e^{iω})`, con `ω = 2π f/fs`, del filtro (`FIR` o `IIR`) en la frecuencia `f` (Hz) o en cada
elemento de un vector de frecuencias. Su módulo es la ganancia; en dB, `20·log10(abs(H))`; su argumento es el
desfase. Para un filtro aplicado con `filtrar_fase_cero`, la respuesta efectiva es `|H|²` y la fase, nula.
"""
function respuesta_frecuencia(f::FIR, fr::Real, fs::Real)
    zinv = cis(-2π * fr / fs)
    return sum(c * zinv^(n - 1) for (n, c) in enumerate(f.b))
end
function respuesta_frecuencia(f::IIR, fr::Real, fs::Real)
    zinv = cis(-2π * fr / fs)
    H = 1.0 + 0im
    for s in axes(f.sos, 1)
        b0, b1, b2, _, a1, a2 = f.sos[s, :]
        H *= (b0 + b1 * zinv + b2 * zinv^2) / (1 + a1 * zinv + a2 * zinv^2)
    end
    return H
end
respuesta_frecuencia(f::Union{FIR,IIR}, fr::AbstractVector, fs::Real) = [respuesta_frecuencia(f, q, fs) for q in fr]

# Retardo de grupo de un polinomio en z⁻¹ de coeficientes c, en muestras: Re(Σ n·c_n·e^{-iωn} / Σ c_n·e^{-iωn}).
function _tau_polinomio(c, ω)
    zinv = cis(-ω)
    return real(sum((n - 1) * q * zinv^(n - 1) for (n, q) in enumerate(c)) / sum(q * zinv^(n - 1) for (n, q) in enumerate(c)))
end

"""
    retardo_grupo(filtro, f, fs) -> Float64 / Vector{Float64}

Retardo de grupo `−dφ/dω` del filtro (en **segundos**) en la frecuencia `f` (Hz) o en un vector de frecuencias: lo que
se retrasa una pequeña envolvente centrada en `f`. En un FIR simétrico es constante, `(ntaps-1)/(2·fs)`; en un IIR
varía con la frecuencia y crece hacia el corte (la distorsión de fase del filtrado causal). Cerca de un cero de la
respuesta (p. ej. el centro de un rechazabanda) no está definido.
"""
function retardo_grupo(f::FIR, fr::Real, fs::Real)
    return _tau_polinomio(f.b, 2π * fr / fs) / fs
end
function retardo_grupo(f::IIR, fr::Real, fs::Real)
    ω = 2π * fr / fs
    return sum(_tau_polinomio(f.sos[s, 1:3], ω) - _tau_polinomio(f.sos[s, 4:6], ω) for s in axes(f.sos, 1)) / fs
end
retardo_grupo(f::Union{FIR,IIR}, fr::AbstractVector, fs::Real) = [retardo_grupo(f, q, fs) for q in fr]

# Cascada de secciones en forma directa II transpuesta. Con `estacionario=true` el estado inicial es el de régimen
# permanente para una entrada constante igual a x[1] (evita el transitorio de arranque).
function _filtrar_sos(sos, x; estacionario=false)
    y = Float64.(x)
    for s in axes(sos, 1)
        b0, b1, b2, _, a1, a2 = sos[s, :]
        z1 = z2 = 0.0
        if estacionario
            g = (b0 + b1 + b2) / (1 + a1 + a2)
            z1, z2 = (g - b0) * y[1], (b2 - a2 * g) * y[1]
        end
        for n in eachindex(y)
            xn = y[n]
            yn = b0 * xn + z1
            z1 = b1 * xn - a1 * yn + z2
            z2 = b2 * xn - a2 * yn
            y[n] = yn
        end
    end
    return y
end

function _convolucion_causal(b, x)
    y = zeros(length(x))
    for n in eachindex(x), k in 1:min(length(b), n)
        y[n] += b[k] * x[n-k+1]
    end
    return y
end

"""
    filtrar(filtro, x; compensar=false) -> Vector{Float64}

Filtrado **causal** de `x` con un `FIR` o un `IIR` (M4.2): cada muestra de salida usa solo muestras de entrada
pasadas y presentes, con estado inicial nulo. Retrasa la señal (el retardo de grupo del filtro) y produce un
transitorio al inicio. Equivale a `filt` de DSP.jl y de SciPy. Con `compensar=true` (solo para `FIR` de fase lineal)
la salida se adelanta `(ntaps-1)/2` muestras para alinearla con la entrada: es el «fase cero» de un FIR,
con las mismas muestras de salida pero sin elevar el módulo al cuadrado.
"""
function filtrar(f::IIR, x::AbstractVector{<:Real})
    return _filtrar_sos(f.sos, x)
end
function filtrar(f::FIR, x::AbstractVector{<:Real}; compensar::Bool=false)
    y = _convolucion_causal(f.b, x)
    compensar || return y
    isodd(length(f.b)) || throw(ArgumentError("compensar exige ntaps impar"))
    d = (length(f.b) - 1) ÷ 2
    return vcat(y[d+1:end], zeros(d))
end

"""
    filtrar_fase_cero(filtro, x) -> Vector{Float64}

Filtrado de **fase cero** (M4.2): se filtra hacia delante, se invierte la salida, se vuelve a filtrar y se invierte
de nuevo. El retardo de la primera pasada se cancela con la segunda, de modo que la salida no está retrasada, y la
respuesta efectiva es `H(e^{iω})·H(e^{-iω}) = |H(e^{iω})|²`: **la atenuación en dB se duplica** y el orden efectivo
también (la pendiente asintótica pasa de `6·orden` a `12·orden` dB por octava, pero **no es** un Butterworth de orden
doble: su módulo es `1/(1 + x^(2·orden))`, con `x = f/fc` en un pasabajos, y no `1/√(1 + x^(4·orden))`). Además, la
frecuencia de corte efectiva (−3 dB) deja de ser `fc`: en `fc` la ganancia es −6,02 dB, y el punto de −3 dB queda en
`x = (√2 − 1)^(1/(2·orden))` (≈ 0,896 `fc` para orden 4 en un pasabajos; su inverso, ≈ 1,116 `fc`, en un pasaaltos).
Hay que tenerlo en cuenta al elegir `fc` si se va a usar fase cero. Solo vale para análisis diferido, porque usa muestras futuras. Para reducir los transitorios de los extremos se extiende
la señal por reflexión impar y se parte del estado estacionario. Equivale a `filtfilt` de DSP.jl y de SciPy.
"""
function filtrar_fase_cero(f::Union{FIR,IIR}, x::AbstractVector{<:Real})
    N = length(x)
    N >= 2 || throw(ArgumentError("hacen falta al menos 2 muestras"))
    orden = f isa IIR ? 2 * size(f.sos, 1) + 1 : length(f.b)
    npad = min(3orden, N - 1)
    xf = Float64.(x)
    ext = vcat(2xf[1] .- xf[npad+1:-1:2], xf, 2xf[end] .- xf[end-1:-1:end-npad])
    pasada(v) = f isa IIR ? _filtrar_sos(f.sos, v; estacionario=true) : _convolucion_causal(f.b, v)
    y = reverse(pasada(reverse(pasada(ext))))
    return y[npad+1:npad+N]
end

"""
    diezmar(x, q) -> Vector{Float64}

Reduce `q` veces la frecuencia de muestreo de `x` (M4.2, M4.3): primero un filtro FIR antialiasing de fase cero (Hamming,
`20q+1` coeficientes, corte al 80 % de la nueva frecuencia de Nyquist) y después se toma una muestra de cada `q`. Quedarse
con una de cada `q` sin filtrar **pliega** (aliasing) al rango útil las componentes por encima de `fs/(2q)`. Los
`10q` primeros y últimos instantes de la salida tienen un transitorio por los extremos del registro.
"""
function diezmar(x::AbstractVector{<:Real}, q::Integer)
    q >= 1 || throw(ArgumentError("q debe ser al menos 1"))
    q == 1 && return Float64.(x)
    h = filtro_fir(20q + 1, 0.4 / q, 1.0; tipo=:pasabajos, ventana=:hamming)
    return filtrar(h, x; compensar=true)[1:q:end]
end
