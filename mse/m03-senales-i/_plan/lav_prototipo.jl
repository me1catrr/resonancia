using Resonancia, Statistics, Random, LinearAlgebra, Printf
# ---- escenario (supuestos del ejercicio) ----
lav_obras = [("Guadalmez", 798, 30), ("Tajo", 694, 17), ("Ciudad Real", 929, 33), ("Guadiana", 292, 6), ("Churreletes", 446, 11)]
lav_luz(L, n) = L / n
lav_L = lav_luz(798, 30)
lav_fn, lav_ζ = 4.0, 0.015
lav_d, lav_n = 18.0, 11
lav_fs, lav_T = 200.0, 120.0
lav_t = collect(0:1/lav_fs:lav_T-1/lav_fs)
function lav_modo(u, fn, ζ, fs)
    ω = 2π * fn; h = 1 / fs
    M = exp([0 1 0; -ω^2 -2ζ*ω 1; 0 0 0] * h)
    Φ, Γ = M[1:2, 1:2], M[1:2, 3]
    z = zeros(2); a = similar(u)
    for k in eachindex(u)
        a[k] = -2ζ * ω * z[2] - ω^2 * z[1] + u[k]
        z = Φ * z + Γ * u[k]
    end
    a
end
function lav_fuerza(t, v; t0=40.0)
    u = zeros(length(t))
    for k in 0:lav_n-1
        s = t .- (t0 + k * lav_d / v)
        u .+= ifelse.((s .>= 0) .& (s .<= lav_L / v), sin.(π * v .* s ./ lav_L), 0.0)
    end
    u
end
v_res = lav_fn * lav_d
rng = MersenneTwister(2026)
amb = lav_modo(randn(rng, length(lav_t)), lav_fn, lav_ζ, lav_fs)
amb .*= 0.0098 / sqrt(mean(abs2, amb))                       # RMS ambiental de 1 mg
tren_res = lav_modo(lav_fuerza(lav_t, v_res), lav_fn, lav_ζ, lav_fs)
P = 1.5 / maximum(abs, tren_res)                              # pico de 1,5 m/s² en el paso resonante
vel = Dict("200 km/h" => 200/3.6, "resonante" => v_res)
reg = Dict(k => amb .+ P .* lav_modo(lav_fuerza(lav_t, v), lav_fn, lav_ζ, lav_fs) for (k, v) in vel)
for k in ("200 km/h", "resonante")
    x = reg[k]; dd = descriptores_temporales(x)
    @printf("%-9s pico=%.3f rms_fluct=%.4f cresta=%.1f curtosis=%.1f\n", k, dd.pico, dd.rms_fluctuante, dd.cresta_fluctuante, dd.curtosis)
end
x = reg["resonante"]; w(a,b) = x[Int(a*lav_fs)+1:Int(b*lav_fs)]
for (nom, xs) in (("ambiente 5-35", w(5,35)), ("paso 38-52", w(38,52)), ("todo", x))
    dd = descriptores_temporales(xs); f, Pw = psd_welch(xs, lav_fs; nseg=1024)
    i = argmax(Pw[(f .> 2) .& (f .< 8)]); fp = f[(f .> 2) .& (f .< 8)][i]
    @printf("%-14s rms_fl=%.4f cresta=%.1f curt=%.1f  Pmax=%.3e en %.2f Hz  Δf=%.3f\n", nom, dd.rms_fluctuante, dd.cresta_fluctuante, dd.curtosis, maximum(Pw[(f .> 2) .& (f .< 8)]), fp, f[2]-f[1])
end
tr, r = rms_por_ventana(x .- mean(x), lav_fs, 1.0)
@printf("RMS 1s: ambiente med=%.4f  max=%.4f en t=%.1f s\n", median(r), maximum(r), tr[argmax(r)])
# comprobaciones de los ejercicios
@printf("luz media: %s\n", [round(lav_luz(L,n); digits=1) for (_, L, n) in lav_obras])
@printf("v_res=%.1f m/s = %.1f km/h; f_exc(200 km/h)=%.2f; 4º armónico=%.1f Hz; fs mín=%.0f; alias(16 Hz a 25 Hz)=%.1f\n", v_res, v_res*3.6, (200/3.6)/lav_d, 4*v_res/lav_d, 2.5*4*v_res/lav_d, frecuencia_aparente(16, 25))
@printf("bits: q(12)=%.3f mg σe=%.4f; q(11)=%.3f σe=%.4f (rango ±0,5 g)\n", 1/2^12*1000, 1/2^12*1000/sqrt(12), 1/2^11*1000, 1/2^11*1000/sqrt(12))
@printf("Sesia: q24=%.3f µV q16=%.1f µV razón=%.0f = %.1f dB\n", 20/2^24*1e6, 20/2^16*1e6, 2^8, 20log10(2^8))
@printf("Δf para 3 bins en 2ζf: %.3f Hz → T=%.1f s\n", 2*lav_ζ*lav_fn/3, 3/(2*lav_ζ*lav_fn))
