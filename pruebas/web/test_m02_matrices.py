"""Laboratorios OJS de M2.1 (matrices estructuradas): se calculan sin errores y responden a los controles.

Requiere el sitio renderizado (`quarto render`) y Chromium; véase test_simulaciones.py.
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
RUTA = "mse/m02-matematicas/matrices/index.html"


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
        errores = []
        pag.on("pageerror", lambda e: errores.append(str(e)))
        pag.on("console", lambda m: errores.append(m.text) if m.type == "error" else None)
        pag.goto(f"http://127.0.0.1:{srv.server_port}/{RUTA}", wait_until="networkidle")
        pag.wait_for_function(
            "() => Array.from(document.querySelectorAll('.observablehq')).some(e => e.innerText.includes('κ₂(A) ='))", timeout=30000)
        pag.errores = errores
        yield pag
        nav.close()
    srv.shutdown()


def fija(pag, etiqueta, valor):
    campo = pag.locator("form", has=pag.locator("label", has_text=etiqueta)).locator("input[type=number]").first
    campo.fill(str(valor))
    campo.dispatch_event("input")
    pag.wait_for_timeout(500)


def salidas(pag, fragmento):
    return [t for t in pag.locator(".observablehq").all_inner_texts() if fragmento in t]


def numero(texto, patron):
    return float(re.search(patron, texto).group(1))


def test_sin_errores_de_consola_ni_celdas_rotas(pagina):
    assert pagina.locator(".observablehq--error").count() == 0
    assert [e for e in pagina.errores if "favicon" not in e] == []


def test_condicionamiento_cumple_la_cota_y_crece_al_bajar_epsilon(pagina):
    fija(pagina, "ε (adimensional)", 0.1)
    fija(pagina, "δ (perturbación", 0.05)
    t = salidas(pagina, "κ₂(A) =")[0]
    k1 = numero(t, r"κ₂\(A\) = ([0-9]+(?:\.[0-9]+)?)")
    assert abs(k1 - 42.1) < 0.2 and "✓" in t
    fija(pagina, "ε (adimensional)", 0.01)
    t = salidas(pagina, "κ₂(A) =")[0]
    assert numero(t, r"κ₂\(A\) = ([0-9]+(?:\.[0-9]+)?)") > 5 * k1 and "✓" in t


def test_toeplitz_el_ruido_de_medida_sesga_yule_walker(pagina):
    def phi1():
        t = salidas(pagina, "Estimados con Yule–Walker")[0]
        return numero(t, r"φ̂ = \(([0-9.-]+),")
    fija(pagina, "ruido de medida", 0)
    sin_ruido = phi1()
    fija(pagina, "ruido de medida", 1.5)
    con_ruido = phi1()
    teorico = numero(salidas(pagina, "Coeficientes teóricos")[0], r"φ = \(([0-9.-]+),")
    assert abs(sin_ruido - teorico) < 0.1          # sin ruido, Yule–Walker recupera el coeficiente
    assert abs(con_ruido - teorico) > abs(sin_ruido - teorico) + 0.2   # con ruido de medida, queda sesgado


def test_ssa_reconstruye_mejor_que_la_senal_ruidosa(pagina):
    fija(pagina, "ruido σ", 0.2)
    t = salidas(pagina, "Error RMS de la reconstrucción")[0]
    err = numero(t, r"limpia: ([0-9.]+)")
    err_ruido = numero(t, r"sin tratar: ([0-9.]+)")
    assert err < 0.5 * err_ruido


def test_convolucion_circular_difiere_de_la_lineal_salvo_con_relleno(pagina):
    t = salidas(pagina, "Diferencia máxima entre la circular directa")[0]
    assert "no coinciden" in t                      # señal al final del registro y sin relleno: se envuelve
    pagina.locator("form", has=pagina.locator("label", has_text="relleno de ceros")).locator("input[type=checkbox]").check()
    pagina.wait_for_timeout(500)
    t = salidas(pagina, "Diferencia máxima entre la circular directa")[0]
    assert "coinciden (basta el relleno" in t
