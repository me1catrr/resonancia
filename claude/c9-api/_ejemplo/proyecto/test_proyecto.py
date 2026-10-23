import json
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generar_informe as gi


def test_validacion_y_totales_coinciden_con_c6():
    f = gi.leer()
    assert gi.validar(f) == {"filas": 109, "duplicadas": 1, "ausentes": 5}
    t = gi.totales(f)
    assert t["Norte"]["total_eur"] == pytest.approx(1911061.69, abs=0.01)
    assert t["Centro"]["total_eur"] == pytest.approx(2539781.72, abs=0.01)
    assert t["Sur"]["total_eur"] == pytest.approx(1619001.97, abs=0.01)
    assert sum(d["total_eur"] for d in t.values()) == pytest.approx(6069845.38, abs=0.01)
    assert (t["Norte"]["meses"], t["Centro"]["meses"], t["Sur"]["meses"]) == (34, 35, 34)


def test_formato_espanol():
    assert gi.es(1911061.69) == "1 911 061,69"


def test_prompt_solo_lleva_cifras_agregadas():
    f = gi.leer()
    p = gi.prompt_ia(gi.validar(f), gi.totales(f))
    assert "Norte" in p and "1911061.69" in p
    assert "2023-01-01" not in p and "ventas_eur" not in p        # ninguna fila ni fecha: minimización de datos


def test_modo_por_defecto_no_usa_ia(tmp_path):
    assert gi.principal(["--salida", str(tmp_path)]) == 0
    q = (tmp_path / "informe.qmd").read_text(encoding="utf-8")
    assert "sin revisar" not in q and "1 911 061,69" in q and "109 filas" in q
    assert not (tmp_path / "registro-api.jsonl").exists()


def test_modo_simulado_etiqueta_el_borrador_y_registra(tmp_path):
    assert gi.principal(["--simulado", "--salida", str(tmp_path)]) == 0
    q = (tmp_path / "informe.qmd").read_text(encoding="utf-8")
    assert "borrador generado por IA, sin revisar" in q and "Revisión humana pendiente" in q and "No se pueden atribuir causas" in q
    linea = json.loads((tmp_path / "registro-api.jsonl").read_text().splitlines()[0])
    assert linea["modelo"] == "claude-haiku-5-5" and linea["tokens_entrada"] == 210
    assert "Norte" not in (tmp_path / "registro-api.jsonl").read_text()     # el registro no guarda el prompt


def test_sin_clave_con_ia_falla_con_codigo_2(tmp_path, monkeypatch):
    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    assert gi.principal(["--ia", "--salida", str(tmp_path)]) == 2


@pytest.mark.skipif(shutil.which("quarto") is None, reason="quarto no instalado")
def test_el_informe_se_renderiza(tmp_path):
    gi.principal(["--simulado", "--salida", str(tmp_path)])
    r = subprocess.run(["quarto", "render", "informe.qmd"], cwd=tmp_path, capture_output=True, text=True)
    assert r.returncode == 0, r.stderr[-500:]
    assert "Interpretación" in (tmp_path / "informe.html").read_text(encoding="utf-8")
