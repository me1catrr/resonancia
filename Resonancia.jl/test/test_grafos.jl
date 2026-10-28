# Pruebas de src/grafos.jl (J3.9). Las incluye runtests.jl dentro de su `using Test` y `using Resonancia`.
# El paquete no depende de Graphs.jl: las componentes conexas se cuentan con el núcleo de la laplaciana.

using LinearAlgebra, SparseArrays

componentes(W) = count(<(1e-9), eigvals(Symmetric(laplaciana(W))))

@testset "red_sensores" begin
    pos = [0.0 0.0; 3.0 4.0; 6.0 8.0; 100.0 0.0]       # distancias: 5, 5, 10 y un nodo aislado
    W = red_sensores(pos; alcance=6.0)
    @test issymmetric(W)
    @test all(iszero, diag(W))
    @test W[1, 2] == 5.0 && W[2, 3] == 5.0
    @test W[1, 3] == 0.0                               # 10 m > alcance
    @test nnz(W) == 4                                  # dos enlaces, contados en las dos direcciones
    @test nnz(red_sensores(pos; alcance=10.0)) == 6    # ahora también el enlace 1–3 (10 m, límite incluido)
    @test componentes(red_sensores(pos; alcance=6.0)) == 2   # {1,2,3} y {4}
    @test componentes(red_sensores(pos; alcance=95.0)) == 1
    @test_throws ArgumentError red_sensores(pos; alcance=-1.0)
end

@testset "reticulado_plano" begin
    for (nx, ny) in [(1, 1), (6, 1), (4, 3)]
        pos, barras = reticulado_plano(nx, ny)
        @test size(pos) == ((nx + 1) * (ny + 1), 2)
        @test length(barras) == nx * (ny + 1) + ny * (nx + 1) + nx * ny      # horizontales + verticales + diagonales
        @test length(unique(barras)) == length(barras)
        @test all(b -> b[1] < b[2], barras)
        @test componentes(adyacencia_barras(size(pos, 1), barras)) == 1
    end
    pos, barras = reticulado_plano(2, 1; dx=2.0, dy=1.5)
    @test pos[end, :] == [4.0, 1.5]
    L = longitudes_barras(pos, barras)
    @test sort(unique(round.(L, digits=6))) == [1.5, 2.0, 2.5]               # verticales, horizontales y diagonales
    # Maxwell: el reticulado de 6 paneles con diagonales es isostático (b + 3 apoyos = 2 nudos)
    pos6, b6 = reticulado_plano(6, 1)
    @test length(b6) + 3 == 2 * size(pos6, 1)
    @test length(reticulado_plano(3, 1; diagonales=false)[2]) == 3 * 2 + 1 * 4
    @test_throws ArgumentError reticulado_plano(0, 2)
end

@testset "adyacencia_barras" begin
    barras = [(1, 2), (2, 3), (3, 4)]
    A = adyacencia_barras(4, barras)
    @test issymmetric(A)
    @test sum(A, dims=2) == [1.0, 2.0, 2.0, 1.0][:, :]              # grados de una cadena
    W = adyacencia_barras(4, barras; pesos=[10.0, 20.0, 30.0])
    @test W[3, 2] == 20.0
    @test_throws ArgumentError adyacencia_barras(4, barras; pesos=[1.0])
    @test_throws ArgumentError adyacencia_barras(3, barras)
    @test_throws ArgumentError adyacencia_barras(4, [(2, 2)])
end

@testset "grafo_de_matriz y laplaciana" begin
    _, K = cadena_masas_muelles(5)
    A = grafo_de_matriz(K)
    @test nnz(A) == 8                                              # 4 enlaces entre vecinos
    @test A[1, 2] == 1.0 && A[1, 3] == 0.0
    # dos bloques desacoplados → dos componentes
    Kb = [2.0 -1.0 0.0 0.0; -1.0 2.0 0.0 0.0; 0.0 0.0 3.0 -2.0; 0.0 0.0 -2.0 3.0]
    @test componentes(grafo_de_matriz(Kb)) == 2
    @test nnz(grafo_de_matriz(Kb; tol=2.5)) == 0
    # la laplaciana de una red de muelles es la rigidez libre-libre: núcleo = movimiento de sólido rígido
    W = adyacencia_barras(3, [(1, 2), (2, 3)]; pesos=[4.0, 6.0])
    L = laplaciana(W)
    @test L == [4.0 -4.0 0.0; -4.0 10.0 -6.0; 0.0 -6.0 6.0]
    @test L * ones(3) ≈ zeros(3)
    @test_throws ArgumentError laplaciana([0.0 1.0; 2.0 0.0])
    @test_throws ArgumentError grafo_de_matriz(ones(2, 3))
end
