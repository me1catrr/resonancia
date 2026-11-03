"""Enlaces internos de _site/ (ficheros y anclas)."""
import re
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urldefrag, urlparse

import pytest

SITIO = Path(__file__).resolve().parents[2] / "_site"


class Extractor(HTMLParser):
    def __init__(self):
        super().__init__()
        self.enlaces, self.ids = [], set()

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if "id" in a:
            self.ids.add(a["id"])
        if tag == "a" and a.get("href"):
            self.enlaces.append(a["href"])
        if tag in ("img", "script", "link", "source") and (a.get("src") or a.get("href")):
            self.enlaces.append(a.get("src") or a.get("href"))


def analiza(ruta):
    e = Extractor()
    e.feed(ruta.read_text(encoding="utf-8"))
    return e


# Todas las páginas del sitio salvo site_libs.
PAGINAS = [p for p in sorted(SITIO.rglob("*.html"))
           if p.parts[len(SITIO.parts)] not in ("site_libs",)]


@pytest.mark.parametrize("pagina", PAGINAS, ids=lambda p: p.relative_to(SITIO).as_posix())
def test_enlaces_internos(pagina):
    e = analiza(pagina)
    rotos = []
    for h in e.enlaces:
        if h.startswith("#/") or re.match(r"^(https?:|mailto:|data:|javascript:|//)", h):
            continue
        ruta, ancla = urldefrag(h)
        destino = pagina if ruta == "" else (pagina.parent / unquote(urlparse(ruta).path)).resolve()
        if destino.is_dir():
            destino = destino / "index.html"
        if not destino.exists():
            rotos.append(h)
        elif ancla and destino.suffix == ".html" and ancla not in analiza(destino).ids:
            rotos.append(h)
    assert not rotos, f"enlaces rotos: {rotos}"

