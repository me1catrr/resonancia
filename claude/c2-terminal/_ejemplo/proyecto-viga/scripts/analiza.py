"""Análisis básico de un registro de aceleración (CSV con columnas t_s y aceleracion_m_s2).

Uso: python scripts/analiza.py datos/aceleracion.csv resultados
Códigos de salida: 0 correcto, 2 fichero de entrada ausente, 3 datos no válidos.
"""
import csv
import sys
from pathlib import Path

import numpy as np


def leer_csv(ruta):
    """Devuelve (t, a) como arreglos de numpy; lanza ValueError si faltan columnas o hay filas vacías."""
    with open(ruta, newline="", encoding="utf-8") as f:
        lector = csv.DictReader(f)
        if lector.fieldnames is None or not {"t_s", "aceleracion_m_s2"} <= set(lector.fieldnames):
            raise ValueError("faltan las columnas t_s y aceleracion_m_s2")
        filas = [(float(r["t_s"]), float(r["aceleracion_m_s2"])) for r in lector]
    if len(filas) < 8:
        raise ValueError("registro demasiado corto")
    t, a = np.array(filas).T
    return t, a


def frecuencia_muestreo(t):
    """fs en Hz a partir del paso medio del tiempo."""
    return 1.0 / float(np.mean(np.diff(t)))


def rms(a):
    """Valor eficaz (m/s²) de la señal sin su media."""
    a = np.asarray(a, dtype=float)
    return float(np.sqrt(np.mean((a - a.mean()) ** 2)))


def frecuencia_dominante(a, fs):
    """Frecuencia (Hz) del máximo del espectro de amplitud, sin contar la componente continua."""
    a = np.asarray(a, dtype=float)
    espectro = np.abs(np.fft.rfft(a - a.mean()))
    frecuencias = np.fft.rfftfreq(len(a), d=1.0 / fs)
    return float(frecuencias[np.argmax(espectro[1:]) + 1])


def escribe_informe(resumen, ruta):
    """Escribe un informe en Markdown (con cabecera YAML) a partir del resumen numérico."""
    filas = "\n".join(f"| {k} | {v} |" for k, v in resumen.items())
    ruta.write_text(
        "---\ntitle: \"Resumen del registro de aceleración\"\nlang: es\n---\n\n"
        "Datos **sintéticos** (ficha en `datos/aceleracion.meta.toml`).\n\n"
        "| Magnitud | Valor |\n|---|---|\n" + filas + "\n\n"
        f"La frecuencia dominante, {resumen['f_dominante_Hz']} Hz, es la del máximo del espectro de amplitud; "
        "la separación entre bins es fs/N, no la resolución efectiva (véase C0).\n",
        encoding="utf-8",
    )


def main(argv):
    if len(argv) != 3:
        print(__doc__, file=sys.stderr)
        return 1
    entrada, salida = Path(argv[1]), Path(argv[2])
    if not entrada.exists():
        print(f"ERROR: no existe {entrada}", file=sys.stderr)
        return 2
    try:
        t, a = leer_csv(entrada)
    except (ValueError, KeyError) as e:
        print(f"ERROR: datos no válidos: {e}", file=sys.stderr)
        return 3
    fs = frecuencia_muestreo(t)
    salida.mkdir(parents=True, exist_ok=True)
    resumen = {
        "muestras": len(a),
        "fs_Hz": round(fs, 3),
        "media_m_s2": round(float(a.mean()), 5),
        "desv_m_s2": round(float(a.std(ddof=1)), 5),
        "rms_m_s2": round(rms(a), 5),
        "f_dominante_Hz": round(frecuencia_dominante(a, fs), 3),
    }
    with open(salida / "resumen.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(resumen.keys())
        w.writerow(resumen.values())
    escribe_informe(resumen, salida / "informe.md")
    print(f"Escrito {salida / 'resumen.csv'} e informe.md")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
