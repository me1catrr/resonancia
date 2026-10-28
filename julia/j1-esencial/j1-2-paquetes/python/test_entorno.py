"""Pruebas de entorno.py sobre el pyproject.toml y el uv.lock del repositorio.

Ejecutar desde la raíz: ``uv run pytest julia/j1-esencial/j1-2-paquetes/python``
"""
from pathlib import Path

import entorno as en

RAIZ = Path(__file__).resolve().parents[4]


def test_dependencias_declaradas():
    deps = en.dependencias(RAIZ / "pyproject.toml")
    assert deps == sorted(deps)
    assert {"scipy", "pandas", "matplotlib", "openpyxl"} <= set(deps)


def test_cada_dependencia_tiene_version_fijada():
    fijadas = en.versiones_fijadas(RAIZ / "uv.lock")
    for nombre in en.dependencias(RAIZ / "pyproject.toml"):
        assert nombre in fijadas
        assert fijadas[nombre][0].isdigit()


def test_nombres_con_especificador():
    # el especificador de versión no forma parte del nombre
    import tempfile

    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "pyproject.toml"
        p.write_text('[project]\nname="x"\ndependencies=["Numpy>=2.0","scipy[extra]<2"]\n', encoding="utf-8")
        assert en.dependencias(p) == ["numpy", "scipy"]
