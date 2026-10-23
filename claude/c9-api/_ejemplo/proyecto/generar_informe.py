"""Proyecto integrador de C9: informe Quarto reproducible de ventas con un paso OPCIONAL de IA.

Flujo: validar (código) → resumir (código) → [borrador de interpretación con Claude, opcional] → informe.qmd → quarto render.
Principios: las cifras las calcula el CÓDIGO, nunca la IA; a la IA solo se le envían cifras agregadas (no filas);
el texto de la IA va en una sección rotulada «borrador sin revisar»; el modo por defecto no usa la IA ni cuesta nada.

Uso:  python generar_informe.py [--ia | --simulado] [--salida carpeta]
"""
import argparse
import csv
import os
import sys
from collections import Counter
from pathlib import Path

AQUI = Path(__file__).resolve().parent
sys.path.insert(0, str(AQUI.parent))
import cliente_claude as cc  # noqa: E402

DATOS = AQUI.parents[3] / "datos" / "sinteticos" / "curso-claude" / "a_ventas.csv"


def leer(ruta=DATOS):
    with open(ruta, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def validar(filas):
    unicas = list(dict.fromkeys(tuple(f.values()) for f in filas))
    return {"filas": len(filas), "duplicadas": len(filas) - len(unicas),
            "ausentes": sum(1 for f in filas if f["ventas_eur"] == "")}


def totales(filas):
    """Totales por región ignorando duplicados y ausentes (misma regla que en C6)."""
    vistos, tot, meses = set(), Counter(), Counter()
    for f in filas:
        clave = tuple(f.values())
        if clave in vistos or f["ventas_eur"] == "":
            continue
        vistos.add(clave)
        tot[f["region"]] += float(f["ventas_eur"])
        meses[f["region"]] += 1
    return {r: {"total_eur": round(tot[r], 2), "meses": meses[r], "media_mensual_eur": round(tot[r] / meses[r], 2)} for r in tot}


def es(x, dec=2):
    """Formato español: 1 911 061,69 (espacio fino como separador de millares y coma decimal)."""
    s = f"{x:,.{dec}f}".replace(",", " ").replace(".", ",")
    return s


def prompt_ia(val, tot):
    lineas = "\n".join(f"- {r}: total {d['total_eur']} €, {d['meses']} meses con dato, media mensual {d['media_mensual_eur']} €" for r, d in tot.items())
    return ("Eres analista de datos. Con SOLO estas cifras agregadas de ventas (datos sintéticos de un curso), escribe dos o tres frases "
            "de interpretación prudente para un informe. No inventes cifras, no atribuyas causas que los datos no demuestran y "
            "menciona que las regiones tienen distinto número de meses con dato.\n\n" + lineas +
            f"\nCalidad: {val['filas']} filas, {val['duplicadas']} duplicadas y {val['ausentes']} ventas ausentes (excluidas).")


def construir(val, tot, interpretacion=None, coste=None):
    filas = "\n".join(f"| {r} | {es(d['total_eur'])} | {d['meses']} | {es(d['media_mensual_eur'])} |" for r, d in tot.items())
    total = sum(d["total_eur"] for d in tot.values())
    ia = ""
    if interpretacion:
        ia = f"""
## Interpretación (borrador generado por IA, sin revisar) {{#sec-ia}}

::: {{.callout-warning title="Revisión humana pendiente"}}
Este párrafo lo ha redactado un modelo de IA a partir **solo** de las cifras de la @tbl-ventas. No sustituye al análisis de una persona:
compruébalo antes de usarlo. Coste de la llamada: {coste if coste is not None else 'desconocido'} USD (estimación).
:::

{interpretacion.strip()}
"""
    return f"""---
title: "Informe de ventas por región (datos sintéticos)"
lang: es
format:
  html:
    embed-resources: true
    toc: true
    number-sections: true
---

## Calidad de los datos {{#sec-calidad}}

El fichero `a_ventas.csv` tiene **{val['filas']} filas**; se han excluido **{val['duplicadas']} fila duplicada** y
**{val['ausentes']} valores ausentes** de `ventas_eur`. Estas cifras las calcula el código del proyecto.

## Ventas por región {{#sec-ventas}}

| Región | Total (€) | Meses con dato | Media mensual (€) |
|---|---|---|---|
{filas}

: Ventas por región sin duplicados ni ausentes. Total conjunto: {es(total)} €. {{#tbl-ventas}}

Las regiones no tienen el mismo número de meses con dato, así que **la media mensual** es la comparación adecuada, no el total.
{ia}
## Reproducibilidad {{#sec-repro}}

Datos sintéticos con semilla fija (`scripts/datos/generar_casos.jl`). Para regenerar: `python generar_informe.py` y `quarto render informe.qmd`.
"""


def principal(argv=None):
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--ia", action="store_true", help="llama a la API de pago (requiere ANTHROPIC_API_KEY)")
    g.add_argument("--simulado", action="store_true", help="paso de IA con transporte falso (sin red ni coste)")
    ap.add_argument("--salida", default=".")
    ap.add_argument("--modelo", default="claude-haiku-5-5")
    a = ap.parse_args(argv)
    filas = leer()
    val, tot = validar(filas), totales(filas)
    interpretacion = coste = None
    if a.ia or a.simulado:
        if a.simulado:
            cli, _ = cc.crear_cliente_simulado([{"texto": "El Centro vende más en total, pero tiene un mes más con dato; la comparación por media mensual es más justa. No se pueden atribuir causas con estos datos.", "entrada": 210, "salida": 48, "modelo": a.modelo}], modelo=a.modelo)
        else:
            if not os.environ.get("ANTHROPIC_API_KEY"):
                print("ERROR: define ANTHROPIC_API_KEY o usa el modo por defecto / --simulado", file=sys.stderr)
                return 2
            cli = cc.crear_cliente()
        try:
            r = cc.llamar(cli, modelo=a.modelo, mensajes=[{"role": "user", "content": prompt_ia(val, tot)}], max_tokens=400,
                          registro=Path(a.salida) / "registro-api.jsonl", etiqueta="interpretacion")
        except Exception as e:  # la IA es opcional: el informe se genera igualmente, y se dice por qué falta
            print(f"AVISO: sin interpretación de IA ({type(e).__name__}); el informe usa solo cálculo", file=sys.stderr)
        else:
            interpretacion, coste = r.texto, round(r.coste_usd, 6)
    salida = Path(a.salida)
    salida.mkdir(parents=True, exist_ok=True)
    (salida / "informe.qmd").write_text(construir(val, tot, interpretacion, coste), encoding="utf-8")
    print(f"Escrito {salida / 'informe.qmd'} ({'con' if interpretacion else 'sin'} borrador de IA)")
    return 0


if __name__ == "__main__":
    sys.exit(principal())
