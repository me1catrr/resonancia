"""
    leer_torroja(ruta) -> (t, a, fs, estacion, inicio)

Lee un fichero de estación del puente de Torroja (`datos/reales-publicables/torroja-puente/`):
4 líneas de cabecera (`Station_code`, `Sampling_rate`, `Start_date`, nombres de columna) y después
`hh:mm:ss.mmm X Y Z` separados por espacios. Devuelve el tiempo `t` en segundos desde la primera
muestra, la matriz `a` (N×3, ejes X, Y, Z en g), la frecuencia de muestreo `fs` (Hz), el código de
estación y la hora de la primera muestra (`"hh:mm:ss.mmm"`).
"""
function leer_torroja(ruta::AbstractString)
    estacion = ""
    fs = NaN
    t = Float64[]
    filas = Vector{NTuple{3,Float64}}()
    inicio = ""
    for (i, linea) in enumerate(eachline(ruta))
        if i == 1
            estacion = String(split(linea)[2])
        elseif i == 2
            fs = parse(Float64, split(linea)[2])
        elseif i > 4 && !isempty(strip(linea))
            c = split(linea)
            length(c) == 4 || throw(ArgumentError("línea $i con $(length(c)) columnas, se esperaban 4"))
            h = split(c[1], ':')
            seg = 3600 * parse(Float64, h[1]) + 60 * parse(Float64, h[2]) + parse(Float64, h[3])
            isempty(t) && (inicio = String(c[1]))
            push!(t, seg)
            push!(filas, (parse(Float64, c[2]), parse(Float64, c[3]), parse(Float64, c[4])))
        end
    end
    isempty(t) && throw(ArgumentError("sin datos en $ruta"))
    a = Matrix{Float64}(undef, length(filas), 3)
    for (i, fila) in enumerate(filas)
        a[i, 1], a[i, 2], a[i, 3] = fila
    end
    return t .- t[1], a, fs, estacion, inicio
end

"""
    leer_aceleracion_csv(ruta; hasta=Inf) -> (t, a, fs)

Lee un CSV de aceleración de Palma del Río: separador `;`, cabecera `tiempo_s;aceleracion_g`.
Devuelve tiempo `t` (s), aceleración `a` (g) y la frecuencia de muestreo `fs = (N-1)/(t_N-t₁)`
(más fiable que `1/(t₂-t₁)`, porque los tiempos del fichero están redondeados a 9 decimales).
`hasta` limita la lectura a las muestras con `t < hasta` segundos.
"""
function leer_aceleracion_csv(ruta::AbstractString; hasta::Real=Inf)
    t = Float64[]
    a = Float64[]
    for (i, linea) in enumerate(eachline(ruta))
        i == 1 && (linea == "tiempo_s;aceleracion_g" || throw(ArgumentError("cabecera inesperada en $ruta: «$linea»")); continue)
        k = findfirst(';', linea)
        ti = parse(Float64, view(linea, 1:k-1))
        ti >= hasta && break
        push!(t, ti)
        push!(a, parse(Float64, view(linea, k+1:lastindex(linea))))
    end
    length(t) >= 2 || throw(ArgumentError("muy pocas muestras en $ruta"))
    return t, a, (length(t) - 1) / (t[end] - t[1])
end
