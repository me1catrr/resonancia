import sys
from pathlib import Path

import numpy as np
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import analiza  # noqa: E402

RAIZ = Path(__file__).resolve().parents[1]


def test_frecuencia_dominante_de_un_seno():
    fs = 200.0
    t = np.arange(2000) / fs
    assert analiza.frecuencia_dominante(2.0 * np.sin(2 * np.pi * 10.0 * t) + 5.0, fs) == pytest.approx(10.0, abs=0.1)


def test_rms_de_un_seno_es_amplitud_sobre_raiz_de_dos():
    t = np.arange(2000) / 200.0
    assert analiza.rms(3.0 * np.sin(2 * np.pi * 10.0 * t)) == pytest.approx(3.0 / np.sqrt(2), rel=1e-3)


def test_datos_sinteticos_tienen_el_modo_de_12_5_hz(tmp_path):
    assert analiza.main(["analiza", str(RAIZ / "datos" / "aceleracion.csv"), str(tmp_path)]) == 0
    cabecera, fila = (tmp_path / "resumen.csv").read_text().splitlines()[:2]
    valores = dict(zip(cabecera.split(","), fila.split(",")))
    assert float(valores["f_dominante_Hz"]) == pytest.approx(12.5, abs=0.1)
    assert int(valores["muestras"]) == 2048


def test_fichero_ausente_devuelve_2(tmp_path):
    assert analiza.main(["analiza", str(tmp_path / "no_existe.csv"), str(tmp_path)]) == 2


def test_columnas_incorrectas_devuelven_3(tmp_path):
    malo = tmp_path / "malo.csv"
    malo.write_text("x,y\n1,2\n")
    assert analiza.main(["analiza", str(malo), str(tmp_path)]) == 3


def test_informe_markdown_contiene_la_frecuencia(tmp_path):
    analiza.main(["analiza", str(RAIZ / "datos" / "aceleracion.csv"), str(tmp_path)])
    texto = (tmp_path / "informe.md").read_text()
    assert texto.startswith("---") and "| f_dominante_Hz | 12.5 |" in texto
