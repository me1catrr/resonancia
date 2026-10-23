# Traducción a Julia de la función MATLAB `mediamovil` (véase C5.7).
using Statistics

function mediamovil(x, n)
    N = length(x)
    y = zeros(N - n + 1)
    for i in 1:N-n+1
        y[i] = mean(x[i:i+n-1])
    end
    return y
end
