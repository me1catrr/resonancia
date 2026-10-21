#!/usr/bin/env julia
# =============================================================================
# compilar_tikz.jl: compila las figuras TikZ de Resonancia a SVG
#
# Uso (desde la raíz del repositorio):
#   julia --project=. scripts/compilar_tikz.jl [--comprobar] [ruta.tex …]
#
# Busca ficheros fig/*.tex (documentclass standalone) en mse/, julia/, claude/,
# labs/ y recursos/, los compila con pdflatex y los convierte a SVG con
# pdftocairo (el texto queda como trazos: no depende de fuentes del lector).
# El estilo común está en recursos/tikz/resonancia.sty.
#
#   (sin opciones)  compila todas las figuras cuyo SVG falte o esté
#                   desactualizado, y las que se indiquen explícitamente.
#   --comprobar     no compila ni escribe nada: comprueba que cada .tex tiene su
#                   SVG y que este lleva la huella (SHA-256) del .tex y del .sty
#                   actuales. Código de salida 1 si algo está desactualizado.
#
# Se commitean los SVG: la publicación en GitHub no tiene LaTeX y los lee tal
# cual (como ocurre con _freeze/). Tras editar un .tex, vuelve a ejecutar este
# script y commitea el .tex y el .svg juntos.
# =============================================================================

using SHA

const RAIZ = normpath(joinpath(@__DIR__, ".."))
const ESTILO = joinpath(RAIZ, "recursos", "tikz", "resonancia.sty")
const CARPETAS = ["mse", "julia", "claude", "labs", "recursos"]
const COMPROBAR = "--comprobar" in ARGS
const EXPLICITAS = filter(a -> !startswith(a, "--"), ARGS)

huella(ruta) = bytes2hex(sha256(read(ruta)))
huella_conjunta(tex) = bytes2hex(sha256(vcat(read(tex), read(ESTILO))))

function figuras()
    if !isempty(EXPLICITAS)
        return [abspath(a) for a in EXPLICITAS]
    end
    out = String[]
    for c in CARPETAS
        base = joinpath(RAIZ, c)
        isdir(base) || continue
        for (dir, _, ficheros) in walkdir(base)
            basename(dir) == "fig" || continue
            for f in ficheros
                endswith(f, ".tex") && push!(out, joinpath(dir, f))
            end
        end
    end
    return sort(out)
end

svg_de(tex) = replace(tex, r"\.tex$" => ".svg")

function huella_en_svg(svg)
    isfile(svg) || return nothing
    m = match(r"<!-- fuente-sha256: ([0-9a-f]{64}) -->", read(svg, String))
    return m === nothing ? nothing : m.captures[1]
end

function compilar(tex)
    svg = svg_de(tex)
    nombre = splitext(basename(tex))[1]
    tmp = mktempdir()
    env = copy(ENV)
    env["TEXINPUTS"] = dirname(ESTILO) * ":" * get(ENV, "TEXINPUTS", "")
    cmd = Cmd(`pdflatex -interaction=nonstopmode -halt-on-error -output-directory=$tmp $tex`; env = env)
    salida = IOBuffer()
    ok = success(pipeline(ignorestatus(cmd); stdout = salida, stderr = salida))
    pdf = joinpath(tmp, nombre * ".pdf")
    if !ok || !isfile(pdf)
        println(stderr, "ERROR al compilar ", relpath(tex, RAIZ), ":")
        log = String(take!(salida))
        lineas = split(log, '\n')
        i = findfirst(l -> startswith(l, "!"), lineas)
        println(stderr, join(lineas[i === nothing ? max(1, length(lineas) - 15) : i:min(end, (i === nothing ? length(lineas) : i + 8))], '\n'))
        return false
    end
    crudo = joinpath(tmp, nombre * ".svg")
    run(`pdftocairo -svg $pdf $crudo`)
    contenido = read(crudo, String)
    sello = "<!-- fuente-sha256: $(huella_conjunta(tex)) -->\n"
    # el sello va tras la declaración XML, si existe
    contenido = occursin(r"^<\?xml[^>]*\?>\s*", contenido) ?
        replace(contenido, r"^(<\?xml[^>]*\?>\s*)" => SubstitutionString("\\1" * sello); count = 1) :
        sello * contenido
    write(svg, contenido)
    println("OK  ", relpath(svg, RAIZ), "  (", filesize(svg) ÷ 1024, " kB)")
    return true
end

function main()
    lista = figuras()
    if isempty(lista)
        println("No hay figuras TikZ (fig/*.tex).")
        return 0
    end
    if COMPROBAR
        malas = 0
        for tex in lista
            svg = svg_de(tex)
            h = huella_en_svg(svg)
            if h === nothing
                println("FALTA o sin huella: ", relpath(svg, RAIZ)); malas += 1
            elseif h != huella_conjunta(tex)
                println("DESACTUALIZADO:     ", relpath(svg, RAIZ)); malas += 1
            end
        end
        println(length(lista), " figuras, ", malas, " con problemas.")
        return malas == 0 ? 0 : 1
    end
    errores = 0
    for tex in lista
        svg = svg_de(tex)
        vigente = isempty(EXPLICITAS) && huella_en_svg(svg) == huella_conjunta(tex)
        if vigente
            println("al día  ", relpath(svg, RAIZ))
            continue
        end
        compilar(tex) || (errores += 1)
    end
    return errores == 0 ? 0 : 1
end

exit(main())
