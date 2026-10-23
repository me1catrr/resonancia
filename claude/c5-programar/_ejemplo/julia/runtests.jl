using Test
include("senales.jl")

@testset "media_movil" begin
    @test media_movil([1, 2, 3, 4, 5], 2) == [1.5, 2.5, 3.5, 4.5]
    @test length(media_movil(0:9, 4)) == 7
    @test media_movil([2, 4, 6], 3) == [4.0]
    for n in (0, -1, 6)
        @test_throws ArgumentError media_movil([1, 2, 3, 4, 5], n)
    end
end

@testset "detectar_picos" begin
    @test detectar_picos([0, 3, 1, 5, 2, 2, 4, 0], 0) == [2, 4, 7]   # índices desde 1
    @test detectar_picos([0, 3, 1, 5, 2, 2, 4, 0], 3.5) == [4, 7]
    @test detectar_picos([0, 2, 2, 0], 0) == Int[]
    t = 0:0.01:0.99
    @test length(detectar_picos(sin.(2π * 5 .* t), 0.5)) == 5
end
