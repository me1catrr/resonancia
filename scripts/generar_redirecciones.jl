#!/usr/bin/env julia
# =============================================================================
# generar_redirecciones.jl — URL antiguas de las vías J y C → JuliaDo y ClaudeDo
#
# Uso (desde la raíz del repositorio):
#   julia --project=. scripts/generar_redirecciones.jl [--comprobar]
#
# Hasta noviembre de 2026, Resonancia publicaba las vías J (julia/) y C (claude/).
# Ahora son sitios propios. A partir del bloque `externos` de temario.yml escribe
# _redirecciones.json: una entrada por URL antigua (index.html y, si la unidad
# tiene diapositivas, slides.html) con su destino. Tras cada render,
# scripts/redirecciones.ts crea en _site/ una página mínima de redirección para
# cada entrada, que conserva el ancla (#…) de la URL.
#
#   --comprobar  no escribe: código de salida 1 si _redirecciones.json no está al día.
# =============================================================================

using YAML

const RAIZ = normpath(joinpath(@__DIR__, ".."))
const SALIDA = joinpath(RAIZ, "_redirecciones.json")

jq(s) = "\"" * replace(string(s), "\\" => "\\\\", "\"" => "\\\"") * "\""

function entradas()
    d = YAML.load_file(joinpath(RAIZ, "temario.yml"); dicttype = Dict{String,Any})
    es = Tuple{String,String,String,String}[]   # (de, a, sitio, título)
    for s in get(d, "externos", [])
        haskey(s, "antes") || continue
        antes, web, sitio = string(s["antes"]), string(s["web"]), string(s["sitio"])
        for p in s["paginas"]
            ruta = string(p["ruta"])
            titulo = haskey(p, "id") ? "$(p["id"]) · $(p["titulo"])" : string(p["titulo"])
            if isempty(ruta) || endswith(ruta, "/")
                push!(es, (antes * ruta * "index.html", web * ruta, sitio, titulo))
                get(p, "slides", false) == true &&
                    push!(es, (antes * ruta * "slides.html", web * ruta * "slides.html", sitio,
                               titulo * " (diapositivas)"))
            else
                push!(es, (antes * ruta, web * ruta, sitio, titulo))
            end
        end
    end
    des = first.(es)
    length(unique(des)) == length(des) || error("hay URL antiguas repetidas en `externos`")
    return sort!(es)
end

function json(es)
    io = IOBuffer()
    println(io, "[")
    for (i, (de, a, sitio, titulo)) in enumerate(es)
        print(io, "  {\"de\": ", jq(de), ", \"a\": ", jq(a), ", \"sitio\": ", jq(sitio),
              ", \"titulo\": ", jq(titulo), "}")
        println(io, i < length(es) ? "," : "")
    end
    println(io, "]")
    return String(take!(io))
end

function main()
    texto = json(entradas())
    actual = isfile(SALIDA) ? read(SALIDA, String) : ""
    n = count(==('\n'), texto) - 2
    if "--comprobar" in ARGS
        texto == actual && (println("_redirecciones.json al día ($n redirecciones)."); return)
        println("_redirecciones.json no está al día: ejecuta scripts/generar_redirecciones.jl.")
        exit(1)
    end
    write(SALIDA, texto)
    println("_redirecciones.json: $n redirecciones (", texto == actual ? "sin cambios" : "actualizado", ").")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
