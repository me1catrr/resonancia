"""Simulaciones OJS de M3 (procesamiento de señales I), retroalimentación por opción y vista de impresión.

Requiere el sitio renderizado (`quarto render`) y Chromium; véase test_simulaciones.py.
Ejecutar: uv run pytest pruebas/web/test_m03.py
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
PAGINA = "mse/m03-senales-i/index.html"


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
    # la última simulación (Torroja, con el CSV) es la más lenta en aparecer
    p.wait_for_function("() => document.body.innerText.includes('Peso del canal más fuerte')", timeout=60000)
    p.errores = errores
    return p


def lectura(pag, fragmento):
    textos = [t.replace("\n", " ") for t in pag.locator(".lectura").all_inner_texts() if fragmento in t]
    assert textos, f"no hay lectura con «{fragmento}»"
    return textos[0]


def fija(pag, etiqueta, valor):
    campo = pag.locator("label", has_text=etiqueta).first.locator("xpath=..").locator("input[type=number]").first
    campo.fill(str(valor))
    campo.dispatch_event("input")
    pag.wait_for_timeout(600)


def test_once_simulaciones_sin_errores(pag):
    assert pag.locator(".observablehq--error").count() == 0
    assert [e for e in pag.errores if "favicon" not in e] == []
    for fragmento in ("energía Σx²Δt", "Pendiente ajustada", "de los instantes más extremos", "Ventanas de", "Curtosis ordinaria", "niveles disponibles", "Nyquist", "Ciclos en el registro",
                      "T·δ", "Segmentos K", "RMS en 1–12 Hz", "Peso del canal más fuerte"):
        lectura(pag, fragmento)


def test_fuga_y_numero_entero_de_ciclos(pag):
    t = lectura(pag, "Ciclos en el registro")
    assert "f₀·T = 5,000" in t and "pico: 1,000 m/s²" in t and "0,0 %" in t
    fija(pag, "frecuencia del coseno", 2.75)
    t = lectura(pag, "Ciclos en el registro")
    assert "pico: 1,000" not in t


def test_alias_y_reinicio(pag):
    fija(pag, "frecuencia real f₀", 117)
    assert "Frecuencia aparente: 17,0 Hz" in lectura(pag, "Nyquist")
    lab = pag.locator(".laboratorio", has=pag.locator("label", has_text="frecuencia real f₀"))
    lab.get_by_role("button", name="Restablecer valores").click()
    pag.wait_for_timeout(600)
    assert "Frecuencia aparente: 30,0 Hz" in lectura(pag, "Nyquist")


def test_dos_tonos_dependen_de_la_duracion(pag):
    assert "valle de al menos 3 dB? no" in lectura(pag, "T·δ")
    fija(pag, "duración T", 20)
    assert "valle de al menos 3 dB? sí" in lectura(pag, "T·δ")


def test_welch_parseval_exacto_en_segmentos(pag):
    t = lectura(pag, "Segmentos K")
    assert "Segmentos K = 22" in t                  # 240 s a 50 Hz con L = 1024 y solape del 50 %
    assert "diferencia 0,000000 %" in t             # exacto frente a los segmentos ponderados


def test_retroalimentacion_por_opcion(pag):
    ej = pag.locator("#m3-diag-rms")
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


def test_colores_del_ruido_y_galeria(pag):
    assert "determinista" in lectura(pag, "energía Σx²Δt")
    pag.locator("label", has_text="tipo de ruido").first.locator("xpath=..").locator("select").select_option("rosa (1/f)")
    pag.wait_for_timeout(800)
    pendiente = float(re.search(r"red\): (-?[\d,]+)", lectura(pag, "Pendiente ajustada")).group(1).replace(",", "."))
    assert -1.3 < pendiente < -0.8                 # ruido rosa: −1 (−10 dB/década)
