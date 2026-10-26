"""Versión Python de J1.8: un tipo propio ``Registro`` con validación y despacho por tipo.

``dataclass(frozen=True)`` hace de ``struct`` inmutable; ``functools.singledispatch``
hace un despacho simple (solo por el tipo del primer argumento), a diferencia del
despacho múltiple de Julia, que mira los tipos de todos los argumentos.
"""
from dataclasses import dataclass
from functools import singledispatch

import numpy as np


@dataclass(frozen=True)
class Registro:
    datos: np.ndarray            # N × c
    fs: float                    # Hz
    canales: tuple
    unidad: str = "m/s²"

    def __post_init__(self):
        if not self.fs > 0:
            raise ValueError(f"fs debe ser positiva (recibido {self.fs})")
        if self.datos.shape[1] != len(self.canales):
            raise ValueError(f"hay {self.datos.shape[1]} columnas y {len(self.canales)} nombres de canal")

    @property
    def muestras(self):
        return self.datos.shape[0]

    @property
    def duracion(self):
        return self.muestras / self.fs

    def __getitem__(self, clave):
        j = self.canales.index(clave) if isinstance(clave, str) else clave
        return self.datos[:, j]


@singledispatch
def rms(x):
    """RMS de un vector (un número)."""
    return float(np.sqrt(np.mean(np.square(np.asarray(x, dtype=float)))))


@rms.register
def _(x: Registro):
    """RMS de cada canal de un ``Registro``."""
    return [rms(x.datos[:, j]) for j in range(x.datos.shape[1])]


def recortar(r, t0, t1):
    """Nuevo ``Registro`` con los datos entre ``t0`` y ``t1`` segundos."""
    i0, i1 = round(t0 * r.fs), round(t1 * r.fs)
    return Registro(r.datos[i0:i1], r.fs, r.canales, r.unidad)
