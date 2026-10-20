#!/usr/bin/env julia
# =============================================================================
# generar_estructura.jl — genera el esqueleto de la web a partir de temario.yml
#
# Uso (desde la raíz del repositorio):
#   julia --project=. scripts/generar_estructura.jl [--dry-run | --comprobar]
#
# Crea carpetas, index.qmd y slides.qmd de cada unidad, los index.qmd de vía
# y de nivel (J), recursos/bibliografia.bib y _navegacion.yml.
#
# Es idempotente: nunca sobrescribe un fichero .qmd o .bib existente. Solo
# _navegacion.yml se regenera siempre, porque deriva por completo del temario.
# No escribe contenido didáctico: solo cabeceras, secciones vacías y listados.
#
#   --dry-run    simula la generación y muestra el resumen sin escribir nada.
#   --comprobar  no escribe nada: compara la cabecera de cada index.qmd existente
#                (title, requiere, perfil, sesion, practica) con temario.yml y
#                lista las discrepancias. Código de salida 1 si las hay.
# =============================================================================

using YAML

const RAIZ = normpath(joinpath(@__DIR__, ".."))
const DRY = "--dry-run" in ARGS

# Vías con plantilla de unidad y diapositivas (R lleva cabecera mínima).
const VIAS_DOCENTES = ("M", "J", "C", "L")

# Etiquetas cortas de la barra superior (si falta una vía, se usa su título).
const ETIQUETA_NAVBAR = Dict(
    "M" => "M · MSE", "J" => "J · Julia", "C" => "C · Claude",
    "L" => "L · Laboratorios", "R" => "R · Recursos",
)

const NOMBRE_LENGUAJE = Dict("c++" => "C++", "python" => "Python", "julia" => "Julia")

# Las unidades de recursos (R) no declaran perfil en temario.yml.
const PERFIL_R = ["mse", "uco", "planta"]

# ---------------------------------------------------------------------------
# Utilidades de texto
# ---------------------------------------------------------------------------

yq(s) = "\"" * replace(string(s), "\\" => "\\\\", "\"" => "\\\"") * "\""
lista(v) = "[" * join(string.(v), ", ") * "]"
lista_q(v) = "[" * join(yq.(v), ", ") * "]"

ancla(id) = lowercase(replace(id, "." => "-"))
orden_tema(k) = parse(Int, last(split(k, '.')))
etiqueta(e) = "$(e["id"]) · $(e["titulo"])"

function ruta_relativa(desde_dir, hacia_fichero)
    r = relpath(joinpath(RAIZ, hacia_fichero), joinpath(RAIZ, desde_dir))
    return replace(r, "\\" => "/")
end

# ---------------------------------------------------------------------------
# Carga y validación del temario
# ---------------------------------------------------------------------------

function cargar_temario()
    d = YAML.load_file(joinpath(RAIZ, "temario.yml"); dicttype = Dict{String,Any})
    vias = Dict{String,Any}[]
    niveles = Dict{String,Any}[]
    unidades = Dict{String,Any}[]
    for v in d["vias"]
        v = Dict{String,Any}(v)
        push!(vias, v)
        if haskey(v, "niveles")
            for n in v["niveles"]
                n = Dict{String,Any}(n)
                n["via"] = v["id"]
                n["dir"] = joinpath(v["carpeta"], n["carpeta"])
                n["ruta"] = joinpath(n["dir"], "index.qmd")
                push!(niveles, n)
                for u in n["unidades"]
                    u = Dict{String,Any}(u)
                    u["via"] = v["id"]
                    u["nivel"] = n["id"]
                    u["nivel_titulo"] = n["titulo"]
                    u["dir"] = joinpath(n["dir"], u["slug"])
                    push!(unidades, u)
                end
            end
        else
            for u in v["unidades"]
                u = Dict{String,Any}(u)
                u["via"] = v["id"]
                u["dir"] = joinpath(v["carpeta"], u["slug"])
                push!(unidades, u)
            end
        end
        v["ruta"] = joinpath(v["carpeta"], "index.qmd")
    end
    for u in unidades
        u["ruta"] = joinpath(u["dir"], "index.qmd")
    end
    return d, vias, niveles, unidades
end

function validar(vias, niveles, unidades)
    errores = String[]
    indice = Dict{String,Dict{String,Any}}()
    for e in Iterators.flatten((niveles, unidades))
        haskey(indice, e["id"]) && push!(errores, "identificador repetido: $(e["id"])")
        indice[e["id"]] = e
    end
    dirs = Dict{String,String}()
    for u in unidades
        if haskey(dirs, u["dir"])
            push!(errores, "carpeta repetida $(u["dir"]): $(dirs[u["dir"]]) y $(u["id"])")
        end
        dirs[u["dir"]] = u["id"]
        for r in get(u, "requiere", [])
            haskey(indice, string(r)) ||
                push!(errores, "$(u["id"]) requiere «$r», que no existe en temario.yml")
        end
        if u["via"] in ("M", "C", "L") && !haskey(u, "temas")
            push!(errores, "$(u["id"]) no tiene `temas`")
        end
    end
    isempty(errores) || error("temario.yml no es válido:\n  - " * join(errores, "\n  - "))
    return indice
end

# ---------------------------------------------------------------------------
# Escritura idempotente con recuento
# ---------------------------------------------------------------------------

const CREADOS = Dict{String,Int}()
const OMITIDOS = Dict{String,Vector{String}}()

function escribir_si_no_existe(ruta, texto, categoria)
    destino = joinpath(RAIZ, ruta)
    if isfile(destino)
        push!(get!(OMITIDOS, categoria, String[]), ruta)
        return false
    end
    if !DRY
        mkpath(dirname(destino))
        write(destino, texto)
    end
    CREADOS[categoria] = get(CREADOS, categoria, 0) + 1
    return true
end

# ---------------------------------------------------------------------------
# Unidades
# ---------------------------------------------------------------------------

function subtitulo(u)
    partes = [u["id"]]
    haskey(u, "sesion") && push!(partes, "Sesión " * u["sesion"])
    haskey(u, "practica") && push!(partes, "Práctica " * u["practica"])
    haskey(u, "nivel") && push!(partes, "Nivel $(u["nivel"]) · $(u["nivel_titulo"])")
    length(partes) == 1 && push!(partes, "Vía " * u["via"])
    return join(partes, " · ")
end

const R6_LISTADO = """
listing:
  type: table
  sort: false
  sort-ui: true
  contents:
    - "../../mse/*/index.qmd"
    - "../../julia/*/*/index.qmd"
    - "../../claude/*/index.qmd"
    - "../../labs/*/index.qmd"
  fields: [id, title, via, estado, requiere]
  field-display-names:
    id: Id
    title: Título
    via: Vía
    estado: Estado
    requiere: Requiere
"""

function cabecera_unidad(u)
    docente = u["via"] in VIAS_DOCENTES
    io = IOBuffer()
    println(io, "---")
    println(io, "id: ", u["id"])
    println(io, "title: ", yq(u["titulo"]))
    docente && println(io, "subtitle: ", yq(subtitulo(u)))
    println(io, "via: ", u["via"])
    haskey(u, "nivel") && println(io, "nivel: ", u["nivel"])
    haskey(u, "sesion") && println(io, "sesion: ", u["sesion"])
    haskey(u, "practica") && println(io, "practica: ", u["practica"])
    if docente
        println(io, "requiere: ", lista(get(u, "requiere", [])))
        println(io, "perfil: ", lista(u["perfil"]))
    else
        println(io, "perfil: ", lista(PERFIL_R))
    end
    haskey(u, "python") && println(io, "python: ", u["python"])
    haskey(u, "lenguajes") && println(io, "lenguajes: ", lista_q(u["lenguajes"]))
    haskey(u, "opcional") && println(io, "opcional: ", u["opcional"])
    haskey(u, "provisional") && println(io, "provisional: ", u["provisional"])
    println(io, "estado: borrador")
    if u["via"] == "C"
        println(io, "verificado:")
        println(io, "  claude-code: \"\"")
        println(io, "  julia: \"\"")
    end
    if u["id"] == "R5"
        println(io, "nocite: \"@*\"")
    elseif u["id"] == "R6"
        print(io, R6_LISTADO)
    end
    if docente
        println(io, "format:")
        println(io, "  html:")
        println(io, "    other-links:")
        println(io, "      - text: Diapositivas")
        println(io, "        href: slides.qmd")
    end
    println(io, "---")
    return String(take!(io))
end

function prerrequisitos(u, indice)
    ids = string.(get(u, "requiere", []))
    isempty(ids) && return "Ninguno declarado en `temario.yml`."
    enlaces = map(ids) do id
        e = indice[id]
        "[$(etiqueta(e))]($(ruta_relativa(u["dir"], e["ruta"])))"
    end
    return join(enlaces, ", ")
end

function pestanas(u)
    langs = if haskey(u, "lenguajes")
        [get(NOMBRE_LENGUAJE, string(l), string(l)) for l in u["lenguajes"]]
    elseif get(u, "python", false) == true
        ["Julia", "Python"]
    else
        String[]
    end
    isempty(langs) && return ""
    return "::: {.panel-tabset}\n" * join(("## $l\n" for l in langs), "\n") * ":::\n"
end

function cuerpo_unidad(u, indice)
    io = IOBuffer()
    println(io, "## Objetivos y prerrequisitos\n")
    println(io, "**Objetivos.** <!-- Qué sabrá hacer quien complete la unidad. -->\n")
    println(io, "**Prerrequisitos.** ", prerrequisitos(u, indice), "\n")
    temas = get(u, "temas", nothing)
    if temas !== nothing
        println(io, "**Temas de la unidad**\n")
        ids = sort!(collect(keys(temas)); by = orden_tema)
        for k in ids
            println(io, "- **$k** ", temas[k])
        end
        println(io, "\n## Teoría breve\n")
        for k in ids
            println(io, "### $k $(temas[k]) {#$(ancla(k))}\n")
        end
    else
        println(io, "**Contenidos**\n")
        for c in get(u, "contenidos", [])
            println(io, "- ", c)
        end
        println(io, "\n## Teoría breve\n")
    end
    println(io, "## Práctica guiada\n")
    tabs = pestanas(u)
    isempty(tabs) || println(io, tabs)
    println(io, "## «Pídeselo a Claude»\n")
    println(io, "::: {.callout-tip title=\"Prompt\"}")
    println(io, "<!-- Prompt para Claude Code. -->\n")
    println(io, "**Verifica.** <!-- Qué comprobar en la respuesta. -->")
    println(io, ":::\n")
    println(io, "## Ejercicios\n")
    println(io, "## La doy por superada si…")
    return String(take!(io))
end

function slides_unidad(u)
    return """
    ---
    title: $(yq(u["titulo"]))
    subtitle: $(yq(subtitulo(u)))
    format:
      revealjs:
        slide-number: true
    ---

    ## Objetivos
    """
end

function cuerpo_r(u)
    u["id"] == "R5" ? "\n::: {#refs}\n:::\n" : ""
end

function generar_unidades(unidades, indice)
    for u in unidades
        if u["via"] in VIAS_DOCENTES
            texto = cabecera_unidad(u) * "\n" * cuerpo_unidad(u, indice)
            escribir_si_no_existe(u["ruta"], texto, "index.qmd de unidad")
            escribir_si_no_existe(joinpath(u["dir"], "slides.qmd"), slides_unidad(u), "slides.qmd")
        else
            texto = cabecera_unidad(u) * cuerpo_r(u)
            escribir_si_no_existe(u["ruta"], texto, "index.qmd de unidad")
        end
    end
end

# ---------------------------------------------------------------------------
# Páginas de vía y de nivel
# ---------------------------------------------------------------------------

marcas(u) = (get(u, "opcional", false) == true ? " *(opcional)*" : "") *
            (get(u, "provisional", false) == true ? " *(provisional)*" : "")

# Columnas extra de la tabla de cada vía: (cabecera, función de celda).
function columnas_extra(via_id)
    via_id == "M" && return ("Sesión", u -> get(u, "sesion", ""))
    via_id == "L" && return ("Práctica", u -> get(u, "practica", ""))
    return nothing
end

function tabla_unidades(desde_dir, unidades, via_id; perfil = true, python = false)
    extra = columnas_extra(via_id)
    cab = ["Id", via_id == "R" ? "Recurso" : "Unidad"]
    extra === nothing || push!(cab, extra[1])
    python && push!(cab, "Python")
    perfil && push!(cab, "Perfil")
    io = IOBuffer()
    println(io, "| ", join(cab, " | "), " |")
    println(io, "|", repeat("---|", length(cab)))
    for u in unidades
        celdas = [u["id"],
                  "[$(u["titulo"])]($(ruta_relativa(desde_dir, u["ruta"])))$(marcas(u))"]
        extra === nothing || push!(celdas, string(extra[2](u)))
        python && push!(celdas, get(u, "python", false) == true ? "sí" : "")
        perfil && push!(celdas, join(get(u, "perfil", []), ", "))
        println(io, "| ", join(celdas, " | "), " |")
    end
    return String(take!(io))
end

function generar_vias(vias, niveles, unidades)
    for v in vias
        io = IOBuffer()
        println(io, "---")
        println(io, "title: ", yq("$(v["id"]) · $(v["titulo"])"))
        println(io, "via: ", v["id"])
        println(io, "---\n")
        haskey(v, "descripcion") && println(io, v["descripcion"], "\n")
        if haskey(v, "niveles")
            for n in niveles
                n["via"] == v["id"] || continue
                println(io, "## [", etiqueta(n), "](", ruta_relativa(v["carpeta"], n["ruta"]), ")\n")
                us = filter(u -> get(u, "nivel", "") == n["id"], unidades)
                println(io, tabla_unidades(v["carpeta"], us, v["id"]; python = true))
            end
        else
            us = filter(u -> u["via"] == v["id"], unidades)
            println(io, tabla_unidades(v["carpeta"], us, v["id"]; perfil = v["id"] != "R"))
        end
        escribir_si_no_existe(v["ruta"], String(take!(io)), "index.qmd de vía o nivel")
    end
    for n in niveles
        io = IOBuffer()
        println(io, "---")
        println(io, "title: ", yq(etiqueta(n)))
        println(io, "via: ", n["via"])
        println(io, "nivel: ", n["id"])
        println(io, "---\n")
        us = filter(u -> get(u, "nivel", "") == n["id"], unidades)
        println(io, tabla_unidades(n["dir"], us, n["via"]; python = true))
        escribir_si_no_existe(n["ruta"], String(take!(io)), "index.qmd de vía o nivel")
    end
end

# ---------------------------------------------------------------------------
# Navegación
# ---------------------------------------------------------------------------

function navegacion(d, vias, niveles, unidades)
    io = IOBuffer()
    println(io, "# GENERADO por scripts/generar_estructura.jl a partir de temario.yml.")
    println(io, "# No editar a mano: se sobrescribe en cada ejecución.")
    println(io, "website:")
    println(io, "  navbar:")
    println(io, "    left:")
    println(io, "      - text: Inicio")
    println(io, "        href: index.qmd")
    for v in vias
        println(io, "      - text: ", yq(get(ETIQUETA_NAVBAR, v["id"], v["titulo"])))
        println(io, "        href: ", v["ruta"])
    end
    println(io, "    right:")
    println(io, "      - text: Acerca de")
    println(io, "        href: about.qmd")
    println(io, "      - icon: github")
    println(io, "        href: ", d["curso"]["repositorio"])
    println(io, "        aria-label: GitHub")
    println(io, "  sidebar:")
    for v in vias
        println(io, "    - id: ", v["carpeta"])
        println(io, "      title: ", yq("$(v["id"]) · $(v["titulo"])"))
        println(io, "      style: docked")
        println(io, "      collapse-level: 1")
        println(io, "      contents:")
        println(io, "        - text: Vista general")
        println(io, "          href: ", v["ruta"])
        if haskey(v, "niveles")
            for n in niveles
                n["via"] == v["id"] || continue
                println(io, "        - section: ", yq(etiqueta(n)))
                println(io, "          href: ", n["ruta"])
                println(io, "          contents:")
                for u in unidades
                    get(u, "nivel", "") == n["id"] || continue
                    println(io, "            - text: ", yq(etiqueta(u)))
                    println(io, "              href: ", u["ruta"])
                end
            end
        else
            for u in unidades
                u["via"] == v["id"] || continue
                println(io, "        - text: ", yq(etiqueta(u)))
                println(io, "          href: ", u["ruta"])
            end
        end
    end
    return String(take!(io))
end

function escribir_navegacion(texto)
    destino = joinpath(RAIZ, "_navegacion.yml")
    estado = !isfile(destino) ? "creado" : read(destino, String) == texto ? "sin cambios" : "actualizado"
    DRY || write(destino, texto)
    return estado
end

# ---------------------------------------------------------------------------
# Comprobación de cabeceras (--comprobar): solo lee, nunca escribe
# ---------------------------------------------------------------------------

const CAMPOS_COMPROBADOS = ("title", "requiere", "perfil", "sesion", "practica")

# Campos de la cabecera tal como los generaría cabecera_unidad.
function campos_esperados(u)
    e = Dict{String,Any}("title" => u["titulo"])
    if u["via"] in VIAS_DOCENTES
        e["requiere"] = string.(get(u, "requiere", []))
        e["perfil"] = string.(u["perfil"])
        haskey(u, "sesion") && (e["sesion"] = u["sesion"])
        haskey(u, "practica") && (e["practica"] = u["practica"])
    else
        e["perfil"] = PERFIL_R
    end
    return e
end

# Devuelve la cabecera como Dict, o un texto con el motivo si no se puede leer.
function leer_cabecera(destino)
    lineas = split(read(destino, String), '\n')
    (!isempty(lineas) && strip(lineas[1]) == "---") || return "no empieza por «---»"
    fin = findnext(l -> strip(l) == "---", lineas, 2)
    fin === nothing && return "la cabecera no se cierra con «---»"
    try
        c = YAML.load(join(lineas[2:fin-1], '\n'); dicttype = Dict{String,Any})
        return c === nothing ? Dict{String,Any}() : c
    catch err
        return "YAML no válido (" * first(split(sprint(showerror, err), '\n')) * ")"
    end
end

normalizar(x) = x isa AbstractVector ? sort!(string.(x)) : x === nothing ? nothing : string(x)
mostrar(x) = x === nothing ? "(ausente)" : x isa AbstractVector ? lista(x) : string(x)

# Devuelve el número de discrepancias.
function comprobar(unidades)
    discrepancias = 0
    con_discrepancias = 0
    ausentes = String[]
    for u in unidades
        destino = joinpath(RAIZ, u["ruta"])
        if !isfile(destino)
            push!(ausentes, u["id"])
            continue
        end
        cab = leer_cabecera(destino)
        if cab isa String
            println(u["id"], ": cabecera ilegible → ", cab)
            discrepancias += 1
            con_discrepancias += 1
            continue
        end
        esperado = campos_esperados(u)
        propias = 0
        for c in CAMPOS_COMPROBADOS
            e = haskey(esperado, c) ? normalizar(esperado[c]) : nothing
            f = haskey(cab, c) ? normalizar(cab[c]) : nothing
            e == f && continue
            println(u["id"], ": ", c, " → esperado ", mostrar(e), ", encontrado ", mostrar(f))
            propias += 1
        end
        discrepancias += propias
        con_discrepancias += propias > 0
    end
    println("$(length(unidades)) unidades: ",
            "$(length(unidades) - length(ausentes) - con_discrepancias) correctas, ",
            "$con_discrepancias con discrepancias ($discrepancias en total), ",
            "$(length(ausentes)) ficheros ausentes.")
    isempty(ausentes) || println("Ausentes: ", join(ausentes, ", "))
    return discrepancias
end

# ---------------------------------------------------------------------------
# Programa principal
# ---------------------------------------------------------------------------

function main()
    if "--comprobar" in ARGS
        if DRY
            println(stderr, "--comprobar y --dry-run no se pueden combinar.")
            exit(2)
        end
        _, vias, niveles, unidades = cargar_temario()
        validar(vias, niveles, unidades)
        exit(comprobar(unidades) == 0 ? 0 : 1)
    end

    d, vias, niveles, unidades = cargar_temario()
    indice = validar(vias, niveles, unidades)

    generar_unidades(unidades, indice)
    generar_vias(vias, niveles, unidades)
    escribir_si_no_existe(joinpath("recursos", "bibliografia.bib"), "", "bibliografia.bib")
    estado_nav = escribir_navegacion(navegacion(d, vias, niveles, unidades))

    println(DRY ? "== Simulación (--dry-run): no se ha escrito nada ==" : "== Estructura generada ==")
    categorias = sort!(collect(union(keys(CREADOS), keys(OMITIDOS))))
    for c in categorias
        println(rpad(c, 28), "creados: ", lpad(get(CREADOS, c, 0), 3),
                "   omitidos (ya existían): ", lpad(length(get(OMITIDOS, c, String[])), 3))
    end
    println(rpad("_navegacion.yml", 28), estado_nav)
    total_c = sum(values(CREADOS); init = 0)
    total_o = sum(length, values(OMITIDOS); init = 0)
    println("Total: $total_c creados, $total_o omitidos.")
    if 0 < total_o <= 20
        println("Omitidos:")
        foreach(r -> println("  ", r), Iterators.flatten(values(OMITIDOS)))
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
