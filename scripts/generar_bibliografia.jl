#!/usr/bin/env julia
# =============================================================================
# generar_bibliografia.jl: genera R5 (recursos/r5-bibliografia/index.qmd)
# a partir de recursos/bibliografia.bib y de las citas de las páginas.
#
# Uso (desde la raíz del repositorio):
#   julia --project=. scripts/generar_bibliografia.jl [--comprobar]
#
# Por cada entrada muestra: la referencia, su enlace (DOI o URL), el estado de
# verificación y las unidades que la citan («Citada en…»). Las entradas se
# agrupan por el campo `keywords` del .bib. Es la ÚNICA fuente de R5: no se
# edita a mano. Campos propios del .bib: keywords y verificado (véase su
# cabecera).
#
#   --comprobar  no escribe nada: sale con código 1 si R5 no coincide con lo que
#                generaría el script (por ejemplo, tras añadir una cita).
# =============================================================================

const RAIZ = normpath(joinpath(@__DIR__, ".."))
const BIB = joinpath(RAIZ, "recursos", "bibliografia.bib")
const SALIDA = joinpath(RAIZ, "recursos", "r5-bibliografia", "index.qmd")
const CARPETAS = ["mse", "julia", "claude", "labs", "recursos"]
const COMPROBAR = "--comprobar" in ARGS

const GRUPOS = [
    "shm" => "Monitorización de la salud estructural",
    "vibraciones" => "Teoría de vibraciones y análisis modal",
    "ia" => "IA, fluencia y uso responsable",
    "normativa" => "Normativa",
]

# ---------- lectura del .bib (sin dependencias) ----------

function leer_bib(ruta)
    texto = read(ruta, String)
    # quita comentarios de línea completa
    texto = join(filter(l -> !startswith(lstrip(l), "%"), split(texto, '\n')), '\n')
    entradas = Vector{Dict{String,String}}()
    i = 1
    n = lastindex(texto)
    while (m = match(r"@(\w+)\s*\{\s*([^,\s]+)\s*,", texto, i)) !== nothing
        tipo = lowercase(m.captures[1]); clave = m.captures[2]
        j = m.offset + length(m.match)
        prof = 1; k = j
        while k <= n && prof > 0
            c = texto[k]
            c == '{' && (prof += 1)
            c == '}' && (prof -= 1)
            k = nextind(texto, k)
        end
        cuerpo = texto[j:prevind(texto, k, 2)]
        e = Dict{String,String}("tipo" => tipo, "clave" => clave)
        p = 1
        while (f = match(r"(\w+)\s*=\s*", cuerpo, p)) !== nothing
            nombre = lowercase(f.captures[1])
            q = f.offset + length(f.match)
            if q <= lastindex(cuerpo) && cuerpo[q] == '{'
                prof = 1; r = nextind(cuerpo, q)
                ini = r
                while r <= lastindex(cuerpo) && prof > 0
                    c = cuerpo[r]
                    c == '{' && (prof += 1)
                    c == '}' && (prof -= 1)
                    r = nextind(cuerpo, r)
                end
                e[nombre] = strip(cuerpo[ini:prevind(cuerpo, r, 2)])
                p = r
            else
                s = match(r"[^,\n]+", cuerpo, q)
                e[nombre] = s === nothing ? "" : strip(s.match)
                p = s === nothing ? q + 1 : s.offset + length(s.match)
            end
        end
        push!(entradas, e)
        i = k
    end
    return entradas
end

# ---------- formato ----------

function limpia(s)
    s = replace(s, "{\\'e}" => "é", "{\\'a}" => "á", "{\\'i}" => "í", "{\\'o}" => "ó", "{\\'u}" => "ú",
                "{\\~n}" => "ñ", "\\&" => "&", "--" => "–")
    s = replace(s, r"[{}]" => "")
    return strip(s)
end

function inicial(nombre)
    partes = split(strip(nombre))
    # «Hua-Peng» → «H.-P.»
    return join([join([string(first(q), ".") for q in split(p, "-")], "-") for p in partes], " ")
end

function persona(p)
    p = strip(p)
    if occursin(",", p)
        ap, nom = strip.(split(p, ",", limit = 2))
        return string(limpia(ap), ", ", inicial(limpia(nom)))
    end
    return limpia(p)
end

function lista_personas(s)
    ps = persona.(split(s, r"\s+and\s+"))
    length(ps) == 1 && return ps[1]
    return join(ps[1:end-1], ", ") * " y " * ps[end]
end

function formatea(e)
    autores = haskey(e, "author") ? lista_personas(e["author"]) :
              haskey(e, "editor") ? lista_personas(e["editor"]) * " (Eds.)" : ""
    anio = get(e, "year", "s. f.")
    titulo = limpia(get(e, "title", ""))
    t = e["tipo"]
    cola = ""
    if t == "article"
        vol = get(e, "volume", ""); num = haskey(e, "number") ? "($(e["number"]))" : ""
        pags = haskey(e, "pages") ? ", " * limpia(e["pages"]) : ""
        cola = "*" * limpia(get(e, "journal", "")) * "*" * (isempty(vol) ? "" : ", " * vol * num) * pags * "."
        return (isempty(autores) ? "" : autores * " ") * "($anio). " * titulo * ". " * cola
    elseif t == "book"
        ed = haskey(e, "edition") ? " ($(e["edition"]).ª ed.)" : ""
        return (isempty(autores) ? "" : autores * " ") * "($anio). *" * titulo * "*" * ed * ". " * limpia(get(e, "publisher", "")) * "."
    elseif t == "phdthesis"
        return autores * " ($anio). *" * titulo * "* [Tesis doctoral]. " * limpia(get(e, "school", "")) * "."
    elseif t == "techreport"
        num = haskey(e, "number") ? " (" * e["number"] * ")" : ""
        return (isempty(autores) ? "" : autores * " ") * "($anio). *" * titulo * "*" * num * ". " * limpia(get(e, "institution", "")) * "."
    elseif t == "inproceedings"
        pags = haskey(e, "pages") ? ", pp. " * limpia(e["pages"]) : ""
        return autores * " ($anio). " * titulo * ". En *" * limpia(get(e, "booktitle", "")) * "*" * pags * ". " * limpia(get(e, "publisher", "")) * "."
    else
        pre = isempty(autores) ? "" : autores * " ($anio). "
        post = haskey(e, "howpublished") ? " " * limpia(e["howpublished"]) * "." : ""
        return pre * (isempty(autores) ? titulo * " ($anio)." : "*" * titulo * "*.") * post
    end
end

function enlace(e)
    haskey(e, "doi") && return "https://doi.org/" * e["doi"]
    haskey(e, "url") && return e["url"]
    return nothing
end

function estado(e)
    v = get(e, "verificado", "no: sin información")
    if startswith(v, "sí")
        return "Verificada", strip(replace(v, r"^sí\s*:\s*" => ""))
    elseif startswith(v, "parcial")
        return "Verificada en parte", strip(replace(v, r"^parcial\s*:\s*" => ""))
    else
        return "Pendiente de cotejar", strip(replace(v, r"^no\s*:\s*" => ""))
    end
end

# ---------- qué páginas citan cada entrada ----------

function paginas_qmd()
    out = String[]
    for c in CARPETAS
        base = joinpath(RAIZ, c)
        isdir(base) || continue
        for (dir, _, fs) in walkdir(base)
            for f in fs
                endswith(f, ".qmd") && f != "slides.qmd" && push!(out, joinpath(dir, f))
            end
        end
    end
    return sort(filter(p -> p != SALIDA, out))
end

function id_de(ruta)
    m = match(r"^---\s*\n(.*?)\n---"s, read(ruta, String))
    m === nothing && return nothing
    mi = match(r"(?m)^id:\s*\"?([A-Za-z0-9.]+)\"?\s*$", m.captures[1])
    return mi === nothing ? nothing : mi.captures[1]
end

function citas(claves)
    res = Dict(k => Tuple{String,String}[] for k in claves)
    for p in paginas_qmd()
        id = id_de(p); id === nothing && continue
        # los .qmd con diapositivas se cuentan por su página principal
        texto = read(p, String)
        for k in claves
            if occursin(Regex("@" * k * "(?![A-Za-z0-9])"), texto)
                rel = replace(relpath(p, dirname(SALIDA)), "\\" => "/")
                push!(res[k], (id, rel))
            end
        end
    end
    return res
end

# ---------- salida ----------

function orden_id(id)
    m = match(r"^([A-Z]+)(\d*)", id)
    return (m.captures[1], isempty(m.captures[2]) ? 0 : parse(Int, m.captures[2]), id)
end

function generar()
    entradas = leer_bib(BIB)
    claves = [e["clave"] for e in entradas]
    cit = citas(claves)
    io = IOBuffer()
    println(io, "---")
    println(io, "id: R5")
    println(io, "title: \"Bibliografía\"")
    println(io, "via: R")
    println(io, "perfil: [mse, uco, planta]")
    println(io, "estado: borrador")
    println(io, "---")
    println(io)
    println(io, "<!-- Generado por scripts/generar_bibliografia.jl a partir de recursos/bibliografia.bib. No editar a mano. -->")
    println(io)
    println(io, "Fuente única de las referencias de Resonancia. Cada ficha indica **cómo se ha")
    println(io, "comprobado** (o que está pendiente de cotejar con el original) y **dónde se cita**.")
    println(io, "El texto de las obras no se reproduce: se cita y se redacta con palabras propias.")
    println(io)
    println(io, "::: {.callout-note title=\"Estado de las fichas\" appearance=\"simple\"}")
    println(io, "**Verificada**: comparada con el documento original o con la guía docente. ",
                "**Verificada en parte**: algún dato sin cotejar. ",
                "**Pendiente de cotejar**: ficha de memoria; no te fíes de ella sin comprobarla (véase [C0](../../claude/c0-fluidez/index.qmd)).")
    println(io, ":::")
    println(io)
    grupos = copy(GRUPOS)
    resto = unique([get(e, "keywords", "otros") for e in entradas])
    for r in resto
        any(g -> g[1] == r, grupos) || push!(grupos, r => titlecase(r))
    end
    for (kw, titulo) in grupos
        es = sort(filter(e -> get(e, "keywords", "otros") == kw, entradas), by = e -> (limpia(get(e, "author", get(e, "editor", get(e, "title", "")))), get(e, "year", "")))
        isempty(es) && continue
        println(io, "## ", titulo)
        println(io)
        for e in es
            est, detalle = estado(e)
            sim = est == "Verificada" ? "✔" : est == "Verificada en parte" ? "◐" : "○"
            println(io, "::: {#ref-", e["clave"], " .ref-ficha}")
            println(io, formatea(e))
            println(io)
            l = enlace(e)
            l === nothing || println(io, "[Enlace](", l, "){.ref-enlace target=\"_blank\"} · ")
            print(io, "<span class=\"ref-estado\">", sim, " ", est, "</span>")
            isempty(detalle) || print(io, " <span class=\"ref-detalle\">· ", detalle, "</span>")
            println(io)
            c = sort(unique(cit[e["clave"]]), by = t -> orden_id(t[1]))
            if isempty(c)
                println(io, "<br><span class=\"ref-citada\">Citada en: aún no.</span>")
            else
                enlaces = join(["[" * id * "](" * rel * ")" for (id, rel) in c], " · ")
                println(io, "<br><span class=\"ref-citada\">Citada en: ", enlaces, "</span>")
            end
            println(io, ":::")
            println(io)
        end
    end
    return String(take!(io))
end

function main()
    nuevo = generar()
    if COMPROBAR
        actual = isfile(SALIDA) ? read(SALIDA, String) : ""
        if actual == nuevo
            println("R5 está al día.")
            return 0
        end
        println("R5 NO coincide con lo que generaría el script: ejecuta scripts/generar_bibliografia.jl")
        return 1
    end
    mkpath(dirname(SALIDA))
    write(SALIDA, nuevo)
    println("Escrito ", relpath(SALIDA, RAIZ), " (", count("::: {#ref-", nuevo), " entradas)")
    return 0
end

exit(main())
