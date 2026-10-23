"""Evaluación mínima y reproducible de una extracción (ejemplo didáctico de C9.6).

Un conjunto de casos con respuesta esperada («conjunto de oro»), una métrica clara (coincidencia exacta por campo) y una
LÍNEA BASE LOCAL GRATUITA (expresión regular) con la que comparar cualquier modelo. Todo es determinista y sin red;
los «modelos» de la prueba son respuestas simuladas.
"""
import json
import re

CASOS = [  # texto sintético → lo que debe extraerse
    {"texto": "Las ventas de la región Norte fueron 52.310,50 euros en enero.", "esperado": {"region": "Norte", "importe": 52310.50}},
    {"texto": "En febrero, el Centro facturó 68.000 euros.", "esperado": {"region": "Centro", "importe": 68000.0}},
    {"texto": "Sur: 44.120,75 € de ventas en marzo.", "esperado": {"region": "Sur", "importe": 44120.75}},
    {"texto": "La región Norte no informó ventas este mes.", "esperado": {"region": "Norte", "importe": None}},
]


def _numero(s):
    return float(s.replace(".", "").replace(",", "."))


def linea_base_regex(texto):
    """Alternativa local gratuita: región por lista cerrada e importe por patrón numérico en euros."""
    region = next((r for r in ("Norte", "Centro", "Sur") if r in texto), None)
    m = re.search(r"(\d{1,3}(?:\.\d{3})*(?:,\d+)?)\s*(?:euros|€)", texto)
    return {"region": region, "importe": _numero(m.group(1)) if m else None}


def evaluar(predictor, casos=CASOS):
    """Devuelve {'aciertos', 'total', 'exactitud', 'fallos': [...]} con coincidencia exacta de todos los campos de cada caso."""
    fallos = []
    for c in casos:
        try:
            obtenido = predictor(c["texto"])
        except Exception as e:  # un fallo del predictor cuenta como error, no detiene la evaluación
            obtenido = {"error": type(e).__name__}
        if obtenido != c["esperado"]:
            fallos.append({"texto": c["texto"], "esperado": c["esperado"], "obtenido": obtenido})
    n = len(casos)
    return {"aciertos": n - len(fallos), "total": n, "exactitud": (n - len(fallos)) / n, "fallos": fallos}


def registrar(ruta, nombre, resultado, **meta):
    """Añade una línea JSON con el resultado y los metadatos de reproducibilidad (modelo, versión del prompt, fecha…)."""
    with open(ruta, "a", encoding="utf-8") as f:
        f.write(json.dumps({"sistema": nombre, "exactitud": resultado["exactitud"], "aciertos": resultado["aciertos"],
                            "total": resultado["total"], **meta}, ensure_ascii=False) + "\n")
