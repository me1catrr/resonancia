# Versión con un error típico de índices (para el ejercicio de depuración de C5.4).
function media_movil_mala(x, n)
    y = Float64[]
    for i in 1:length(x)-n          # ¿falta algo?
        push!(y, sum(x[i:i+n-1]) / n)
    end
    return y
end
