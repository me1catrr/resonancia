# Comprueba datos/reales-publicables/: ficha por campaña, tamaño, ficheros no deseados y EXIF.
# Uso: julia --project=. scripts/comprobar_datos.jl

const RAIZ = joinpath(@__DIR__, "..", "datos", "reales-publicables")
const MAX_BYTES = 50 * 1024^2
const PROHIBIDOS = [".DS_Store", ".zip", ".rar", ".fig", ".eps", ".umc", ".rtf"]

errores = String[]
rel(p) = relpath(p, RAIZ)

for (dir, _, ficheros) in walkdir(RAIZ), f in ficheros
    p = joinpath(dir, f)
    ext = lowercase(splitext(f)[2])
    if f == ".DS_Store" || ext in PROHIBIDOS
        push!(errores, "fichero no permitido: $(rel(p))")
    end
    filesize(p) > MAX_BYTES && push!(errores, "supera 50 MB: $(rel(p))")
    occursin(r"[ áéíóúñÁÉÍÓÚÑ]", f) && push!(errores, "nombre con espacios o acentos: $(rel(p))")
    if ext == ".csv" && occursin(r"harvester|C9|C10"i, first(eachline(p)))
        push!(errores, "canal de harvester en $(rel(p))")
    end
    if ext in (".jpg", ".jpeg") && occursin("Exif", String(read(p, 4096)))
        push!(errores, "foto con EXIF: $(rel(p))")
    end
end

# cada carpeta con crudos/ o extractos/ o fotos/ necesita su ficha
for (dir, subdirs, _) in walkdir(RAIZ)
    if any(in(subdirs), ("crudos", "extractos", "fotos"))
        isfile(joinpath(dir, "campana.meta.toml")) ||
            push!(errores, "falta campana.meta.toml en $(rel(dir))")
    end
end

if isempty(errores)
    println("datos/reales-publicables: todo correcto")
else
    foreach(e -> println("ERROR: ", e), errores)
    exit(1)
end
