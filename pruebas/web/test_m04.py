"""Simulaciones OJS de M4 (procesamiento de señales II), retroalimentación por opción y errores de consola.

Requiere el sitio renderizado (`quarto render mse/m04-senales-ii/index.qmd`) y Chromium; véase test_simulaciones.py.
Ejecutar: uv run pytest pruebas/web/test_m04.py
"""
import functools
import glob
import http.server
import os
import re
import threading
from pathlib import Path

import pytest
from playwright.sync_api import sync_playwright

SITIO = Path(__file__).resolve().parents[2] / "_site"
PAGINA = "mse/m04-senales-ii/index.html"


@pytest.fixture(scope="module")
def navegador():
    manejador = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(SITIO))
    manejador.log_message = lambda *a, **k: None
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), manejador)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    ruta = os.environ.get("PLAYWRIGHT_CHROMIUM") or next(iter(sorted(glob.glob(
        os.path.expanduser("~/Library/Caches/ms-playwright/chromium_headless_shell-*/*/chrome-headless-shell")))[::-1]), None)
    with sync_playwright() as p:
        nav = p.chromium.launch(executable_path=ruta) if ruta else p.chromium.launch()
        yield nav, srv.server_port
        nav.close()
    srv.shutdown()


@pytest.fixture(scope="module")
def pag(navegador):
    nav, puerto = navegador
    p = nav.new_page(viewport={"width": 1280, "height": 900})
    errores = []
    p.on("pageerror", lambda e: errores.append(str(e)))
    p.on("console", lambda m: errores.append(m.text) if m.type == "error" else None)
    p.goto(f"http://127.0.0.1:{puerto}/{PAGINA}", wait_until="networkidle")
    p.wait_for_function("() => document.body.innerText.includes('resolución Δf')", timeout=60000)
    p.errores = errores
    return p


def lectura(pag, fragmento):
    textos = [t.replace("\n", " ") for t in pag.locator(".lectura").all_inner_texts() if fragmento in t]
    assert textos, f"no hay lectura con «{fragmento}»"
    return textos[0]


def elige(pag, etiqueta, valor, n=0):
    """Elige `valor` en el desplegable cuya etiqueta contiene `etiqueta` (el n-ésimo de la página)."""
    sel = pag.locator("label", has_text=etiqueta).nth(n).locator("xpath=..").locator("select").first
    sel.select_option(label=valor)
    pag.wait_for_timeout(500)


def fija(pag, etiqueta, valor, n=0):
    campo = pag.locator("label", has_text=etiqueta).nth(n).locator("xpath=..").locator("input[type=number]").first
    campo.fill(str(valor))
    campo.dispatch_event("input")
    pag.wait_for_timeout(500)


def numero(texto, antes):
    """Primer número (con coma decimal) que sigue a `antes` en `texto`."""
    m = re.search(re.escape(antes) + r"\s*([−+\-]?\d+(?:,\d+)?)", texto)
    assert m, f"no hay número tras «{antes}» en: {texto}"
    return float(m.group(1).replace("−", "-").replace(",", "."))


def test_diez_simulaciones_sin_errores(pag):
    assert pag.locator(".observablehq--error").count() == 0
    assert [e for e in pag.errores if "favicon" not in e] == []
    for fragmento in ("ancho a −3 dB", "sobresale de la fuga", "resolución Δf", "ganancia en f₁", "retardo de grupo a 3,3 Hz",
                      "suelo de ruido (15–45 Hz)", "Error máximo", "SNR global", "En el pico", "resolución en frecuencia Δf"):
        lectura(pag, fragmento)


def test_simulacion1_cifras_de_merito(pag):
    # Hann, N = 64: ancho a −3 dB 1,44 bins y lóbulo lateral −31,5 dB (los de la tabla)
    t = lectura(pag, "ancho a −3 dB")
    assert numero(t, "ancho a −3 dB:") == pytest.approx(1.44, abs=0.01)
    assert numero(t, "lóbulo lateral máx.:") == pytest.approx(-31.5, abs=0.1)
    elige(pag, "ventana", "rectangular", 0)
    t = lectura(pag, "ancho a −3 dB")
    assert numero(t, "ancho a −3 dB:") == pytest.approx(0.89, abs=0.01)
    assert numero(t, "lóbulo lateral máx.:") == pytest.approx(-13.3, abs=0.1)
    elige(pag, "ventana", "flattop", 0)
    t = lectura(pag, "ancho a −3 dB")
    assert numero(t, "ancho a −3 dB:") > 3.5
    assert numero(t, "lóbulo lateral máx.:") < -80
    elige(pag, "ventana", "hann", 0)


def test_simulacion2_tono_debil(pag):
    # δ = 6 bins y débil a −50 dB: no se ve con rectangular ni Hamming; sí con Hann, Blackman y flat-top
    esperado = {"rectangular": False, "hann": True, "hamming": False, "blackman": True, "flattop": True}
    for ventana, ve in esperado.items():
        elige(pag, "ventana", ventana, 1)
        t = lectura(pag, "sobresale de la fuga")
        assert ("→ SE VE" in t) == ve, f"{ventana}: {t}"
    # a δ = 4 la flat-top deja de verlo y Blackman sí
    fija(pag, "separación δ", 4, 0)
    elige(pag, "ventana", "flattop", 1)
    assert "NO SE VE" in lectura(pag, "sobresale de la fuga")
    elige(pag, "ventana", "blackman", 1)
    assert "→ SE VE" in lectura(pag, "sobresale de la fuga")


def test_simulacion3_welch(pag):
    # Hann, L = 256, solape 50 %, N = 8192: K = 63 segmentos y desviación teórica ≈ 12,9 %
    t = lectura(pag, "resolución Δf")
    assert numero(t, "K =") == 63
    teorica = numero(t, "desviación relativa teórica (ecuación de Welch):")
    medida = numero(t, "medida en 20–45 Hz:")
    assert 11 < teorica < 15
    assert 8 < medida < 20            # la medida es una sola realización: del orden de la teórica
    elige(pag, "solape", "0,0 %", 0)
    assert numero(lectura(pag, "resolución Δf"), "K =") == 32          # (8192 − 256)/256 + 1
    elige(pag, "solape", "50,0 %", 0)


def test_retroalimentacion_por_opcion(pag):
    """Un ejercicio de opción de M4 muestra la retroalimentación razonada de la opción elegida."""
    ej = pag.locator("#m4-1-interpretacion-debil")
    ej.locator("input[value=a]").check()
    ej.get_by_role("button", name="Comprobar").click()
    retro = ej.locator(".retro")
    assert retro.is_visible()
    assert retro.locator("li").nth(0).is_visible() and not retro.locator("li").nth(1).is_visible()


def test_vista_de_impresion(pag):
    pag.emulate_media(media="print")
    assert not pag.locator(".laboratorio").first.is_visible()
    assert pag.locator(".solo-impresion").first.is_visible()
    pag.emulate_media(media="screen")


def test_simulacion4_filtros(pag):
    # Butterworth de orden 4, pasabajos, f₁ = 10 Hz: −3,01 dB en el corte; con fase cero, −6,02 dB
    t = lectura(pag, "ganancia en f₁")
    assert "Butterworth orden 4" in t
    assert numero(t, "ganancia en f₁ = 10,0 Hz:") == pytest.approx(-3.01, abs=0.01)
    pag.get_by_label("fase cero (filtrar_fase_cero)").check()
    pag.wait_for_timeout(500)
    assert numero(lectura(pag, "ganancia en f₁"), "ganancia en f₁ = 10,0 Hz:") == pytest.approx(-6.02, abs=0.01)
    pag.get_by_label("fase cero (filtrar_fase_cero)").uncheck()
    # FIR de 101 coeficientes: retardo constante de 500 ms (con 100 Hz de muestreo)
    pag.get_by_label("FIR por ventana (Hamming)").check()
    pag.wait_for_timeout(600)
    t = lectura(pag, "ganancia en f₁")
    assert "FIR (101 coeficientes)" in t and "500 ms" in t
    pag.get_by_label("Butterworth (IIR)").check()
    pag.wait_for_timeout(500)


def test_simulacion5_retardo_de_grupo(pag):
    t = lectura(pag, "retardo de grupo a 3,3 Hz")
    assert numero(t, "retardo de grupo a 3,3 Hz de") > 50          # ms: el filtro causal retrasa
    assert "retardo 0 ms" in t                                      # y el de fase cero, no


def test_simulacion6_defectos(pag):
    # con el pico espurio de 8 por defecto, el suelo sube ≈ 4,3 dB; sin él, 0
    t = lectura(pag, "suelo de ruido (15–45 Hz)")
    assert numero(t, "suelo de ruido (15–45 Hz)") == pytest.approx(4.3, abs=0.3)
    fija(pag, "pico espurio", 0)
    assert abs(numero(lectura(pag, "suelo de ruido (15–45 Hz)"), "suelo de ruido (15–45 Hz)")) < 0.2
    fija(pag, "pico espurio", 8)


def test_simulacion7_integracion(pag):
    # por defecto (offset 0,002, lenta 0,002, corte 0,5): C da un error de décimas de micra a unas micras
    t = lectura(pag, "Error máximo")
    assert numero(t, "en frecuencia, corte 0,50 Hz) ") < 0.1
    assert numero(t, "sin preprocesar; puede salirse del eje) ") > 100
    fija(pag, "frecuencia de corte de C", 2.5)
    assert numero(lectura(pag, "Error máximo"), "en frecuencia, corte 2,50 Hz) ") == pytest.approx(0.32, abs=0.02)
    fija(pag, "frecuencia de corte de C", 0.5)


def test_simulacion8_snr(pag):
    t = lectura(pag, "SNR global")
    assert numero(t, "SNR global (tiempo):") == pytest.approx(14.2, abs=0.2)
    assert numero(t, "(naranja):") == pytest.approx(25.2, abs=0.3)


def test_simulacion9_frf(pag):
    # con ruido solo en la entrada (0,5), H1 queda por debajo y H2 coincide con la verdadera
    t = lectura(pag, "En el pico")
    assert numero(t, "H₂/H =") == pytest.approx(1.0, abs=0.08)
    assert numero(t, "H₁/H =") < 0.9
    # sesgo de resolución: ζ = 1 %, segmentos de 256, sin ruido → coherencia baja
    fija(pag, "amortiguamiento", 0.01)
    elige(pag, "longitud del segmento", "256", 1)
    fija(pag, "ruido en la entrada", 0)
    assert numero(lectura(pag, "En el pico"), "γ² =") < 0.4
    elige(pag, "longitud del segmento", "4096", 1)
    assert numero(lectura(pag, "En el pico"), "γ² =") > 0.8


def test_simulacion10_espectrograma(pag):
    t = lectura(pag, "resolución en frecuencia Δf")
    assert numero(t, "Δf =") == pytest.approx(0.391, abs=0.001)
    assert numero(t, "Δt ≈") == pytest.approx(2.56, abs=0.01)
