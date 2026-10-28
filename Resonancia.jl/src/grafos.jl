# Constructores de grafos para SHM (J3.9): red inalámbrica de sensores, estructura reticulada y
# grafo de una matriz de rigidez. Devuelven matrices de adyacencia dispersas y listas de aristas;
# la unidad J3.9 las entrega a Graphs.jl (`SimpleGraph(A)`). El paquete no depende de Graphs.jl.

"""
    red_sensores(pos; alcance) -> SparseMatrixCSC{Float64}

Matriz de adyacencia ponderada de una red inalámbrica de sensores. `pos` es una matriz `n × d` con las
coordenadas (m) de los `n` nodos; dos nodos distintos están conectados si su distancia euclídea es como máximo
`alcance` (m), y el peso de la arista es esa distancia. La matriz es simétrica, de diagonal nula, y un
elemento nulo significa «sin enlace».
"""
function red_sensores(pos::AbstractMatrix{<:Real}; alcance::Real)
    alcance > 0 || throw(ArgumentError("el alcance debe ser positivo"))
    n = size(pos, 1)
    I_, J_, V_ = Int[], Int[], Float64[]
    for i in 1:n-1, j in i+1:n
        d = norm(view(pos, i, :) .- view(pos, j, :))
        if d <= alcance
            append!(I_, (i, j)); append!(J_, (j, i)); append!(V_, (d, d))
        end
    end
    return sparse(I_, J_, V_, n, n)
end

"""
    reticulado_plano(nx, ny; dx=1.0, dy=1.0, diagonales=true) -> (pos, barras)

Reticulado plano de `nx × ny` paneles rectangulares de `dx × dy` metros. Los nodos se numeran por filas, de
izquierda a derecha y de abajo arriba (`(nx+1)(ny+1)` nodos; el nodo de la columna `i` y la fila `j`, con `i` y `j`
desde 0, es el `j(nx+1) + i + 1`). `pos` es la matriz `n × 2` de coordenadas y `barras` el vector de pares
`(i, j)` con `i < j`: cordones horizontales, montantes verticales y, si `diagonales`, una diagonal por panel
(de pendiente alternada, tipo Pratt/Warren).
"""
function reticulado_plano(nx::Integer, ny::Integer; dx::Real=1.0, dy::Real=1.0, diagonales::Bool=true)
    (nx >= 1 && ny >= 1) || throw(ArgumentError("nx y ny deben ser al menos 1"))
    nodo(i, j) = j * (nx + 1) + i + 1
    pos = zeros((nx + 1) * (ny + 1), 2)
    for j in 0:ny, i in 0:nx
        pos[nodo(i, j), :] = [i * dx, j * dy]
    end
    barras = Tuple{Int,Int}[]
    for j in 0:ny, i in 0:nx
        i < nx && push!(barras, (nodo(i, j), nodo(i + 1, j)))
        j < ny && push!(barras, (nodo(i, j), nodo(i, j + 1)))
        if diagonales && i < nx && j < ny
            iseven(i + j) ? push!(barras, (nodo(i, j), nodo(i + 1, j + 1))) : push!(barras, (nodo(i + 1, j), nodo(i, j + 1)))
        end
    end
    return pos, barras
end

"""
    adyacencia_barras(n, barras; pesos=nothing) -> SparseMatrixCSC{Float64}

Matriz de adyacencia simétrica de `n` nodos con las aristas `barras` (pares `(i, j)`). Sin `pesos`, cada elemento
vale 1; con `pesos` (un valor por barra, p. ej. rigideces o longitudes), vale el peso de la barra.
"""
function adyacencia_barras(n::Integer, barras::AbstractVector{<:Tuple{<:Integer,<:Integer}}; pesos=nothing)
    pesos === nothing || length(pesos) == length(barras) || throw(ArgumentError("hace falta un peso por barra"))
    all(b -> 1 <= b[1] <= n && 1 <= b[2] <= n && b[1] != b[2], barras) ||
        throw(ArgumentError("las barras deben unir dos nodos distintos entre 1 y n"))
    w = pesos === nothing ? ones(length(barras)) : float.(pesos)
    I_ = vcat([b[1] for b in barras], [b[2] for b in barras])
    J_ = vcat([b[2] for b in barras], [b[1] for b in barras])
    return sparse(I_, J_, vcat(w, w), n, n)
end

"""
    longitudes_barras(pos, barras) -> Vector{Float64}

Longitud (m) de cada barra de un reticulado con coordenadas `pos` (`n × d`).
"""
longitudes_barras(pos::AbstractMatrix{<:Real}, barras::AbstractVector{<:Tuple{<:Integer,<:Integer}}) =
    [norm(view(pos, i, :) .- view(pos, j, :)) for (i, j) in barras]

"""
    grafo_de_matriz(K; tol=0.0) -> SparseMatrixCSC{Float64}

Matriz de adyacencia (con unos) del grafo asociado a una matriz simétrica `K`: los nodos son los grados de libertad
y hay una arista entre `i ≠ j` si `|K[i,j]| > tol`. Las componentes conexas del grafo son los bloques desacoplados
de `K`.
"""
function grafo_de_matriz(K::AbstractMatrix{<:Real}; tol::Real=0.0)
    n, m = size(K)
    n == m || throw(ArgumentError("K debe ser cuadrada"))
    I_, J_ = Int[], Int[]
    for j in 1:n, i in 1:n
        i != j && abs(K[i, j]) > tol && (push!(I_, i); push!(J_, j))
    end
    return sparse(I_, J_, ones(length(I_)), n, n)
end

"""
    laplaciana(W) -> Matrix{Float64}

Matriz laplaciana `D - W` de un grafo con matriz de adyacencia (o de pesos) simétrica `W`, siendo `D` la diagonal de
las sumas de cada fila. Si los pesos son rigideces de muelles, es la matriz de rigidez de la red de masas y muelles
sin apoyos: su núcleo tiene tantas dimensiones como componentes conexas (modos de sólido rígido).
"""
function laplaciana(W::AbstractMatrix{<:Real})
    size(W, 1) == size(W, 2) || throw(ArgumentError("W debe ser cuadrada"))
    Wd = Matrix{Float64}(W)
    Wd ≈ Wd' || throw(ArgumentError("W debe ser simétrica"))
    return Diagonal(vec(sum(Wd, dims=2))) - Wd
end
