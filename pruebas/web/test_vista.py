"""Pruebas visuales de la vía C sobre _site/ (render previo: quarto render).

Cinco anchuras; sin desbordamiento horizontal ni recursos rotos. Las capturas
van a _capturas/ (ignorado por Git).
"""
import functools
import glob
import os
import http.server
import threading
from pathlib import Path

import pytest
from playwright.sync_api import sync_playwright

RAIZ = Path(__file__).resolve().parents[2]
SITIO = RAIZ / "_site"
ANCHURAS = [390, 768, 1280, 1920, 2560]
PAGINAS = ["claude/index.html"] + [
    p.relative_to(SITIO).as_posix() for p in sorted((SITIO / "claude").glob("c*/index.html"))
]


@pytest.fixture(scope="session")
def servidor():
    manejador = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(SITIO))
    manejador.log_message = lambda *a, **k: None
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), manejador)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    yield f"http://127.0.0.1:{srv.server_port}"
    srv.shutdown()


@pytest.fixture(scope="session")
def navegador():
    with sync_playwright() as p:
        # PLAYWRIGHT_CHROMIUM: ruta a un Chromium ya descargado si la versión de
        # Playwright no coincide con la de la caché; si no, el predeterminado.
        ruta = os.environ.get("PLAYWRIGHT_CHROMIUM") or next(iter(sorted(glob.glob(
            os.path.expanduser("~/Library/Caches/ms-playwright/chromium_headless_shell-*/*/chrome-headless-shell")))[::-1]), None)
        nav = p.chromium.launch(executable_path=ruta) if ruta else p.chromium.launch()
        yield nav
        nav.close()


@pytest.mark.parametrize("ancho", ANCHURAS)
@pytest.mark.parametrize("pagina", PAGINAS)
def test_sin_desbordamiento_ni_recursos_rotos(servidor, navegador, pagina, ancho):
    ctx = navegador.new_context(viewport={"width": ancho, "height": 900})
    pag = ctx.new_page()
    rotos = []
    pag.on("response", lambda r: rotos.append(r.url) if r.status >= 400 and "fonts" not in r.url else None)
    errores = []
    pag.on("pageerror", lambda e: errores.append(str(e)))
    pag.goto(f"{servidor}/{pagina}", wait_until="networkidle")
    if errores:
        # El servidor de pruebas (http.server) a veces sirve incompleto algún script de
        # las bibliotecas de Quarto; un error que persiste tras recargar sí es real.
        errores.clear()
        rotos.clear()
        pag.reload(wait_until="networkidle")
    pag.wait_for_function("[...document.images].every(i => i.complete)", timeout=15000)
    sin_imagen = pag.evaluate("[...document.images].filter(i => i.naturalWidth === 0).map(i => i.getAttribute('src'))")
    refs_toc = pag.evaluate("[...document.querySelectorAll('#TOC a')].filter(a => a.offsetParent !== null && a.textContent.trim() === 'Referencias').length")
    sobra = pag.evaluate("document.documentElement.scrollWidth - document.documentElement.clientWidth")
    (RAIZ / "_capturas").mkdir(exist_ok=True)
    pag.screenshot(path=str(RAIZ / "_capturas" / f"{pagina.replace('/', '_')}-{ancho}.png"))
    ctx.close()
    assert sobra <= 1, f"desbordamiento horizontal de {sobra}px"
    assert not rotos, f"recursos rotos: {rotos}"
    assert refs_toc <= 1, "«Referencias» repetida en el índice visible"
    assert not sin_imagen, f"imágenes que no se decodifican: {sin_imagen}"
    assert not errores, f"errores JS: {errores}"
