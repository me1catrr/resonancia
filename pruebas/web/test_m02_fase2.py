"""Laboratorios OJS de M2.2–M2.6 (valores propios, SVD, Laplace y espacio de estados).

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
BASE = "mse/m02-matematicas/"


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


def abre(navegador, pagina, esperar):
    nav, puerto = navegador
    pag = nav.new_page(viewport={"width": 1280, "height": 900})
    errores = []
    pag.on("pageerror", lambda e: errores.append(str(e)))
    pag.on("console", lambda m: errores.append(m.text) if m.type == "error" else None)
    pag.goto(f"http://127.0.0.1:{puerto}/{BASE}{pagina}/index.html", wait_until="networkidle")
    pag.wait_for_function(
        "(t) => Array.from(document.querySelectorAll('.observablehq')).some(e => e.innerText.includes(t))", arg=esperar, timeout=30000)
    pag.errores = errores
    return pag


def salidas(pag, fragmento):
    return [t.replace("\n", " ") for t in pag.locator(".observablehq").all_inner_texts() if fragmento in t]


def fija(pag, etiqueta, valor):
    campo = pag.locator("form", has=pag.locator("label", has_text=etiqueta)).locator("input[type=number]").first
    campo.fill(str(valor))
    campo.dispatch_event("input")
    pag.wait_for_timeout(500)


def sin_errores(pag):
    assert pag.locator(".observablehq--error").count() == 0
    assert [e for e in pag.errores if "favicon" not in e] == []


def test_valores_propios_prediccion_lineal_y_mac(navegador):
    pag = abre(navegador, "valores-propios", "f referencia (Hz)")
    sin_errores(pag)
    t = salidas(pag, "f referencia (Hz)")[0]
    # Δk₂ = −10 %: −1,85 % exacto y −1,70 % lineal en el primer modo; MAC ≥ 0,999
    assert "1,105" in t and "-1,85 %" in t and "-1,70 %" in t
    assert all(float(v.replace(",", ".")) > 0.999 for v in re.findall(r"0,99\d\d", t))
    fija(pag, "Δk₂", 0)
    t = salidas(pag, "f referencia (Hz)")[0]
    assert t.count("0,00 %") >= 3 and t.count("1,0000") == 3     # sin cambio: frecuencias iguales y MAC = 1


def test_svd_eckart_young_y_ruido(navegador):
    pag = abre(navegador, "svd", "Energía retenida")
    sin_errores(pag)
    t = salidas(pag, "Energía retenida")[0]
    assert "✓" in t                                         # el error en norma 2 coincide con σ_{r+1}
    for r in (0, 1, 5, 12):
        fija(pag, "rango r", r)
        t = salidas(pag, "Energía retenida")[0]
        assert "✓" in t or r == 12                          # con r = 12 no queda cola
    fija(pag, "rango r", 3)
    fija(pag, "ruido s", 0.3)
    t = salidas(pag, "Energía retenida")[0]
    limpia = float(re.search(r"sin ruido: ([0-9,]+)", t).group(1).replace(",", "."))
    ruidosa = float(re.search(r"ruidosa: ([0-9,]+)", t).group(1).replace(",", "."))
    assert limpia < ruidosa                                 # truncar al rango de la señal filtra el ruido


def test_laplace_frf_antirresonancia_puntual(navegador):
    pag = abre(navegador, "laplace", "")
    sin_errores(pag)
    assert pag.locator("svg").count() > 3


def test_espacio_estados_observabilidad(navegador):
    pag = abre(navegador, "espacio-estados", "Rango de la matriz de observabilidad")
    sin_errores(pag)
    rango = lambda: int(re.search(r"observabilidad: (\d)", salidas(pag, "Rango de la matriz")[0]).group(1))
    assert rango() == 4                                     # cadena simétrica con sensor central
    pag.get_by_label("masa 1").check()
    pag.wait_for_timeout(500)
    assert rango() == 6                                     # un segundo sensor devuelve la observabilidad
    pag.get_by_label("masa 1").uncheck()
    pag.get_by_label("masa 2").uncheck()
    pag.get_by_label("masa 3").check()
    pag.wait_for_timeout(500)
    assert rango() == 6                                     # sensor en el extremo
    pag.get_by_label("Edificio de cortante (3 plantas)").check()
    pag.get_by_label("masa 2").check()
    pag.get_by_label("masa 3").uncheck()
    pag.wait_for_timeout(500)
    assert rango() == 6                                     # edificio: cualquier planta basta
    pag.get_by_label("aceleración", exact=True).check()
    pag.wait_for_timeout(500)
    assert rango() == 6
