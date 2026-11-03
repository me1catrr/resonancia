# Descomposición en el dominio de la frecuencia (FDD) y su versión mejorada (EFDD), M7.7.
# Redactado a partir de la descripción del método en Brincker et al. (2000, 2001) tal y como la resume
# el tutorial de Magalhães y Cunha (2011); la implementación es propia.

"""
    matriz_espectral(Y, fs; nseg=4096, solape=0.5) -> (f, S)

Matriz de densidades espectrales (cruzadas) unilaterales de las `no` columnas de `Y` (`N × no`, muestreadas a
`fs` Hz) por el método de Welch: segmentos de `nseg` muestras (potencia de 2), ventana de Hann, solape relativo
`solape` y media restada a cada segmento. `S[a, b, k]` es la densidad cruzada entre los canales `a` y `b` en `f[k]`
(unidades²/Hz); `S[:, :, k]` es hermítica semidefinida positiva y su diagonal coincide con `psd_welch`.
"""
function matriz_espectral(Y::AbstractMatrix{<:Real}, fs::Real; nseg::Int=4096, solape::Real=0.5)
    N, no = size(Y)
    N >= nseg || throw(ArgumentError("el registro ($N muestras) es más corto que un segmento ($nseg)"))
    0 <= solape < 1 || throw(ArgumentError("el solape debe estar en [0, 1)"))
    w = [0.5 - 0.5cos(2π * n / nseg) for n in 0:nseg-1]
    paso = max(1, round(Int, nseg * (1 - solape)))
    nf = nseg ÷ 2 + 1
    S = zeros(ComplexF64, no, no, nf)
    nsegs = 0
    X = zeros(ComplexF64, nf, no)
    for ini in 1:paso:N-nseg+1
        for c in 1:no
            s = Float64.(view(Y, ini:ini+nseg-1, c))
            s .-= sum(s) / nseg
            X[:, c] = fft_radix2(s .* w)[1:nf]
        end
        for k in 1:nf, b in 1:no, a in 1:no
            @inbounds S[a, b, k] += X[k, a] * conj(X[k, b])
        end
        nsegs += 1
    end
    S .*= 1 / (nsegs * fs * sum(abs2, w))
    S[:, :, 2:nf-1] .*= 2
    return collect(0:nf-1) .* (fs / nseg), S
end

"""
    fdd(Y, fs; nseg=4096, solape=0.5) -> (f, s, U)

Descomposición en el dominio de la frecuencia: descomposición en valores singulares de la matriz espectral
`S(f)` en cada frecuencia, `S = U diag(s) Uᴴ`. Devuelve `f`, los valores singulares `s[i, k]` (decrecientes en `i`)
y los vectores singulares `U[:, i, k]`. Cerca de un modo aislado, `s[1, k]` se parece al espectro de un oscilador de
1 GDL y `U[:, 1, k]` a la forma modal en los canales medidos (salvo escala y fase global).
"""
function fdd(Y::AbstractMatrix{<:Real}, fs::Real; nseg::Int=4096, solape::Real=0.5)
    f, S = matriz_espectral(Y, fs; nseg=nseg, solape=solape)
    no, _, nf = size(S)
    s = zeros(no, nf)
    U = zeros(ComplexF64, no, no, nf)
    for k in 1:nf
        F = svd(Hermitian(S[:, :, k]))
        s[:, k] = F.S
        U[:, :, k] = F.U
    end
    return f, s, U
end

"""
    mac_complejo(a, b) -> Float64

Criterio de seguridad modal entre dos formas (posiblemente complejas), `|aᴴb|² / ((aᴴa)(bᴴb))`: 1 si una es múltiplo
(real o complejo) de la otra, 0 si son ortogonales.
"""
mac_complejo(a::AbstractVector, b::AbstractVector) = abs2(dot(a, b)) / (real(dot(a, a)) * real(dot(b, b)))

"""
    efdd_modo(f, s, U, k; mac_min=0.8, duracion=0.5/(f[2]-f[1]), umbral=0.1) -> NamedTuple

FDD mejorada (EFDD) alrededor del pico de la primera curva singular en el índice `k`. Pasos:

1. **Banda del modo**: se amplía a ambos lados de `k` mientras el MAC entre `U[:, 1, j]` y `U[:, 1, k]` sea
   ≥ `mac_min` (0,8 en el tutorial de referencia) y `s[1, j] > 0`.
2. **Correlación del oscilador equivalente**: transformada inversa de `s[1, j]` en esa banda (suma de cosenos en
   los retardos `0, Δt, …, duracion`), normalizada con su valor en el retardo 0.
3. **Frecuencia**: de los cruces por cero de la correlación (ajuste lineal tiempo-índice, semiperiodo).
4. **Amortiguamiento**: de los extremos de la correlación con `|r| ≥ umbral` (decremento logarítmico por regresión
   de `ln|r|` frente al tiempo).

Devuelve `f_n` (Hz), `zeta`, `forma` (vector singular en `k`, con la componente de mayor módulo real y positiva),
`banda = (ia, ib)` (índices de `f`), `t` y `r` (la correlación) y `n_extremos`, para comprobar el ajuste.
"""
function efdd_modo(f::AbstractVector, s::AbstractMatrix, U::AbstractArray{<:Complex,3}, k::Integer;
                   mac_min::Real=0.8, duracion::Real=0.5 / (f[2] - f[1]), umbral::Real=0.1)
    nf = length(f)
    1 < k < nf || throw(ArgumentError("k debe ser un índice interior de f"))
    φ = U[:, 1, k]
    ok(j) = s[1, j] > 0 && mac_complejo(view(U, :, 1, j), φ) >= mac_min
    ia = k; while ia > 2 && ok(ia - 1); ia -= 1; end
    ib = k; while ib < nf - 1 && ok(ib + 1); ib += 1; end
    dt = 1 / (2 * f[end])   # f[end] es la frecuencia de Nyquist: dt = 1/fs
    nlag = floor(Int, duracion / dt) + 1
    t = collect(0:nlag-1) .* dt
    r = [sum(s[1, j] * cos(2π * f[j] * τ) for j in ia:ib) for τ in t]
    r ./= r[1]
    # extremos locales de r (incluido el retardo 0) hasta que el módulo cae por debajo del umbral
    ext = [1]
    for m in 2:nlag-1
        if (r[m] - r[m-1]) * (r[m+1] - r[m]) < 0 || (r[m] == r[m-1] && r[m] != r[m+1])
            push!(ext, m)
        end
    end
    corte = findfirst(m -> abs(r[m]) < umbral, ext)
    ext = corte === nothing ? ext : ext[1:corte-1]
    length(ext) >= 3 || throw(ErrorException("la correlación decae demasiado deprisa para estimar el modo (revisa mac_min o la banda)"))
    tmax = t[ext[end]]
    # cruces por cero (interpolación lineal) dentro del tramo de extremos usados
    tc = Float64[]
    for m in 1:ext[end]-1
        if r[m] * r[m+1] < 0
            push!(tc, t[m] - r[m] * dt / (r[m+1] - r[m]))
        end
    end
    length(tc) >= 2 || throw(ErrorException("muy pocos cruces por cero para estimar la frecuencia"))
    n = length(tc)
    idx = collect(0:n-1)
    b = (n * sum(idx .* tc) - sum(idx) * sum(tc)) / (n * sum(idx .^ 2) - sum(idx)^2)   # semiperiodo medio
    fd = 1 / (2b)
    # decremento logarítmico: ln|r_ext| = c − σ t
    te = t[ext]; le = log.(abs.(r[ext]))
    ne = length(ext)
    σ = -(ne * sum(te .* le) - sum(te) * sum(le)) / (ne * sum(te .^ 2) - sum(te)^2)
    ωd = 2π * fd
    ζ = σ / sqrt(σ^2 + ωd^2)
    forma = copy(φ)
    j0 = argmax(abs.(forma))
    forma .*= conj(forma[j0]) / abs(forma[j0])
    return (f_n=fd / sqrt(1 - ζ^2), f_amortiguada=fd, zeta=ζ, forma=forma, banda=(ia, ib), t=t, r=r, n_extremos=ne, t_ajuste=tmax)
end

"""
    respuesta_modal(Phi, fn, zeta, F, fs) -> Matrix

Aceleración en los `nd` grados de libertad de un sistema con `nm` modos de masa modal unidad, formas `Phi`
(`nd × nm`), frecuencias naturales `fn` (Hz) y razones de amortiguamiento `zeta`, sometido a las fuerzas `F`
(`N × nd`, constantes entre muestras: retención de orden cero), muestreadas a `fs` Hz. La integración es **exacta**
para esa hipótesis (exponencial matricial de cada modo). Sirve para generar respuestas sintéticas con parámetros
modales conocidos.
"""
function respuesta_modal(Phi::AbstractMatrix{<:Real}, fn::AbstractVector{<:Real}, zeta::AbstractVector{<:Real},
                         F::AbstractMatrix{<:Real}, fs::Real)
    nd, nm = size(Phi)
    length(fn) == nm == length(zeta) || throw(DimensionMismatch("fn y zeta deben tener nm = $nm elementos"))
    size(F, 2) == nd || throw(DimensionMismatch("F debe tener nd = $nd columnas"))
    N = size(F, 1)
    P = F * Phi                       # fuerzas modales, N × nm
    A = zeros(N, nm)
    h = 1 / fs
    for m in 1:nm
        ω = 2π * fn[m]; ζ = zeta[m]
        E = exp([0 1 0; -ω^2 -2ζ * ω 1; 0 0 0] .* h)
        Φd, Γ = E[1:2, 1:2], E[1:2, 3]
        z = zeros(2)
        for n in 1:N
            A[n, m] = -2ζ * ω * z[2] - ω^2 * z[1] + P[n, m]
            z = Φd * z + Γ * P[n, m]
        end
    end
    return A * Phi'
end

"""
    psd_mejorada(s, U, k) -> Vector{Float64}

PSD «mejorada» (*enhanced PSD*, M7.7) del modo cuyo pico de la primera curva singular está en la línea `k`: se filtra la
matriz espectral con el vector singular del pico, `e(f_j) = u₁(f_k)ᴴ Ĝ(f_j) u₁(f_k)` con `Ĝ(f_j) = U_j diag(s_j) U_jᴴ`, es decir
`e_j = Σ_i s[i, j]·|u₁(f_k)ᴴ U[:, i, j]|²`. Cerca del modo se comporta como la densidad de un oscilador de 1 GDL (una
lorentziana), y lejos de él se atenúa lo que no comparte su forma. `s` y `U` son los de [`fdd`](@ref).
"""
function psd_mejorada(s::AbstractMatrix, U::AbstractArray{<:Complex,3}, k::Integer)
    no, nf = size(s)
    1 <= k <= nf || throw(ArgumentError("k fuera de rango"))
    uk = U[:, 1, k]
    return [sum(s[i, j] * abs2(dot(uk, U[:, i, j])) for i in 1:no) for j in 1:nf]
end

"""
    fsdd_modo(f, s, U, k; frac=0.3) -> NamedTuple

Frecuencia y amortiguamiento de un modo por **ajuste en banda estrecha de la PSD mejorada** (M7.7, método tipo FSDD de
Zhang et al.): se calcula [`psd_mejorada`](@ref) y se ajusta una lorentziana en las líneas contiguas al pico `k` donde
`e ≥ frac·e_k`. Como `1/e` es un polinomio de segundo grado en `ω`, el ajuste es lineal (mínimos cuadrados de `1/e`
con pesos `e²`, que equivalen a minimizar el error relativo de `e`); de los coeficientes salen la frecuencia
amortiguada y la tasa de decaimiento `σ`, y de ahí `ζ = σ/√(σ² + ω_d²)` y `f_n`. Devuelve `f_n`, `f_amortiguada`, `zeta`,
`banda = (ia, ib)`, `lineas`, `e` (la PSD mejorada de todas las líneas) y `modelo` (la lorentziana ajustada, función de la frecuencia en Hz), para dibujarlas.

La banda es lo que decide el resultado: con `frac` pequeño entran los hombros de modos vecinos y el ajuste falla;
con `frac` grande quedan pocas líneas. Lanza `ArgumentError` si el ajuste no da `σ² > 0` o quedan menos de 4 líneas.
"""
function fsdd_modo(f::AbstractVector, s::AbstractMatrix, U::AbstractArray{<:Complex,3}, k::Integer; frac::Real=0.3)
    0 < frac < 1 || throw(ArgumentError("frac debe estar entre 0 y 1"))
    e = psd_mejorada(s, U, k)
    ia = k; while ia > 1 && e[ia-1] >= frac * e[k]; ia -= 1; end
    ib = k; while ib < length(f) && e[ib+1] >= frac * e[k]; ib += 1; end
    ib - ia + 1 >= 4 || throw(ArgumentError("menos de 4 líneas en la banda: usa un frac menor o más resolución"))
    idx = ia:ib
    ω = 2π .* f[idx]
    A = hcat(ω .^ 2, ω, ones(length(ω)))
    W = Diagonal(e[idx] .^ 2)
    a, b, c0 = (A' * W * A) \ (A' * W * (1 ./ e[idx]))
    a > 0 || throw(ArgumentError("el ajuste no da una lorentziana (coeficiente cuadrático no positivo)"))
    ωd = -b / (2a)
    σ2 = c0 / a - ωd^2
    σ2 > 0 || throw(ArgumentError("el ajuste no da una tasa de decaimiento real"))
    σ = sqrt(σ2)
    ζ = σ / sqrt(σ^2 + ωd^2)
    modelo = fq -> 1 / (a * (2π * fq)^2 + b * 2π * fq + c0)
    return (f_n=ωd / (2π) / sqrt(1 - ζ^2), f_amortiguada=ωd / (2π), zeta=ζ, banda=(ia, ib), lineas=length(idx), e=e, modelo=modelo)
end

"""
    indicador_armonico(x, fs, f0; ancho) -> NamedTuple

Indicador de armónicos por **curtosis** (M7.7). Filtra `x` (un vector, o una matriz con un canal por columna) con un filtro
paso banda ideal de anchura `ancho` (Hz) centrado en `f0` (por FFT, de fase cero; se usa la mayor potencia de 2 de
muestras) y calcula la curtosis en exceso de lo que queda. La respuesta de uno o varios modos es casi gaussiana (exceso ≈ 0);
una sinusoide tiene la distribución de dos picos del arcoseno y un exceso de `−1,5`. Devuelve `exceso` (por canal),
`incertidumbre = √(24/N_ef)` con `N_ef = duración·ancho` muestras independientes (la desviación típica del exceso de un proceso
gaussiano) y `n` (muestras usadas). Un armónico **más débil que la respuesta modal** que lo acompaña no se detecta.
"""
function indicador_armonico(x::AbstractVecOrMat{<:Real}, fs::Real, f0::Real; ancho::Real)
    X = x isa AbstractVector ? reshape(x, :, 1) : x
    N = 2^floor(Int, log2(size(X, 1)))
    N >= 64 || throw(ArgumentError("registro demasiado corto"))
    ancho > 0 && f0 > ancho / 2 && f0 + ancho / 2 < fs / 2 || throw(ArgumentError("la banda debe quedar entre 0 y fs/2"))
    f = min.((0:N-1) .* (fs / N), fs .- (0:N-1) .* (fs / N))
    dentro = abs.(f .- f0) .<= ancho / 2
    exceso = map(1:size(X, 2)) do c
        F = fft_radix2(Float64.(X[1:N, c]) .+ 0im)
        F[.!dentro] .= 0
        z = real.(ifft_radix2(F))
        z .-= sum(z) / N
        sum(z .^ 4) / N / (sum(z .^ 2) / N)^2 - 3
    end
    return (exceso=exceso, incertidumbre=sqrt(24 / (N / fs * ancho)), n=N)
end
