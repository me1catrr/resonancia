"""Laboratorios OJS de M2.5, M2.8, M2.9 y M2.10 (Fourier, Hilbert, estocásticos y correlación)."""
import re

from test_m02_fase2 import abre, fija, navegador, salidas, sin_errores  # noqa: F401


def test_fourier_fuga_y_ventanas(navegador):
    pag = abre(navegador, "fourier", "Pico:")
    sin_errores(pag)
    t = salidas(pag, "Pico:")[0]
    amp = float(re.search(r"amplitud estimada ([0-9,]+)", t).group(1).replace(",", "."))
    assert 0.6 < amp < 0.7                                  # 12,5 bins con ventana rectangular: pérdida por escalonamiento
    fija(pag, "frecuencia (bins)", 12)
    t = salidas(pag, "Pico:")[0]
    assert float(re.search(r"amplitud estimada ([0-9,]+)", t).group(1).replace(",", ".")) > 0.999
    pag.get_by_label("ventana", exact=True).select_option("flattop")
    fija(pag, "frecuencia (bins)", 12.5)
    t = salidas(pag, "Pico:")[0]
    assert float(re.search(r"amplitud estimada ([0-9,]+)", t).group(1).replace(",", ".")) > 0.99


def test_hilbert_banda_estrecha(navegador):
    pag = abre(navegador, "hilbert", "")
    sin_errores(pag)
    assert pag.locator("svg").count() > 3
    fija(pag, "amplitud de la 2", 0.6)                      # la segunda componente: sigue sin errores
    sin_errores(pag)


def test_estocasticos_avisos(navegador):
    pag = abre(navegador, "estocasticos", "Media de conjunto")
    sin_errores(pag)
    assert "compatible con estacionario" in salidas(pag, "Media de conjunto")[0]
    pag.get_by_label("proceso", exact=True).select_option(index=1)
    pag.wait_for_timeout(600)
    assert "no es estacionario" in salidas(pag, "Media de conjunto")[0]


def test_correlacion_retardo(navegador):
    pag = abre(navegador, "correlacion", "Retardo estimado")
    sin_errores(pag)
    assert "✓ Coincide" in salidas(pag, "Retardo estimado")[0]
    fija(pag, "retardo real d", -7)
    assert "estimado:** -7" in salidas(pag, "Retardo estimado")[0] or "-7 muestras" in salidas(pag, "Retardo estimado")[0]
