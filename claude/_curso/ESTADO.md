# Estado del curso de la vía C

Documento vivo. Léelo (junto con `git log`) antes de continuar en una sesión nueva.
Rama de trabajo: `docs/curso-claude-completo`. Plan: [PLAN.md](PLAN.md).

## Fase actual
**Fase 1 · Auditoría, investigación y consolidación de C0** (en curso).

## Hecho
| Fecha | Paso | Comprobación |
|---|---|---|
| 23/10/2026 | Fase 0: rama, `temario.yml` de la vía C (títulos y 94 temas; sin Typst), esqueletos C1–C9 regenerados, índice de la vía, referencias «C0.2» → «C0.5» en M0, M5, M6 y M7 | `generar_estructura.jl --comprobar`: 64 correctas |

## Pendiente inmediato
1. Investigación documental (FUENTES.md, comandos.yml).
2. C0: reordenar en 10 temas, historia y línea temporal, nuevos apartados.
3. Modelo didáctico y niveles.

## Pruebas ejecutadas (última vez)
| Prueba | Resultado | Fecha |
|---|---|---|
| `generar_estructura.jl --comprobar` | Verificado (64/64) | 23/10/2026 |

## Bloqueos y acciones del responsable
- Dependencias Julia y Python: pedirán confirmación al instalarlas (Fase 2).
- Playwright y Chromium: descarga con confirmación (Fase 2).
- FigureLabs: el responsable añadirá el dominio de descarga a `.claude/settings.local.json`.
- Push y merge: solo a petición.

## Problemas conocidos
- Ninguno abierto.
