"""Prueba del servidor MCP con el cliente del SDK (sin Claude): lista herramientas y las llama."""
import asyncio
import sys
from pathlib import Path

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

SERVIDOR = Path(__file__).resolve().parent / "servidor_csv.py"


async def main():
    params = StdioServerParameters(command=sys.executable, args=[str(SERVIDOR)])
    async with stdio_client(params) as (leer, escribir):
        async with ClientSession(leer, escribir) as sesion:
            await sesion.initialize()
            herramientas = await sesion.list_tools()
            print("herramientas:", [t.name for t in herramientas.tools])
            r = await sesion.call_tool("listar_casos", {})
            print("listar_casos:", r.content[0].text)
            r = await sesion.call_tool("resumen_csv", {"caso": "a_ventas"})
            print("resumen_csv:", r.content[0].text)
            r = await sesion.call_tool("resumen_csv", {"caso": "../../CLAUDE"})
            print("ruta maliciosa -> error:", r.is_error, "|", r.content[0].text)


asyncio.run(main())
