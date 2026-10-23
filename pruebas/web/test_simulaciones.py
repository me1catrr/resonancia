"""Interacción de las simulaciones OJS de C0 (cambian al mover los controles)."""
import functools
import glob
import http.server
import os
import threading
from pathlib import Path

import pytest
from playwright.sync_api import sync_playwright

SITIO = Path(__file__).resolve().parents[2] / "_site"


@pytest.fixture(scope="module")
def pagina():
    manejador = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(SITIO))
    manejador.log_message = lambda *a, **k: None
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), manejador)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    ruta = os.environ.get("PLAYWRIGHT_CHROMIUM") or next(iter(sorted(glob.glob(
        os.path.expanduser("~/Library/Caches/ms-playwright/chromium_headless_shell-*/*/chrome-headless-shell")))[::-1]), None)
    with sync_playwright() as p:
        nav = p.chromium.launch(executable_path=ruta) if ruta else p.chromium.launch()
        pag = nav.new_page(viewport={"width": 1280, "height": 900})
        pag.goto(f"http://127.0.0.1:{srv.server_port}/claude/c0-fluidez/index.html", wait_until="networkidle")
        pag.wait_for_selector("svg text", timeout=20000)
        yield pag
        nav.close()
    srv.shutdown()


def fija(pag, etiqueta, valor):
    campo = pag.locator("form", has=pag.locator("label", has_text=etiqueta)).locator("input[type=number]").first
    campo.fill(str(valor))
    campo.dispatch_event("input")
    pag.wait_for_timeout(400)


def test_neurona_cambia_la_ecuacion(pagina):
    fija(pagina, "peso w", 2.5)
    assert "2.5·x" in pagina.locator("svg text", has_text="sigmoide").first.text_content()


def test_softmax_suma_100_y_cambia_con_t(pagina):
    def porcentajes():
        t = pagina.locator("svg text", has_text="%").all_text_contents()
        return [float(x.replace("%", "").replace(",", ".")) for x in t if "%" in x]
    fija(pagina, "temperatura T", 1)
    p1 = porcentajes()
    assert abs(sum(p1) - 100) < 0.5
    fija(pagina, "temperatura T", 0.1)
    p2 = porcentajes()
    assert abs(sum(p2) - 100) < 0.5 and max(p2) > max(p1)
