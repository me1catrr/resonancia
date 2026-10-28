# Métodos elementales de búsqueda de raíces (J3.4), con historial de iteraciones para estudiar la convergencia.
# Para el trabajo real se usa `Roots.jl`; estas versiones están para ver cómo converge cada método.

"""
    raiz_biseccion(f, a, b; tol=1e-14, maxiter=200) -> (x, historial)

Raíz de `f` en `[a, b]` por bisección: exige `f(a) f(b) < 0` y reduce el intervalo a la mitad en cada paso hasta que
mida menos que `tol`. `historial` guarda el punto medio de cada iteración. Converge siempre y con **orden lineal**:
cada iteración gana un bit (≈ 0,3 cifras decimales).
"""
function raiz_biseccion(f, a::Real, b::Real; tol::Real=1e-14, maxiter::Integer=200)
    fa, fb = f(a), f(b)
    fa * fb < 0 || throw(ArgumentError("f(a) y f(b) deben tener signos opuestos"))
    hist = Float64[]
    lo, hi, flo = float(a), float(b), fa
    for _ in 1:maxiter
        mid = (lo + hi) / 2
        push!(hist, mid)
        fm = f(mid)
        if fm == 0
            return mid, hist
        elseif flo * fm < 0
            hi = mid
        else
            lo, flo = mid, fm
        end
        hi - lo <= tol && break
    end
    return (lo + hi) / 2, hist
end

"""
    raiz_newton(f, df, x0; tol=1e-14, maxiter=50) -> (x, historial)

Método de Newton `xₖ₊₁ = xₖ − f(xₖ)/f'(xₖ)` desde `x0`, parando cuando `|xₖ₊₁ − xₖ| ≤ tol`. `historial` incluye `x0` y
cada iterada. En una raíz simple y cerca de ella el **error se eleva al cuadrado** en cada paso (orden 2); en una raíz
múltiple el orden baja a lineal. Lanza un error si la derivada se anula.
"""
function raiz_newton(f, df, x0::Real; tol::Real=1e-14, maxiter::Integer=50)
    x = float(x0)
    hist = [x]
    for _ in 1:maxiter
        d = df(x)
        d == 0 && throw(ErrorException("la derivada se anula en x = $x"))
        xn = x - f(x) / d
        push!(hist, xn)
        abs(xn - x) <= tol && return xn, hist
        x = xn
    end
    return x, hist
end

"""
    raiz_secante(f, x0, x1; tol=1e-14, maxiter=50) -> (x, historial)

Método de la secante: como Newton pero con la pendiente de la recta por los dos últimos puntos, sin necesidad de la
derivada. Orden de convergencia `(1+√5)/2 ≈ 1,62` en una raíz simple.
"""
function raiz_secante(f, x0::Real, x1::Real; tol::Real=1e-14, maxiter::Integer=50)
    xa, xb = float(x0), float(x1)
    fa, fb = f(xa), f(xb)
    hist = [xa, xb]
    for _ in 1:maxiter
        fb == fa && throw(ErrorException("pendiente nula entre los dos últimos puntos"))
        xc = xb - fb * (xb - xa) / (fb - fa)
        push!(hist, xc)
        abs(xc - xb) <= tol && return xc, hist
        xa, fa, xb, fb = xb, fb, xc, f(xc)
    end
    return xb, hist
end
