# =============================================================================
# generar_hoja.jl: hoja de consulta de comandos de la vía C
#
# Uso: julia --project=. scripts/generar_hoja.jl [--comprobar]
# Lee claude/_curso/comandos.yml y escribe claude/hoja-consulta.qmd (página web
# imprimible) y claude/descargas/hoja-consulta.txt (descargable). No editar a mano ambos.
# Se omiten las entradas con estado «eliminado» o «no_existe»; las «pendiente»
# y «cambiado» se marcan. Con --comprobar solo verifica que estén al día.
# =============================================================================
using YAML

const RAIZ = dirname(@__DIR__)
const REG = YAML.load_file(joinpath(RAIZ, "claude", "_curso", "comandos.yml"))
const SECCIONES = [
    ("sistema", "Terminal (sistema)"), ("git", "Git"), ("herramienta", "Herramientas"),
    ("cli", "Subcomandos de `claude`"), ("opcion_cli", "Opciones al arrancar `claude`"),
    ("interactivo", "Comandos dentro de una sesión"), ("skill", "Skills incluidas"),
    ("atajo", "Atajos de teclado"), ("terceros", "Herramientas de terceros"),
]

esc(s) = replace(replace(string(s), "|" => "\\|"), "\n" => " ")
marca(c) = get(c, "estado", "") == "verificado" ? "" : " *(" * get(c, "estado", "") * ")*"

function cuerpo()
    io = IOBuffer()
    println(io, "Versión documentada de Claude Code: **", REG["doc_claude_code"], "** · instalada: ", REG["instalado_claude_code"],
        " · verificación: ", REG["fecha_verificacion"], ". Generada desde `claude/_curso/comandos.yml`.\n")
    for (tipo, titulo) in SECCIONES
        cs = [c for c in REG["comandos"] if c["tipo"] == tipo && !(c["estado"] in ("eliminado", "no_existe"))]
        isempty(cs) && continue
        println(io, "## ", titulo, "\n")
        println(io, "| Comando | Qué hace | Precauciones |\n|---|---|---|")
        for c in cs
            println(io, "| `", esc(c["sintaxis"]), "`", marca(c), " | ", esc(c["que_hace"]), " | ", esc(get(c, "precauciones", "")), " |")
        end
        println(io)
    end
    String(take!(io))
end

qmd() = "---\ntitle: \"Hoja de consulta de comandos\"\nvia: C\ncitation-location: margin\n---\n\n" *
        "<a href=\"descargas/hoja-consulta.txt\" download>Descargar en texto (Markdown)</a>\n\n" * cuerpo()
md() = "# Hoja de consulta de comandos\n\n" * cuerpo()

ficheros = [joinpath(RAIZ, "claude", "hoja-consulta.qmd") => qmd(), joinpath(RAIZ, "claude", "descargas", "hoja-consulta.txt") => md()]
if "--comprobar" in ARGS
    ok = all(isfile(f) && read(f, String) == t for (f, t) in ficheros)
    println(ok ? "Hoja de consulta al día." : "ERROR: la hoja está desactualizada; ejecuta scripts/generar_hoja.jl")
    ok || exit(1)
else
    for (f, t) in ficheros
        write(f, t)
        println("Escrito ", relpath(f, RAIZ))
    end
end
