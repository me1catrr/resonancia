# =============================================================================
# auditar_claude.jl: comprueba la coherencia de la vía C
#
# Uso: julia --project=. scripts/auditar_claude.jl [--comprobar]
# Con --comprobar termina con código 1 si hay errores. Revisa:
#   - claude/_versiones.yml: una entrada por unidad de temario.yml con via C;
#   - claude/_curso/comandos.yml: campos obligatorios y estados válidos;
#   - versión de Claude Code instalada frente a la registrada (aviso, no error);
#   - unidades que citan comandos del registro con verificación pendiente.
# =============================================================================
using YAML

const RAIZ = dirname(@__DIR__)
const ESTADOS_CMD = ("verificado", "pendiente", "no_existe", "cambiado", "eliminado")
const ESTADOS_UNIDAD = ("verificado", "pendiente de revisión", "histórico")
const OBLIGATORIOS = ("id", "tipo", "sintaxis", "que_hace", "fuente", "verificado_en", "estado")

errores = String[]
avisos = String[]

versiones = YAML.load_file(joinpath(RAIZ, "claude", "_versiones.yml"))["versiones"]
registro = YAML.load_file(joinpath(RAIZ, "claude", "_curso", "comandos.yml"))
temario = YAML.load_file(joinpath(RAIZ, "temario.yml"))

# Unidades de la vía C: se buscan por carpeta para no depender de la forma del temario.
unidades = sort([d for d in readdir(joinpath(RAIZ, "claude")) if occursin(r"^c\d+-", d)])
ids = [uppercase(match(r"^(c\d+)-", d).captures[1]) for d in unidades]

for id in ids
    v = get(versiones, id, nothing)
    if v === nothing
        push!(errores, "_versiones.yml: falta la unidad $id")
        continue
    end
    get(v, "estado", "") in ESTADOS_UNIDAD || push!(errores, "_versiones.yml: estado no válido en $id")
    if get(v, "estado", "") == "verificado" && isempty(string(get(v, "verificacion", "")))
        push!(errores, "_versiones.yml: $id está «verificado» sin fecha de verificación")
    end
end
haskey(versiones, "curso") || push!(errores, "_versiones.yml: falta la entrada «curso»")

ids_cmd = String[]
for c in registro["comandos"]
    id = string(get(c, "id", "?"))
    push!(ids_cmd, id)
    for k in OBLIGATORIOS
        haskey(c, k) || push!(errores, "comandos.yml: «$id» sin campo $k")
    end
    get(c, "estado", "") in ESTADOS_CMD || push!(errores, "comandos.yml: «$id» con estado no válido")
    get(c, "estado", "") == "pendiente" && push!(avisos, "comandos.yml: «$id» pendiente de verificar")
end
length(unique(ids_cmd)) == length(ids_cmd) || push!(errores, "comandos.yml: identificadores repetidos")

instalada = try
    m = match(r"(\d+\.\d+\.\d+)", read(`claude --version`, String))
    m === nothing ? nothing : m.captures[1]
catch
    nothing
end
registrada = string(get(registro, "instalado_claude_code", ""))
if instalada === nothing
    push!(avisos, "No se pudo ejecutar `claude --version`; no se compara la versión instalada")
elseif instalada != registrada
    push!(avisos, "Claude Code instalado $instalada ≠ registrado $registrada: revisar comandos y unidades")
end

println("Unidades de la vía C: ", length(ids), " · comandos registrados: ", length(ids_cmd))
for a in avisos; println("AVISO  ", a); end
for e in errores; println("ERROR  ", e); end
if isempty(errores)
    println("Auditoría correcta (", length(avisos), " avisos).")
else
    "--comprobar" in ARGS && exit(1)
end
