"""Pruebas de figuras.py frente a los valores de Julia (página J2.4).

Ejecutar desde la raíz: ``uv run pytest julia/j2-datos/j2-4-makie/python``
"""
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

import figuras as fg

RAIZ = Path(__file__).resolve().parents[4]
BASE = RAIZ / "datos" / "sinteticos" / "edificio-3-plantas"


def test_contraste_blanco_negro():
    assert fg.contraste("#000000", "#FFFFFF") == pytest.approx(21.0)
    assert fg.contraste("#FFFFFF", "#FFFFFF") == pytest.approx(1.0)


def test_contraste_paleta_del_curso():
    # El azul oscuro del curso supera con holgura el 3:1 exigido a los gráficos
    assert fg.contraste("#1B6CA8") > 3.0
    assert fg.contraste("#1F2937") > 12.0


@pytest.mark.parametrize("esc, media, desv", [("A", 4.4189, 0.0345), ("B", 4.375, 0.0341), ("C", 4.2725, 0.0415)])
def test_picos_por_segmento_frente_a_julia(esc, media, desv):
    a = pd.read_csv(BASE / f"escenario_{esc}.csv", sep=";")
    f3 = fg.picos_por_segmento(a["a3_ms2"].to_numpy(), 100.0)
    assert len(f3) == 10
    assert f3.mean() == pytest.approx(media, abs=5e-4)
    assert f3.std(ddof=1) == pytest.approx(desv, abs=5e-4)


def test_figura_columna(tmp_path):
    fig = fg.figura_columna([np.array([1.0, 2.0, 3.0]), np.array([2.0, 3.0, 4.0])], ["A", "B"])
    assert fig.get_size_inches() == pytest.approx([3.5, 190 / 72])
    destino = tmp_path / "f.pdf"
    fig.savefig(destino)
    assert destino.stat().st_size > 500
