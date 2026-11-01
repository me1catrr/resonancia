# Integración de aceleración (M4.4) y relación señal-ruido (M4.5).

"""
    integrar_trapecio(x, fs) -> Vector{Float64}

Integral acumulada de `x` (muestreada a `fs` Hz) por la regla del trapecio (M4.4), con valor inicial 0:
`v[k] = v[k-1] + (x[k-1] + x[k])/(2·fs)`. Tiene la misma longitud que `x`. Un offset `c` en la aceleración
produce en la velocidad una rampa `c·t`, y en el desplazamiento una parábola `c·t²/2`: por eso hay que quitar el
offset y la tendencia antes de integrar, y aun así la deriva de baja frecuencia obliga a filtrar (véase
`integrar_frecuencia`). El trapecio atenúa ligeramente las frecuencias altas (factor `(ωΔt/2)/tan(ωΔt/2)`).
"""
function integrar_trapecio(x::AbstractVector{<:Real}, fs::Real)
    fs > 0 || throw(ArgumentError("fs debe ser positiva"))
    v = zeros(length(x))
    for k in 2:length(x)
        v[k] = v[k-1] + (x[k-1] + x[k]) / (2fs)
    end
    return v
end

"""
    integrar_frecuencia(x, fs; fcorte, orden=1) -> Vector{Float64}

Integra `x` `orden` veces (1: aceleración → velocidad; 2: → desplazamiento) en el dominio de la frecuencia (M4.4):
cada coeficiente de la DFT se divide por `(iω)^orden`, con `ω = 2π f`, **salvo** los de frecuencia menor que `fcorte`
(Hz) y el de continua, que se anulan. Esa es la forma de evitar la deriva: la integral solo es fiable por encima de
`fcorte`, y lo que haya por debajo (offset, deriva, ruido) se descarta en lugar de amplificarse como `1/ω^orden`.
Supone que el registro es periódico (el último valor «enlaza» con el primero), así que conviene quitar antes la
tendencia. Con `orden = 1` el coeficiente de Nyquist se anula. Si `fcorte` es mayor que la frecuencia de interés,
también se pierde la señal buscada.
"""
function integrar_frecuencia(x::AbstractVector{<:Real}, fs::Real; fcorte::Real, orden::Integer=1)
    N = length(x)
    N >= 2 || throw(ArgumentError("hacen falta al menos 2 muestras"))
    fs > 0 || throw(ArgumentError("fs debe ser positiva"))
    fcorte >= 0 || throw(ArgumentError("fcorte no puede ser negativa"))
    orden in (1, 2) || throw(ArgumentError("orden debe ser 1 o 2"))
    X = dft(Float64.(x))
    for k in 0:N-1
        kk = k <= N ÷ 2 ? k : k - N
        f = abs(kk) * fs / N
        X[k+1] = (k == 0 || f < fcorte) ? 0.0im : X[k+1] / (im * 2π * kk * fs / N)^orden
    end
    return real.(conj.(dft(conj.(X)))) ./ N   # DFT inversa
end

"""
    snr_db(x, ruido) -> Float64

Relación señal-ruido en dB (M4.5): `10·log10(P_x/P_ruido)`, con la potencia de cada registro igual a su **varianza**
(la parte fluctuante: se ignora la media). `x` es la señal sola y `ruido` el ruido solo. Si solo se dispone de la
medida (señal + ruido) y de un registro del ruido de fondo, la señal se estima restando la potencia del ruido.
"""
function snr_db(x::AbstractVector{<:Real}, ruido::AbstractVector{<:Real})
    pot(v) = sum(abs2, v .- sum(v) / length(v)) / length(v)
    pn = pot(ruido)
    pn > 0 || throw(ArgumentError("el ruido tiene potencia nula"))
    return 10log10(pot(x) / pn)
end

"""
    snr_banda(f, P, Pruido, banda) -> Float64

Relación señal-ruido en dB **dentro de una banda** `(fa, fb)` (M4.5): `10·log10(∫P df / ∫Pruido df)`, con la PSD de
la medida `P` y la del ruido de fondo `Pruido` sobre la misma rejilla `f`. Es la medida pertinente cuando solo
interesa una banda (por ejemplo, la de los primeros modos): el SNR del registro completo puede ser muy distinto.
"""
function snr_banda(f::AbstractVector, P::AbstractVector, Pruido::AbstractVector, banda)
    pot, _ = potencia_bandas(f, P, [banda])
    potn, _ = potencia_bandas(f, Pruido, [banda])
    potn[1] > 0 || throw(ArgumentError("el ruido tiene potencia nula en la banda"))
    return 10log10(pot[1] / potn[1])
end

"""
    rms_ruido_banda(densidad, fa, fb) -> Float64

Valor eficaz del ruido de un sensor de densidad espectral plana en la banda `[fa, fb]` (M4.5):
`densidad·√(fb − fa)`. La `densidad` se da en unidades/√Hz (p. ej., 100 µg/√Hz); el resultado, en las unidades
de la medida. Reducir la banda a la mitad baja el ruido en un factor √2 (3 dB).
"""
function rms_ruido_banda(densidad::Real, fa::Real, fb::Real)
    densidad >= 0 || throw(ArgumentError("la densidad de ruido no puede ser negativa"))
    fb > fa >= 0 || throw(ArgumentError("la banda debe cumplir 0 ≤ fa < fb"))
    return densidad * sqrt(fb - fa)
end
