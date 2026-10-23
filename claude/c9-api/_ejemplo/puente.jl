# Julia → cliente de Python (verificado). No hay SDK oficial de Julia: la vía más sencilla y auditable es llamar al
# cliente probado de Python como subproceso. Julia solo usa la biblioteca estándar.
#   julia --project=. claude/c9-api/_ejemplo/puente.jl
using Test

const RAIZ_EJEMPLO = @__DIR__

"Resume `texto` con el cliente Python. `simulado=true` usa el transporte falso (sin red, sin clave, sin coste)."
function resumir_con_python(texto::AbstractString; simulado::Bool = true, modelo = "claude-sonnet-5-5")
    orden = `uv run --with anthropic --with httpx2 python $(joinpath(RAIZ_EJEMPLO, "cliente_claude.py")) $texto --modelo $modelo`
    simulado && (orden = `$orden --simulado`)
    salida = read(orden, String)                     # lanza ProcessFailedException si el código de salida ≠ 0
    campo(nombre, patron) = match(Regex("\"$nombre\": $patron"), salida)
    (texto = campo("texto", "\"([^\"]*)\"").captures[1],
     tokens_entrada = parse(Int, campo("tokens_entrada", "(\\d+)").captures[1]),
     tokens_salida = parse(Int, campo("tokens_salida", "(\\d+)").captures[1]),
     coste_usd = parse(Float64, campo("coste_usd", "([0-9.e-]+)").captures[1]))
end

if abspath(PROGRAM_FILE) == @__FILE__()
    @testset "puente Julia → Python (simulado)" begin
        r = resumir_con_python("Informe de ventas del primer trimestre con tres regiones")
        @test startswith(r.texto, "Resumen simulado de:")
        @test r.tokens_entrada == 25 && r.tokens_salida == 12
        @test r.coste_usd ≈ 0.00017
        @test_throws ProcessFailedException read(`uv run --with anthropic --with httpx2 python $(joinpath(RAIZ_EJEMPLO, "cliente_claude.py"))`, String)
    end
end
