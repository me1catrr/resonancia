"""Pruebas de graficos.py frente a los picos calculados en Julia (página J1.7).

Ejecutar desde la raíz: ``uv run pytest julia/j1-esencial/j1-7-visualizacion/python``
"""
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

import graficos as gr

RAIZ = Path(__file__).resolve().parents[4]
BASE = RAIZ / "datos" / "sinteticos" / "edificio-3-plantas"

# Julia: buscar_picos(f, P; fmin=0.5, fmax=6, n=3) sobre la planta 3 con psd_welch(nseg=4096)
PICOS_JULIA = {
    "A": [1.0986328125, 2.9296875, 4.39453125],
    "C": [1.07421875, 2.9541015625, 4.248046875],
}


@pytest.mark.parametrize("esc", ["A", "C"])
def test_picos_frente_a_julia(esc):
    a = pd.read_csv(BASE / f"escenario_{esc}.csv", sep=";")
    f, P = gr.espectro(a["a3_ms2"].to_numpy(), 100.0)
    assert gr.picos(f, P) == pytest.approx(PICOS_JULIA[esc], abs=1e-9)


def test_parseval():
    x = np.random.default_rng(0).normal(size=20000)
    f, P = gr.espectro(x, 100.0, nseg=1024)
    assert np.sum(P) * (f[1] - f[0]) == pytest.approx(np.var(x), rel=0.05)


def test_la_figura_se_guarda(tmp_path):
    t = np.arange(1000) / 100.0
    x = np.sin(2 * np.pi * 2.5 * t)
    f, P = gr.espectro(x, 100.0, nseg=256)
    fig = gr.figura_dos_paneles(t, x, f, P, [2.5])
    destino = tmp_path / "f.png"
    fig.savefig(destino, dpi=60)
    assert destino.stat().st_size > 1000
