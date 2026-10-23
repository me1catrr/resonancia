"""Servidor MCP local de SOLO LECTURA sobre los datos sintéticos del curso (ejemplo de C7).

Expone dos herramientas que únicamente leen:
  - listar_casos(): nombres de los CSV disponibles;
  - resumen_csv(caso): filas, columnas y ausentes por columna de un CSV.
Y un recurso: resumen://casos con la misma lista. No escribe, no abre red y solo
sirve ficheros de la carpeta de datos sintéticos (el nombre se valida).

Ejecución (stdio): uv run --with "mcp>=2" python servidor_csv.py
"""
import csv
from pathlib import Path

from mcp.server.mcpserver import MCPServer

DATOS = Path(__file__).resolve().parents[4] / "datos" / "sinteticos" / "curso-claude"
mcp = MCPServer("datos-sinteticos-curso")


def _casos():
    return sorted(p.stem for p in DATOS.glob("*.csv"))


@mcp.tool()
def listar_casos() -> list[str]:
    """Lista los casos disponibles (nombre de fichero sin extensión)."""
    return _casos()


@mcp.tool()
def resumen_csv(caso: str) -> dict:
    """Filas, columnas y valores ausentes por columna de un caso de datos sintéticos.

    `caso` debe ser uno de los devueltos por `listar_casos` (p. ej. "a_ventas").
    """
    if caso not in _casos():          # lista blanca: impide rutas como ../../secreto
        raise ValueError(f"caso desconocido: {caso!r}; usa listar_casos()")
    with open(DATOS / f"{caso}.csv", newline="", encoding="utf-8") as f:
        lector = csv.DictReader(f)
        filas = list(lector)
        columnas = lector.fieldnames or []
    ausentes = {c: sum(1 for r in filas if r[c] == "") for c in columnas}
    return {"caso": caso, "filas": len(filas), "columnas": columnas, "ausentes": ausentes}


@mcp.resource("resumen://casos")
def casos_disponibles() -> str:
    """Los casos disponibles, uno por línea."""
    return "\n".join(_casos())


if __name__ == "__main__":
    mcp.run(transport="stdio")
