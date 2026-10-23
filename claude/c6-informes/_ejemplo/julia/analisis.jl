# Análisis de los casos A–E de la vía C (datos sintéticos). Uso:
#   julia --project=. claude/c6-informes/_ejemplo/julia/analisis.jl
using CSV, DataFrames, Statistics, Dates

const RAIZ = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
const DATOS = joinpath(RAIZ, "datos", "sinteticos", "curso-claude")
cargar(nombre; kw...) = CSV.read(joinpath(DATOS, nombre), DataFrame; kw...)

# ── Caso A: ventas ────────────────────────────────────────────────────────────
"Registro de incidencias de calidad de un DataFrame de ventas."
function validar_ventas(df)
    (; filas = nrow(df),
       duplicadas = nrow(df) - nrow(unique(df)),
       ausentes = count(ismissing, df.ventas_eur))
end

"Totales anuales de ventas por región (ignora duplicados y ausentes)."
function ventas_por_region(df)
    limpio = dropmissing(unique(df), :ventas_eur)
    combine(groupby(limpio, :region), :ventas_eur => sum => :total_eur, nrow => :meses)
end

# ── Caso B: fechas mixtas ─────────────────────────────────────────────────────
"Interpreta fechas ISO (aaaa-mm-dd) o dd/mm/aaaa; devuelve `missing` si no reconoce el formato."
function parsear_fecha(s)
    ismissing(s) && return missing
    for f in (dateformat"yyyy-mm-dd", dateformat"dd/mm/yyyy")
        d = tryparse(Date, s, f)
        d === nothing || return d
    end
    return missing
end

# ── Caso C: mantenimiento ─────────────────────────────────────────────────────
"Horas de parada y coste por tipo de orden."
resumen_mantenimiento(df) = combine(groupby(df, :tipo),
    nrow => :ordenes, :horas_parada => sum => :horas, :horas_parada => mean => :horas_medias,
    :coste_eur => (c -> sum(skipmissing(c))) => :coste_total)

# ── Caso D: sensor con un hueco ───────────────────────────────────────────────
"Primer y último índice (consecutivos) de cada hueco de valores ausentes."
function huecos(v)
    res = Tuple{Int,Int}[]; i = 1
    while i <= length(v)
        if ismissing(v[i])
            j = i
            while j < length(v) && ismissing(v[j+1]); j += 1; end
            push!(res, (i, j)); i = j + 1
        else
            i += 1
        end
    end
    res
end

# ── Caso E: espectro (FFT radix-2 propia; solo para no añadir dependencias) ──
"FFT de longitud potencia de 2 (Cooley-Tukey recursiva)."
function fft2(x::AbstractVector{<:Number})
    n = length(x)
    n == 1 && return complex.(x)
    isinteger(log2(n)) || throw(ArgumentError("la longitud debe ser potencia de 2, no $n"))
    par, impar = fft2(x[1:2:end]), fft2(x[2:2:end])
    w = cis.(-2π .* (0:n÷2-1) ./ n)
    return [par .+ w .* impar; par .- w .* impar]
end

"Espectro de amplitud de un solo lado (unidades de la señal) de una señal real con ventana de Hann."
function espectro(x, fs)
    n = length(x)
    v = 0.5 .- 0.5 .* cos.(2π .* (0:n-1) ./ n)          # Hann
    y = fft2((x .- mean(x)) .* v)
    f = (0:n÷2) .* fs ./ n
    return f, abs.(y[1:n÷2+1]) .* 2 ./ sum(v)
end

function principal()
    a = cargar("a_ventas.csv"; dateformat = "yyyy-mm-dd")
    println("A validar: ", validar_ventas(a))
    println(ventas_por_region(a))
    println("A total: ", round(sum(ventas_por_region(a).total_eur), digits = 2))

    b = cargar("b_absentismo.csv"; types = Dict(:fecha => String))
    f = parsear_fecha.(b.fecha)
    println("B filas=", nrow(b), " fechas dd/mm/aaaa=", count(s -> occursin('/', s), b.fecha), " no reconocidas=", count(ismissing, f),
            " días totales=", sum(b.dias_ausencia), " mes con más días=", argmax(combine(groupby(DataFrame(m = month.(f), d = b.dias_ausencia), :m), :d => sum => :d) |> df -> Dict(df.m .=> df.d)))

    c = cargar("c_mantenimiento.csv")
    println(resumen_mantenimiento(c))
    println("C ausentes coste=", count(ismissing, c.coste_eur))

    d = cargar("d_ambiental.csv")
    println("D filas=", nrow(d), " huecos=", huecos(d.temperatura_C), " media T=", round(mean(skipmissing(d.temperatura_C)), digits = 2))

    e = cargar("e_vibracion.csv")
    f_, A = espectro(e.aceleracion_m_s2, 200.0)
    i1 = argmax(A)
    println("E: pico principal f=", round(f_[i1], digits = 3), " Hz, amplitud=", round(A[i1], digits = 4), "; Δf=", 200 / 4096)
    A2 = copy(A); A2[max(1, i1 - 5):min(end, i1 + 5)] .= 0
    i2 = argmax(A2[f_ .> 20]) + count(f_ .<= 20)
    println("E: segundo pico f=", round(f_[i2], digits = 3), " Hz, amplitud=", round(A[i2], digits = 4))
end

abspath(PROGRAM_FILE) == @__FILE__() && principal()
