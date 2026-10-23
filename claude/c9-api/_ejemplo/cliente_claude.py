"""Cliente mínimo y prudente para la API de Claude (ejemplo didáctico de C9).

Qué demuestra: autenticación por variable de entorno (la clave nunca va en el código), petición con
límites (max_tokens), clasificación de errores reintentables y no reintentables, cálculo de coste a partir de
`usage`, registro JSON-lines sin datos sensibles y salida estructurada validada por nosotros.

NO llama a la red por sí solo: la función `crear_cliente_simulado()` usa un transporte falso para
probar todo sin clave ni coste. Con una clave real, `crear_cliente()` usa la API de pago (opcional).
"""
import hashlib
import json
import logging
import os
import time
from dataclasses import dataclass

import anthropic

# Precios por millón de tokens (entrada, salida) en dólares, de la documentación de modelos consultada el
# 23-10-2026. CAMBIAN: consúltalos antes de calcular costes reales.
PRECIOS = {
    "claude-haiku-5-5": (0.10, 0.50),
    "claude-sonnet-5-5": (2.00, 10.00),
    "claude-opus-5-5": (4.00, 20.00),
}

REINTENTABLES = (anthropic.RateLimitError, anthropic.APIConnectionError, anthropic.InternalServerError)


@dataclass
class Resultado:
    texto: str
    modelo: str
    tokens_entrada: int
    tokens_salida: int
    coste_usd: float
    parada: str
    id_peticion: str | None


def coste_usd(modelo, tokens_entrada, tokens_salida):
    """Coste estimado en dólares (sin caché ni descuentos). Lanza KeyError si no conocemos el precio del modelo."""
    p_ent, p_sal = PRECIOS[modelo]
    return (tokens_entrada * p_ent + tokens_salida * p_sal) / 1e6


def crear_cliente(**kw):
    """Cliente real. La clave se lee del entorno (ANTHROPIC_API_KEY) o de la sesión de `ant auth login`."""
    return anthropic.Anthropic(**kw)


def llamar(cliente, *, modelo, mensajes, sistema=None, max_tokens=1024, reintentos=3, espera_s=1.0,
           registro=None, etiqueta="llamada", dormir=time.sleep):
    """Una petición con reintentos para errores transitorios. Devuelve un Resultado.

    - 429, errores de conexión y 5xx se reintentan con espera creciente (respetando `retry-after` si viene).
    - 400, 401, 403 y 404 NO se reintentan: son errores nuestros (petición, clave, permisos, modelo).
    - Se aborta si el modelo se queda sin tokens (max_tokens) o rechaza la petición (refusal).
    - El registro (JSON-lines) guarda modelo, tokens, coste y un hash del prompt, NUNCA el texto ni la clave.
    """
    argumentos = {"model": modelo, "max_tokens": max_tokens, "messages": mensajes}
    if sistema:
        argumentos["system"] = sistema
    ultimo = None
    for intento in range(1, reintentos + 1):
        try:
            r = cliente.messages.create(**argumentos)
            break
        except REINTENTABLES as e:
            ultimo = e
            retry = getattr(getattr(e, "response", None), "headers", {}).get("retry-after") if hasattr(e, "response") else None
            pausa = float(retry) if retry else espera_s * 2 ** (intento - 1)
            logging.warning("%s: intento %d/%d fallido (%s); espero %.1fs", etiqueta, intento, reintentos, type(e).__name__, pausa)
            if intento < reintentos:
                dormir(pausa)
    else:
        raise ultimo
    texto = "".join(b.text for b in r.content if b.type == "text")
    if r.stop_reason == "max_tokens":
        raise RuntimeError("respuesta truncada: sube max_tokens o pide menos")
    if r.stop_reason == "refusal":
        raise RuntimeError("el modelo rechazó la petición (refusal)")
    res = Resultado(texto, r.model, r.usage.input_tokens, r.usage.output_tokens,
                    coste_usd(r.model, r.usage.input_tokens, r.usage.output_tokens) if r.model in PRECIOS else float("nan"),
                    r.stop_reason, getattr(r, "_request_id", None))
    if registro:
        huella = hashlib.sha256(json.dumps(mensajes, sort_keys=True, ensure_ascii=False).encode()).hexdigest()[:16]
        with open(registro, "a", encoding="utf-8") as f:
            f.write(json.dumps({"t": time.strftime("%Y-%m-%dT%H:%M:%S"), "etiqueta": etiqueta, "modelo": res.modelo,
                                "tokens_entrada": res.tokens_entrada, "tokens_salida": res.tokens_salida,
                                "coste_usd": res.coste_usd, "parada": res.parada, "prompt_sha256": huella}) + "\n")
    return res


def extraer_json(cliente, *, modelo, instruccion, texto, claves, max_tokens=512, **kw):
    """Salida estructurada «a mano»: se pide JSON, se parsea y se VALIDA (claves y tipos). Si falla, un reintento de reparación.

    La API ofrece además salida estructurada con esquema (output_config.format / messages.parse): aquí no se usa porque
    no se ha probado en este curso; la validación propia sirve con cualquier modelo.
    `claves` es un dict {nombre: tipo}.
    """
    sistema = "Responde SOLO con un objeto JSON, sin texto adicional ni bloques de código."
    mensajes = [{"role": "user", "content": f"{instruccion}\n\nTexto:\n{texto}\n\nClaves: {list(claves)}"}]
    for intento in (1, 2):
        res = llamar(cliente, modelo=modelo, mensajes=mensajes, sistema=sistema, max_tokens=max_tokens, etiqueta="extraer_json", **kw)
        try:
            datos = json.loads(res.texto)
            if not isinstance(datos, dict):
                raise ValueError("no es un objeto JSON")
            faltan = [k for k in claves if k not in datos]
            malos = [k for k, t in claves.items() if k in datos and not isinstance(datos[k], t)]
            if faltan or malos:
                raise ValueError(f"faltan {faltan}, tipo incorrecto {malos}")
            return datos, res
        except ValueError as e:
            if intento == 2:
                raise ValueError(f"salida no válida tras reparar: {e}") from e
            mensajes = mensajes + [{"role": "assistant", "content": res.texto},
                                   {"role": "user", "content": f"Tu respuesta no es válida ({e}). Devuelve solo el JSON corregido."}]


def crear_cliente_simulado(respuestas, *, modelo="claude-sonnet-5-5"):
    """Cliente REAL del SDK con un transporte falso (sin red ni clave): `respuestas` es una lista de dicts
    {"estado": 200, "texto": "...", "entrada": n, "salida": n} o de errores {"estado": 429, "retry_after": "1"}.
    Devuelve (cliente, peticiones_vistas)."""
    import httpx2
    vistas, cola = [], list(respuestas)

    def manejador(p):
        vistas.append(json.loads(p.content))
        r = cola.pop(0) if len(cola) > 1 else cola[0]
        if r.get("estado", 200) != 200:
            tipos = {400: "invalid_request_error", 401: "authentication_error", 403: "permission_error",
                     404: "not_found_error", 429: "rate_limit_error", 500: "api_error", 529: "overloaded_error"}
            h = {"retry-after": r["retry_after"]} if "retry_after" in r else {}
            return httpx2.Response(r["estado"], headers=h, json={"type": "error", "error": {"type": tipos.get(r["estado"], "api_error"), "message": r.get("mensaje", "error simulado")}})
        return httpx2.Response(200, json={
            "id": "msg_sim", "type": "message", "role": "assistant", "model": r.get("modelo", modelo),
            "content": [{"type": "text", "text": r["texto"]}], "stop_reason": r.get("parada", "end_turn"), "stop_sequence": None,
            "usage": {"input_tokens": r.get("entrada", 10), "output_tokens": r.get("salida", 5),
                      "cache_creation_input_tokens": 0, "cache_read_input_tokens": 0}})

    cliente = anthropic.Anthropic(api_key="clave-simulada", max_retries=0,
                                  http_client=anthropic.DefaultHttpxClient(transport=httpx2.MockTransport(manejador)))
    return cliente, vistas


if __name__ == "__main__":
    import argparse
    import sys
    ap = argparse.ArgumentParser(description="Resume un texto con Claude (o en modo --simulado, sin red).")
    ap.add_argument("texto")
    ap.add_argument("--modelo", default="claude-sonnet-5-5")
    ap.add_argument("--simulado", action="store_true", help="usa un transporte falso: sin clave, sin red, sin coste")
    a = ap.parse_args()
    if a.simulado:
        cli, _ = crear_cliente_simulado([{"texto": "Resumen simulado de: " + a.texto[:40], "entrada": 25, "salida": 12}], modelo=a.modelo)
    else:
        if not os.environ.get("ANTHROPIC_API_KEY"):
            print("ERROR: define ANTHROPIC_API_KEY (llamada de pago) o usa --simulado", file=sys.stderr)
            sys.exit(2)
        cli = crear_cliente()
    try:
        r = llamar(cli, modelo=a.modelo, mensajes=[{"role": "user", "content": f"Resume en una frase: {a.texto}"}], max_tokens=200)
    except anthropic.APIError as e:
        print(f"ERROR de la API: {type(e).__name__}", file=sys.stderr)
        sys.exit(3)
    print(json.dumps({"texto": r.texto, "modelo": r.modelo, "tokens_entrada": r.tokens_entrada,
                      "tokens_salida": r.tokens_salida, "coste_usd": round(r.coste_usd, 6)}, ensure_ascii=False))
