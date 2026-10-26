"""Pruebas de proyecto.py frente a los valores de Julia (página J2.1).

Ejecutar desde la raíz: ``uv run pytest julia/j2-datos/j2-1-proyectos/python``
"""
from pathlib import Path

import pytest

import proyecto as pr

RAIZ = Path(__file__).resolve().parents[4]
CSV = RAIZ / "datos" / "sinteticos" / "curso-claude" / "d_ambiental.csv"


def test_resumen_diario_frente_a_julia():
    r = pr.resumen_diario(CSV)
    assert len(r) == 14
    assert list(r["n_validas"][:6]) == [144, 144, 144, 144, 131, 144]
    assert r["media_C"][0] == pytest.approx(21.9923, abs=5e-5)
    assert r["max_C"][4] == pytest.approx(27.45, abs=5e-3)
    assert int(r["n_validas"].sum()) == 2016 - 13


def test_huella_conocida(tmp_path):
    f = tmp_path / "a.txt"
    f.write_bytes(b"abc")
    assert pr.huella(f) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"


def test_huella_es_determinista(tmp_path):
    a, b = tmp_path / "a.csv", tmp_path / "b.csv"
    a.write_text("x,y\n1,2\n")
    b.write_text("x,y\n1,2\n")
    assert pr.huella(a) == pr.huella(b)
    b.write_text("x,y\n1,3\n")
    assert pr.huella(a) != pr.huella(b)
