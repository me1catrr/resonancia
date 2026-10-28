# Viga de Euler–Bernoulli (J3.4 y J3.5): ecuaciones características, frecuencias y formas modales.
# La ecuación de la viga uniforme es  EI ∂⁴w/∂x⁴ + ρA ∂²w/∂t² = 0; con w = φ(x) e^{iωt} resulta
# φ'''' = β⁴ φ, con β⁴ = ω² ρA / EI, y las condiciones de contorno dan una ecuación en x = βL.

const TIPOS_VIGA = (:biapoyada, :voladizo, :libre_libre, :biempotrada, :empotrada_apoyada, :voladizo_masa)

"""
    ecuacion_viga(tipo, x; mu=0.0) -> Float64

Ecuación característica de una viga uniforme de Euler–Bernoulli en la variable `x = βL`, escrita en forma
**estable** (dividida por `cosh x`, para que no se desborde al crecer `x`). Sus raíces son los `βL` de los modos.

| `tipo`               | condiciones            | ecuación                                  |
|:---------------------|:-----------------------|:------------------------------------------|
| `:biapoyada`         | apoyada–apoyada        | `sin x = 0`                               |
| `:voladizo`          | empotrada–libre        | `cos x + 1/cosh x = 0`                    |
| `:libre_libre`       | libre–libre            | `cos x - 1/cosh x = 0` (sin `x = 0`)      |
| `:biempotrada`       | empotrada–empotrada    | la misma que libre–libre                  |
| `:empotrada_apoyada` | empotrada–apoyada      | `sin x - cos x tanh x = 0`                |
| `:voladizo_masa`     | voladizo con masa en el extremo | `1/cosh x + cos x + μ x (cos x tanh x - sin x) = 0` |

`mu` es la razón entre la masa concentrada del extremo y la masa de la viga (`ρAL`); solo se usa en `:voladizo_masa`.
"""
function ecuacion_viga(tipo::Symbol, x::Real; mu::Real=0.0)
    if tipo === :biapoyada
        return sin(x)
    elseif tipo === :voladizo
        return cos(x) + 1 / cosh(x)
    elseif tipo === :libre_libre || tipo === :biempotrada
        return cos(x) - 1 / cosh(x)
    elseif tipo === :empotrada_apoyada
        return sin(x) - cos(x) * tanh(x)
    elseif tipo === :voladizo_masa
        return 1 / cosh(x) + cos(x) + mu * x * (cos(x) * tanh(x) - sin(x))
    end
    throw(ArgumentError("tipo debe ser uno de $(TIPOS_VIGA)"))
end

"""
    raices_viga(tipo, n=4; mu=0.0, tol=1e-15) -> Vector{Float64}

Las `n` primeras raíces positivas `βL` de [`ecuacion_viga`](@ref) (los modos de flexión; en `:libre_libre` se
excluye el movimiento de sólido rígido). Rastrea los cambios de signo con paso 0,05 desde `x = 0,05` y refina cada
raíz por bisección hasta que el intervalo mida menos que `tol` (relativo); en `:biapoyada` devuelve `nπ`. Es una implementación mínima para el
paquete (sin dependencias): en la práctica se usaría `Roots.jl` (J3.4).
"""
function raices_viga(tipo::Symbol, n::Integer=4; mu::Real=0.0, tol::Real=1e-15)
    tipo in TIPOS_VIGA || throw(ArgumentError("tipo debe ser uno de $(TIPOS_VIGA)"))
    n >= 1 || throw(ArgumentError("n debe ser positivo"))
    tipo === :biapoyada && return [j * π for j in 1:n]
    g(x) = ecuacion_viga(tipo, x; mu=mu)
    raices = Float64[]
    paso = 0.05
    a = 0.5
    fa = g(a)
    while length(raices) < n
        b = a + paso
        fb = g(b)
        if fa == 0
            push!(raices, a)
        elseif fa * fb < 0
            lo, hi, flo = a, b, fa
            while hi - lo > tol * max(1.0, abs(hi))
                mid = (lo + hi) / 2
                fm = g(mid)
                if flo * fm <= 0
                    hi = mid
                else
                    lo, flo = mid, fm
                end
            end
            push!(raices, (lo + hi) / 2)
        end
        a, fa = b, fb
        a > 1000 && throw(ErrorException("no se encontraron $n raíces"))
    end
    return raices
end

"""
    frecuencias_viga(tipo; E, I, rho, A, L, n=4, mu=0.0) -> Vector{Float64}

Frecuencias propias de flexión (Hz) de una viga uniforme: `fₙ = (βₙL)² / (2π L²) · √(EI / (ρA))`, con `βₙL` las
raíces de [`ecuacion_viga`](@ref). Unidades SI: `E` en Pa, `I` en m⁴, `rho` en kg/m³, `A` en m², `L` en m.
"""
function frecuencias_viga(tipo::Symbol; E::Real, I::Real, rho::Real, A::Real, L::Real, n::Integer=4, mu::Real=0.0)
    bL = raices_viga(tipo, n; mu=mu)
    return @. bL^2 / (2π * L^2) * sqrt(E * I / (rho * A))
end

"""
    forma_modal_viga(tipo, bL, xi) -> Float64

Forma del modo de raíz `bL` en la posición relativa `xi = x/L ∈ [0, 1]`, para `:biapoyada` (`sin(bL·xi)`) y
`:voladizo` (combinación de funciones trigonométricas e hiperbólicas; se normaliza para que valga 1 en el extremo
libre). Está escrita con operaciones elementales, de modo que se puede derivar con diferenciación automática.
"""
function forma_modal_viga(tipo::Symbol, bL::Real, xi::Real)
    if tipo === :biapoyada
        return sin(bL * xi)
    elseif tipo === :voladizo
        s = (cosh(bL) + cos(bL)) / (sinh(bL) + sin(bL))
        phi(z) = cosh(bL * z) - cos(bL * z) - s * (sinh(bL * z) - sin(bL * z))
        return phi(xi) / phi(one(xi))
    end
    throw(ArgumentError("forma modal disponible solo para :biapoyada y :voladizo"))
end
