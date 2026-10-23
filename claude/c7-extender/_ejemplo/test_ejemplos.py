"""Pruebas de los ejemplos de C7 (skill validar-tabla). Los hooks se prueban con hooks/probar_hooks.sh."""
import subprocess
import sys
from pathlib import Path

import pytest

AQUI = Path(__file__).resolve().parent
sys.path.insert(0, str(AQUI / "skill" / "validar-tabla" / "scripts"))
import validar  # noqa: E402
sys.path.insert(0, str(AQUI / "skill" / "validar-tabla" / "scripts"))


DATOS = AQUI.parents[2] / "datos" / "sinteticos" / "curso-claude"


def test_validar_ventas():
    r = validar.validar(DATOS / "a_ventas.csv")
    assert r["filas"] == 109 and r["duplicadas"] == 1 and r["ausentes"]["ventas_eur"] == 5


def test_validar_ambiental_tiene_13_ausentes():
    assert validar.validar(DATOS / "d_ambiental.csv")["ausentes"]["temperatura_C"] == 13


def test_codigos_de_salida(tmp_path):
    script = AQUI / "skill" / "validar-tabla" / "scripts" / "validar.py"
    assert subprocess.run([sys.executable, str(script), str(tmp_path / "no.csv")], capture_output=True).returncode == 2
    malo = tmp_path / "malo.csv"
    malo.write_text("a,b\n1\n")
    assert subprocess.run([sys.executable, str(script), str(malo)], capture_output=True).returncode == 3
    vacio = tmp_path / "vacio.csv"
    vacio.write_text("")
    assert subprocess.run([sys.executable, str(script), str(vacio)], capture_output=True).returncode == 3


def test_solo_lee(tmp_path):
    f = tmp_path / "x.csv"
    f.write_text("a,b\n1,2\n")
    antes = f.read_bytes()
    validar.validar(f)
    assert f.read_bytes() == antes


def test_skill_tiene_frontmatter_valido():
    texto = (AQUI / "skill" / "validar-tabla" / "SKILL.md").read_text()
    assert texto.startswith("---\n")
    cabecera = texto.split("---")[1]
    assert "name: validar-tabla" in cabecera and "description:" in cabecera


def test_informe_quarto_y_xlsx(tmp_path):
    import json
    import openpyxl
    import informe
    libro = openpyxl.Workbook()
    ws = libro.active
    ws.append(["mes", "indicador"])
    ws.append(["ene", 1.5])
    ws.append(["feb", None])
    ws.append(["ene", 1.5])
    libro.save(tmp_path / "i.xlsx")
    v = validar.validar(tmp_path / "i.xlsx")
    assert v["filas"] == 3 and v["ausentes"]["indicador"] == 1 and v["duplicadas"] == 1
    qmd = informe.construir(v)
    assert qmd.startswith("---") and "| indicador | 1 |" in qmd and "Validación de i.xlsx" in qmd
