import numpy as np
import pytest

from senales import detectar_picos, media_movil


def test_media_movil_caso_pequeno():
    assert media_movil([1, 2, 3, 4, 5], 2).tolist() == [1.5, 2.5, 3.5, 4.5]


def test_media_movil_longitud():
    assert len(media_movil(np.arange(10), 4)) == 7


def test_media_movil_ventana_igual_a_la_serie():
    assert media_movil([2, 4, 6], 3).tolist() == [4.0]


@pytest.mark.parametrize("n", [0, -1, 6])
def test_media_movil_rechaza_ventanas_invalidas(n):
    with pytest.raises(ValueError):
        media_movil([1, 2, 3, 4, 5], n)


def test_detectar_picos_simple():
    assert detectar_picos([0, 3, 1, 5, 2, 2, 4, 0], 0) == [1, 3, 6]


def test_detectar_picos_respeta_el_umbral():
    assert detectar_picos([0, 3, 1, 5, 2, 2, 4, 0], 3.5) == [3, 6]


def test_detectar_picos_meseta_no_cuenta():
    assert detectar_picos([0, 2, 2, 0], 0) == []


def test_picos_de_un_seno():
    t = np.arange(0, 1, 0.01)
    assert len(detectar_picos(np.sin(2 * np.pi * 5 * t), 0.5)) == 5
