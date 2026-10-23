"""Comprobaciones de accesibilidad básicas sobre el HTML generado de la vía C."""
import re
from collections import Counter
from html.parser import HTMLParser
from pathlib import Path

import pytest

SITIO = Path(__file__).resolve().parents[2] / "_site"
PAGINAS = sorted((SITIO / "claude").glob("c*/index.html")) + [SITIO / "claude" / "index.html"]


class Sonda(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids, self.imgs_sin_alt, self.niveles, self.toc = [], [], [], []
        self._en_toc = self._en_a = False
        self._texto = ""

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if "id" in a:
            self.ids.append(a["id"])
        if tag == "img" and "alt" not in a:
            self.imgs_sin_alt.append(a.get("src"))
        if re.fullmatch(r"h[1-6]", tag):
            self.niveles.append(int(tag[1]))
        if tag == "nav" and a.get("id") == "TOC":
            self._en_toc = True
        if self._en_toc and tag == "a":
            self._en_a, self._texto = True, ""

    def handle_endtag(self, tag):
        if tag == "a" and self._en_a:
            self.toc.append(self._texto.strip())
            self._en_a = False
        if tag == "nav":
            self._en_toc = False

    def handle_data(self, d):
        if self._en_a:
            self._texto += d


@pytest.mark.parametrize("ruta", PAGINAS, ids=lambda p: p.parent.name)
def test_html_accesible(ruta):
    s = Sonda()
    s.feed(ruta.read_text(encoding="utf-8"))
    repetidos = [i for i, n in Counter(s.ids).items() if n > 1 and not i.startswith("toc-")]
    assert not repetidos, f"ids repetidos: {repetidos}"
    assert not s.imgs_sin_alt, f"imágenes sin atributo alt: {s.imgs_sin_alt}"
    assert s.niveles.count(1) <= 2, "más de un h1 de contenido"
