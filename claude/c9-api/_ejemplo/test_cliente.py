import json
import math

import anthropic
import pytest

import cliente_claude as cc


def test_coste_con_precios_de_la_documentacion():
    assert cc.coste_usd("claude-sonnet-5-5", 20_000, 2_000) == pytest.approx(0.06)
    assert cc.coste_usd("claude-haiku-5-5", 50_000, 1_000) == pytest.approx(0.0055)
    assert cc.coste_usd("claude-opus-5-5", 50_000, 1_000) == pytest.approx(0.22)
    with pytest.raises(KeyError):
        cc.coste_usd("modelo-inexistente", 1, 1)


def test_llamada_correcta_envia_lo_esperado_y_mide_coste(tmp_path):
    cli, vistas = cc.crear_cliente_simulado([{"texto": "Hola", "entrada": 20_000, "salida": 2_000}])
    log = tmp_path / "log.jsonl"
    r = cc.llamar(cli, modelo="claude-sonnet-5-5", mensajes=[{"role": "user", "content": "Di hola"}], sistema="Sé breve", max_tokens=100, registro=log)
    assert r.texto == "Hola" and r.coste_usd == pytest.approx(0.06) and r.parada == "end_turn"
    cuerpo = vistas[0]
    assert cuerpo["model"] == "claude-sonnet-5-5" and cuerpo["max_tokens"] == 100 and cuerpo["system"] == "Sé breve"
    assert "clave-simulada" not in json.dumps(cuerpo)          # la clave nunca viaja en el cuerpo
    linea = json.loads(log.read_text().splitlines()[0])
    assert linea["tokens_entrada"] == 20_000 and "Di hola" not in log.read_text()   # se registra un hash, no el texto
    assert len(linea["prompt_sha256"]) == 16


def test_429_se_reintenta_y_respeta_retry_after():
    cli, vistas = cc.crear_cliente_simulado([{"estado": 429, "retry_after": "7"}, {"estado": 429, "retry_after": "7"}, {"texto": "ok"}])
    pausas = []
    r = cc.llamar(cli, modelo="claude-sonnet-5-5", mensajes=[{"role": "user", "content": "x"}], reintentos=3, dormir=pausas.append)
    assert r.texto == "ok" and len(vistas) == 3 and pausas == [7.0, 7.0]


def test_429_persistente_agota_los_intentos():
    cli, vistas = cc.crear_cliente_simulado([{"estado": 429}])
    with pytest.raises(anthropic.RateLimitError):
        cc.llamar(cli, modelo="claude-sonnet-5-5", mensajes=[{"role": "user", "content": "x"}], reintentos=2, espera_s=0, dormir=lambda s: None)
    assert len(vistas) == 2


@pytest.mark.parametrize("estado,clase", [(400, anthropic.BadRequestError), (401, anthropic.AuthenticationError),
                                          (403, anthropic.PermissionDeniedError), (404, anthropic.NotFoundError)])
def test_errores_del_cliente_no_se_reintentan(estado, clase):
    cli, vistas = cc.crear_cliente_simulado([{"estado": estado}])
    with pytest.raises(clase):
        cc.llamar(cli, modelo="claude-sonnet-5-5", mensajes=[{"role": "user", "content": "x"}], reintentos=3, dormir=lambda s: None)
    assert len(vistas) == 1


def test_error_5xx_se_reintenta():
    cli, vistas = cc.crear_cliente_simulado([{"estado": 500}, {"texto": "recuperado"}])
    assert cc.llamar(cli, modelo="claude-sonnet-5-5", mensajes=[{"role": "user", "content": "x"}], espera_s=0, dormir=lambda s: None).texto == "recuperado"
    assert len(vistas) == 2


def test_truncado_y_rechazo_abortan():
    cli, _ = cc.crear_cliente_simulado([{"texto": "a medias", "parada": "max_tokens"}])
    with pytest.raises(RuntimeError, match="truncada"):
        cc.llamar(cli, modelo="claude-sonnet-5-5", mensajes=[{"role": "user", "content": "x"}])
    cli, _ = cc.crear_cliente_simulado([{"texto": "", "parada": "refusal"}])
    with pytest.raises(RuntimeError, match="rechaz"):
        cc.llamar(cli, modelo="claude-sonnet-5-5", mensajes=[{"role": "user", "content": "x"}])


def test_modelo_sin_precio_da_coste_nan():
    cli, _ = cc.crear_cliente_simulado([{"texto": "x", "modelo": "claude-nuevo-9"}])
    assert math.isnan(cc.llamar(cli, modelo="claude-nuevo-9", mensajes=[{"role": "user", "content": "x"}]).coste_usd)


CLAVES = {"region": str, "total": (int, float)}


def test_json_valido_a_la_primera():
    cli, vistas = cc.crear_cliente_simulado([{"texto": '{"region": "Norte", "total": 1911061.69}'}])
    datos, r = cc.extraer_json(cli, modelo="claude-sonnet-5-5", instruccion="Extrae", texto="…", claves=CLAVES)
    assert datos == {"region": "Norte", "total": 1911061.69} and len(vistas) == 1


def test_json_invalido_se_repara_una_vez():
    cli, vistas = cc.crear_cliente_simulado([{"texto": "Claro: Norte, 1911061.69"}, {"texto": '{"region": "Norte", "total": 1911061.69}'}])
    datos, _ = cc.extraer_json(cli, modelo="claude-sonnet-5-5", instruccion="Extrae", texto="…", claves=CLAVES)
    assert datos["region"] == "Norte" and len(vistas) == 2
    assert vistas[1]["messages"][-1]["content"].startswith("Tu respuesta no es válida")


def test_json_con_tipo_incorrecto_tras_reparar_falla():
    cli, _ = cc.crear_cliente_simulado([{"texto": '{"region": 5, "total": "mucho"}'}])
    with pytest.raises(ValueError, match="no válida"):
        cc.extraer_json(cli, modelo="claude-sonnet-5-5", instruccion="Extrae", texto="…", claves=CLAVES)


def test_cli_simulado(capsys, monkeypatch):
    import sys
    monkeypatch.setattr(sys, "argv", ["cliente_claude.py", "texto de prueba largo para resumir", "--simulado"])
    import runpy
    runpy.run_path(cc.__file__, run_name="__main__")
    salida = json.loads(capsys.readouterr().out)
    assert salida["tokens_entrada"] == 25 and salida["tokens_salida"] == 12 and salida["coste_usd"] == pytest.approx(0.00017)
