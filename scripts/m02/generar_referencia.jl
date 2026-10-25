#!/usr/bin/env julia
# =============================================================================
# generar_referencia.jl: datos de referencia de M02 (entradas fijas y resultados
# calculados con Julia) para contrastar las implementaciones en JavaScript y Python.
#
# Uso (desde la raíz):  julia --project=. scripts/m02/generar_referencia.jl
# Escribe mse/m02-matematicas/referencia/matrices.json. Sin aleatoriedad.
# Los autovectores y vectores singulares tienen signo arbitrario: las pruebas
# comparan magnitudes (|φ|), el MAC o las identidades, no el signo.
# =============================================================================
using LinearAlgebra, Resonancia

json(x::Integer) = string(x)
json(x::Real) = isfinite(x) ? string(Float64(x)) : "null"
json(x::AbstractString) = "\"" * x * "\""
json(x::AbstractVector) = "[" * join(json.(x), ",") * "]"
json(x::AbstractMatrix) = "[" * join((json(x[i, :]) for i in axes(x, 1)), ",") * "]"
json(x::NamedTuple) = "{" * join(("\"$k\":" * json(v) for (k, v) in pairs(x)), ",") * "}"

ref = Dict{String,Any}()

# 1. Matrices simétricas y rectangulares: valores propios, SVD, normas, condicionamiento
A = [4.0 1.0 0.0; 1.0 3.0 1.0; 0.0 1.0 2.0]
R = [1.0 2.0; 3.0 4.0; 5.0 6.0]
b = [1.0, 0.0, -1.0]
ref["simetrica"] = (A=A, valores_propios=sort(eigvals(Symmetric(A))))
ref["rectangular"] = (R=R, valores_singulares=svdvals(R), norma1=opnorm(R, 1), normaInf=opnorm(R, Inf),
    normaFro=norm(R), norma2=opnorm(R, 2), cond2=cond(R), b=b, minimos_cuadrados=R \ [1.0, 2.0, 4.0], b_ls=[1.0, 2.0, 4.0])

# 2. Condicionamiento: Hilbert 5x5
H5 = [1 / (i + j - 1) for i in 1:5, j in 1:5]
ref["hilbert5"] = (H=H5, cond2=cond(H5), solucion=H5 \ ones(5))

# 3. FFT de una señal de longitud 8
x8 = [1.0, 2.0, 0.0, -1.0, 3.0, 0.5, 0.0, 1.0]
X8 = fft_radix2(x8)
ref["fft8"] = (x=x8, re=real.(X8), im=imag.(X8))

# 4. Convolución circular
a8 = x8
b8 = [0.5, -1.0, 2.0, 0.0, 1.0, 1.0, -2.0, 0.0]
ref["conv_circular"] = (a=a8, b=b8, c=conv_circular(a8, b8))

# 5. Autocorrelación y Yule–Walker sobre una serie corta
z = [0.3, -1.2, 0.8, 0.1, -0.4, 1.5, -0.9, 0.2, 0.6, -0.7]
rz = autocorrelacion(z, 5)
phi, s2 = yule_walker(rz, 2)
ref["yule_walker"] = (z=z, r=rz, phi=phi, sigma2=s2)

# 6. Hankel y SSA de dos sinusoides
t = (0:99) ./ 100
xs = sin.(2π * 5 .* t) .+ 0.5 .* sin.(2π * 12 .* t)
rec, S = ssa(xs, 30, 4)
ref["ssa"] = (x=xs, L=30, valores_singulares=S[1:8], reconstruccion_rango4=rec)

# 7. Cadena de 4 masas y muelles (m = 2 kg, k = 5 N/m) y edificio de cortante genérico
M4, K4 = cadena_masas_muelles(4; m=2.0, k=5.0)
f4, P4 = modos_propios(K4, M4)
ref["cadena4"] = (m=2.0, k=5.0, f=f4, modos_abs=abs.(P4))
me, ke = [1.0, 2.0, 3.0], [4.0, 5.0, 6.0]
Me, Ke = edificio_cortante(me, ke)
fe, Pe = modos_propios(Ke, Me)
ref["edificio_generico"] = (m=me, k=ke, K=Ke, f=fe, modos_abs=abs.(Pe))

# 8. MAC
v1, v2 = [1.0, 2.0, 3.0], [1.0, 2.5, 2.0]
ref["mac"] = (a=v1, b=v2, valor=mac(v1, v2))

# 9. ERA, Levinson–Durbin, observabilidad y matriz MAC
dt = 0.01
osc(f, z) = (ω = 2π * f; [0.0 1.0; -ω^2 -2z * ω])
Ac = [osc(2.0, 0.02) zeros(2, 2); zeros(2, 2) osc(5.0, 0.05)]
Bc = [0.0, 1.0, 0.0, 1.0]
Cc = [1.0 0.0 1.0 0.0]
Ad = exp(Ac * dt)
Bd = Ac \ ((Ad - I) * Bc)
hk = [(Cc * Ad^(k - 1) * Bd)[1] for k in 1:80]
fe, ze = era(hk, 4, dt)
ref["era"] = (dt=dt, h=hk, n=4, f=fe, zeta=ze)
phi_l, s2_l, kappa_l = levinson_durbin(rz, 3)
ref["levinson"] = (r=rz, p=3, phi=phi_l, sigma2=s2_l, kappa=kappa_l)
Kf = [2.0 -1.0 0.0; -1.0 2.0 -1.0; 0.0 -1.0 2.0]
Aobs = [zeros(3, 3) I(3); -Kf zeros(3, 3)]
ref["observabilidad"] = (A=Aobs, C_centro=[0.0 1.0 0.0 0.0 0.0 0.0], C_extremo=[1.0 0.0 0.0 0.0 0.0 0.0],
    rango_centro=rank(matriz_observabilidad(Aobs, [0.0 1.0 0.0 0.0 0.0 0.0])),
    rango_extremo=rank(matriz_observabilidad(Aobs, [1.0 0.0 0.0 0.0 0.0 0.0])))
Me0, K0 = edificio_cortante([1.0, 1.0, 1.0], [1.0, 1.0, 1.0])
_, K1 = edificio_cortante([1.0, 1.0, 1.0], [1.0, 0.9, 1.0])
f0, P0 = modos_propios(K0, Me0)
f1, P1 = modos_propios(K1, Me0)
ref["mac_edificio"] = (f0=f0, f1=f1, matriz=matriz_mac(P0, P1))
fpa, zpa = polos_ar([1.2, -0.6, 0.1], 0.1)
ref["polos_ar"] = (phi=[1.2, -0.6, 0.1], dt=0.1, f=fpa, zeta=zpa)
Bp = [3.0 1.0; 1.0 2.0; 0.0 1.0]
ref["pseudoinversa"] = (A=Bp, P=pseudoinversa_svd(Bp), Arango1=[1.0 2.0; 2.0 4.0; 3.0 6.0], rango1=rango_numerico([1.0 2.0; 2.0 4.0; 3.0 6.0]))
Ae = [0.0 1.0; -4.0 -0.4]
Ade, Bde = discretizar_zoh(Ae, reshape([0.0, 1.0], 2, 1), 0.05)
ref["expm"] = (A=Ae, expA=expm(Ae), dt=0.05, Ad=Ade, Bd=Bde)
Me3, Ce3, Ke3 = edificio_tres_plantas()
fe3, Pe3 = modos_propios(Ke3, Me3)
Ae3, _ = espacio_estados(Me3, Ce3, Ke3, [0.0, 0.0, 1.0])
fp3, zp3 = polos_modales(Ae3)
_, _, KeC = edificio_tres_plantas(escenario=:C)
fC, PC = modos_propios(KeC, Me3)
ref["edificio3"] = (K=Ke3, f=fe3, f_polos=fp3, zeta=zp3, f_C=fC, mac_AC=[mac(Pe3[:, i], PC[:, i]) for i in 1:3])

salida = joinpath(@__DIR__, "..", "..", "mse", "m02-matematicas", "referencia", "matrices.json")
open(salida, "w") do io
    println(io, "{")
    claves = sort(collect(keys(ref)))
    for (i, k) in enumerate(claves)
        println(io, "  \"", k, "\": ", json(ref[k]), i < length(claves) ? "," : "")
    end
    println(io, "}")
end
println("Escrito ", normpath(salida))
