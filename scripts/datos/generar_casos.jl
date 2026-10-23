# =============================================================================
# generar_casos.jl: datos sintéticos de la vía C (casos A–E)
#
# Uso: julia --project=. scripts/datos/generar_casos.jl
# Salida: datos/sinteticos/curso-claude/*.csv y *.meta.toml. Semilla fija (20261023):
# la salida es idéntica en cada ejecución. Solo usa la biblioteca estándar.
# Los defectos (ausentes, duplicados, formatos mixtos) son deliberados y se
# documentan en cada ficha, porque el curso enseña a detectarlos.
# =============================================================================
using Random, Dates, Printf

const SEMILLA = 20261023
const SALIDA = joinpath(@__DIR__, "..", "..", "datos", "sinteticos", "curso-claude")
mkpath(SALIDA)

function ficha(nombre, descripcion, columnas, defectos; sensor = "ninguno", fs = "no aplica")
    open(joinpath(SALIDA, nombre * ".meta.toml"), "w") do io
        println(io, "origen = \"Sintético: generado por scripts/datos/generar_casos.jl (semilla $SEMILLA)\"")
        println(io, "descripcion = \"$descripcion\"")
        println(io, "sensor = \"$sensor\"")
        println(io, "fs = \"$fs\"")
        println(io, "unidades = \"", columnas, "\"")
        println(io, "defectos_deliberados = \"$defectos\"")
        println(io, "licencia = \"CC BY-SA 4.0\"")
        println(io, "publicable = true")
    end
end

# Caso A · ventas mensuales por región (36 meses × 3 regiones), con ausentes y un duplicado.
let rng = MersenneTwister(SEMILLA)
    filas = String[]
    for (r, base) in (("Norte", 52_000.0), ("Centro", 68_000.0), ("Sur", 44_000.0)), m in 0:35
        f = Date(2023, 1, 1) + Month(m)
        est = 1 + 0.18 * sin(2π * (month(f) - 3) / 12)
        v = base * est * (1 + 0.004m) * (1 + 0.04 * randn(rng))
        u = round(Int, v / 41 * (1 + 0.03 * randn(rng)))
        ausente = rand(rng) < 0.03
        push!(filas, @sprintf("%s,%s,%s,%d", f, r, ausente ? "" : @sprintf("%.2f", v), u))
    end
    open(joinpath(SALIDA, "a_ventas.csv"), "w") do io
        println(io, "fecha,region,ventas_eur,unidades")
        foreach(f -> println(io, f), filas)
        println(io, filas[17])  # duplicado deliberado
    end
    ficha("a_ventas", "Ventas mensuales por región, 2023-2025", "fecha ISO 8601; ventas_eur en euros; unidades en uds.", "ventas_eur ausente en ~3 % de filas; una fila duplicada al final")
end

# Caso B · absentismo por departamento (RR. HH.), con formatos de fecha mixtos.
let rng = MersenneTwister(SEMILLA + 1)
    deps = ["Producción", "Logística", "Administración", "Mantenimiento", "Calidad"]
    open(joinpath(SALIDA, "b_absentismo.csv"), "w") do io
        println(io, "id_empleado,departamento,fecha,dias_ausencia,motivo")
        for i in 1:240
            d = Date(2025, 1, 1) + Day(rand(rng, 0:364))
            fecha = rand(rng) < 0.1 ? Dates.format(d, "dd/mm/yyyy") : string(d)
            motivo = rand(rng, ["enfermedad", "enfermedad", "asuntos propios", "formación", "accidente"])
            @printf(io, "E%04d,%s,%s,%d,%s\n", rand(rng, 1:90), rand(rng, deps), fecha, rand(rng, 1:6), motivo)
        end
    end
    ficha("b_absentismo", "Ausencias de personal por departamento en 2025 (identificadores ficticios)", "fecha ISO 8601 o dd/mm/aaaa; dias_ausencia en días laborables", "~10 % de fechas en formato dd/mm/aaaa; mismo id_empleado con departamentos distintos")
end

# Caso C · órdenes de mantenimiento de una planta.
let rng = MersenneTwister(SEMILLA + 2)
    equipos = ["Bomba P-101", "Bomba P-102", "Compresor K-201", "Ventilador V-301", "Cinta T-401"]
    open(joinpath(SALIDA, "c_mantenimiento.csv"), "w") do io
        println(io, "orden,equipo,tipo,fecha_apertura,horas_parada,coste_eur")
        for i in 1:180
            e = rand(rng, equipos)
            tipo = rand(rng) < 0.35 ? "correctivo" : "preventivo"
            h = tipo == "correctivo" ? round(2 + 30 * rand(rng)^2, digits = 1) : round(0.5 + 1.5rand(rng), digits = 1)
            c = round(h * (tipo == "correctivo" ? 310 : 120) * (0.8 + 0.4rand(rng)), digits = 2)
            @printf(io, "OT-%04d,%s,%s,%s,%.1f,%s\n", i, e, tipo, Date(2025, 1, 1) + Day(rand(rng, 0:364)), h, rand(rng) < 0.02 ? "" : @sprintf("%.2f", c))
        end
    end
    ficha("c_mantenimiento", "Órdenes de trabajo de mantenimiento de cinco equipos en 2025", "horas_parada en h; coste_eur en euros", "coste_eur ausente en ~2 % de filas")
end

# Caso D · sensor ambiental (temperatura y humedad), 1 muestra cada 10 min durante 14 días.
let rng = MersenneTwister(SEMILLA + 3)
    open(joinpath(SALIDA, "d_ambiental.csv"), "w") do io
        println(io, "instante,temperatura_C,humedad_pct")
        t0 = DateTime(2025, 6, 2, 0, 0)
        for k in 0:(14 * 144 - 1)
            t = t0 + Minute(10k)
            h = hour(t) + minute(t) / 60
            T = 22 + 5 * sin(2π * (h - 9) / 24) + 0.4randn(rng)
            H = 55 - 12 * sin(2π * (h - 9) / 24) + 1.5randn(rng)
            falla = 600 <= k <= 612
            @printf(io, "%s,%s,%.1f\n", t, falla ? "" : @sprintf("%.2f", T), clamp(H, 0, 100))
        end
    end
    ficha("d_ambiental", "Temperatura y humedad en una nave, 14 días", "temperatura en °C; humedad relativa en %", "13 muestras consecutivas de temperatura ausentes (fallo del sensor)"; sensor = "termohigrómetro simulado", fs = "1/600 Hz (1 muestra cada 10 min)")
end

# Caso E · vibración de una viga: dos modos amortiguados excitados por impulsos en instantes
# aleatorios (un tren periódico daría un espectro de líneas que enmascara los picos modales).
let rng = MersenneTwister(SEMILLA + 4)
    fs = 200.0; n = 4096; dt = 1 / fs
    modos = [(f = 12.5, ζ = 0.015, a = 1.0), (f = 41.0, ζ = 0.020, a = 0.45)]
    instantes = cumsum(0.8 .+ 2.4 .* rand(rng, 12))   # un impulso cada ~2 s, de amplitud aleatoria
    amplitudes = 0.5 .+ rand(rng, 12)
    x = zeros(n)
    for k in 1:n
        t = (k - 1) * dt
        for (ti, ai) in zip(instantes, amplitudes)
            t < ti && continue
            τ = t - ti
            for m in modos
                ωd = 2π * m.f * sqrt(1 - m.ζ^2)
                x[k] += ai * m.a * exp(-m.ζ * 2π * m.f * τ) * cos(ωd * τ)
            end
        end
        x[k] += 0.05randn(rng)
    end
    open(joinpath(SALIDA, "e_vibracion.csv"), "w") do io
        println(io, "t_s,aceleracion_m_s2")
        for k in 1:n
            @printf(io, "%.4f,%.5f\n", (k - 1) * dt, x[k])
        end
    end
    ficha("e_vibracion", "Aceleración de una viga con modos a 12,5 Hz y 41,0 Hz (ζ = 1,5 % y 2,0 %), impulsos aleatorios cada ~2 s", "t en s; aceleración en m/s²", "ninguno; ruido blanco gaussiano de σ = 0,05 m/s²"; sensor = "acelerómetro simulado", fs = "200 Hz")
end

println("Casos A–E escritos en ", normpath(SALIDA))
