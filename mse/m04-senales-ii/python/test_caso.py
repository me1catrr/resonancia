"""Prueba de caso.py frente a Julia (referencia/caso.json) sobre los registros reales de Palma del Río.

Ejecutar desde la raíz: ``uv run pytest mse/m04-senales-ii/python``
"""
import json
from pathlib import Path

import numpy as np
import pytest

import caso

AQUI = Path(__file__).parent
REF = json.loads((AQUI.parent / "referencia" / "caso.json").read_text(encoding="utf-8"))
CRUDOS = AQUI.parents[2] / "datos" / "reales-publicables" / "palma-del-rio-puente" / "2020-07-17-vibracion-operacional" / "crudos"


@pytest.fixture(scope="module")
def res():
    return caso.caso_integrado(CRUDOS / "set1.csv", CRUDOS / "set2.csv")


def test_identificacion_y_descriptores(res):
    assert (res["fs"], res["N"]) == (REF["fs"], REF["N"])
    for set_ in ("set1", "set2"):
        for k, v in REF[set_].items():
            assert res[set_][k] == pytest.approx(v, rel=1e-9, abs=1e-12), (set_, k)


def test_espectro_y_picos(res):
    assert res["fraccion_potencia"] == pytest.approx(REF["fraccion_potencia"], rel=1e-8)
    assert list(res["picos_Hz"]) == pytest.approx(REF["picos_Hz"], abs=1e-9)


def test_preprocesado(res):
    assert res["N_diezmado"] == REF["N_diezmado"]
    assert res["rms_diezmado"] == pytest.approx(REF["rms_diezmado"], rel=1e-8)
    assert res["rms_pasabanda"] == pytest.approx(REF["rms_pasabanda"], rel=1e-7)


def test_integracion_y_contraste(res):
    for a, b in zip(res["integracion"], REF["integracion"]):
        for k, v in b.items():
            assert a[k] == pytest.approx(v, rel=1e-7), (b["fcorte"], k)
    assert res["cociente_trafico_fondo"] == pytest.approx(REF["cociente_trafico_fondo"], rel=1e-7)


def test_cifras_del_caso(res):
    """Lo que dice la página: velocidad y desplazamiento estables al variar el corte de 0,3 a 1 Hz."""
    v = [i["v_rms_mms"] for i in res["integracion"]]
    assert max(v) / min(v) < 1.02
    assert res["integracion"][1]["v_rms_mms"] == pytest.approx(7.11, abs=0.01)
    assert res["integracion"][1]["d_rms_mm"] == pytest.approx(0.676, abs=0.001)
    # el diezmado a 64 Hz conserva casi toda la potencia: el 92 % está por debajo de 32 Hz
    assert np.sum(res["fraccion_potencia"][:4]) == pytest.approx(0.918, abs=0.002)
