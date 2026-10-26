"""Versión Python de J1.2: leer las dependencias declaradas de un proyecto.

Equivale a ``TOML.parsefile("Project.toml")["deps"]`` en Julia: ``pyproject.toml``
declara lo que se pide y ``uv.lock`` fija las versiones exactas.
"""
import re
import tomllib
from pathlib import Path


def dependencias(ruta_pyproject):
    """Nombres de los paquetes declarados en ``[project].dependencies``, ordenados."""
    datos = tomllib.loads(Path(ruta_pyproject).read_text(encoding="utf-8"))
    nombres = (re.split(r"[<>=!~\[; ]", d, maxsplit=1)[0] for d in datos["project"]["dependencies"])
    return sorted(n.lower() for n in nombres)


def versiones_fijadas(ruta_lock):
    """Diccionario ``{paquete: versión}`` leído de ``uv.lock``."""
    datos = tomllib.loads(Path(ruta_lock).read_text(encoding="utf-8"))
    return {p["name"]: p["version"] for p in datos["package"] if "version" in p}
