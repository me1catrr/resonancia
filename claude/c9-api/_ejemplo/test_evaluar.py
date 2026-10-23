import json

import evaluar as ev


def test_linea_base_regex_en_el_conjunto_de_oro():
    r = ev.evaluar(ev.linea_base_regex)
    assert r["exactitud"] == 1.0 and r["aciertos"] == 4


def test_un_modelo_simulado_con_un_error_se_detecta():
    respuestas = {c["texto"]: dict(c["esperado"]) for c in ev.CASOS}
    respuestas[ev.CASOS[1]["texto"]] = {"region": "Centro", "importe": 680.0}        # el modelo «se equivoca» por un factor 100
    r = ev.evaluar(lambda t: respuestas[t])
    assert r["aciertos"] == 3 and r["exactitud"] == 0.75
    assert r["fallos"][0]["obtenido"]["importe"] == 680.0


def test_un_fallo_del_predictor_cuenta_como_error_sin_romper():
    def malo(t):
        raise TimeoutError
    r = ev.evaluar(malo)
    assert r["aciertos"] == 0 and r["fallos"][0]["obtenido"] == {"error": "TimeoutError"}


def test_registro_con_metadatos(tmp_path):
    f = tmp_path / "ev.jsonl"
    ev.registrar(f, "regex", ev.evaluar(ev.linea_base_regex), prompt_version="v1", fecha="2026-10-23")
    linea = json.loads(f.read_text())
    assert linea["sistema"] == "regex" and linea["exactitud"] == 1.0 and linea["prompt_version"] == "v1"
