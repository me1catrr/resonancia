# Estado del curso de la vía C

Documento vivo. Léelo (junto con `git log`) antes de continuar en una sesión nueva.
Rama de trabajo: `docs/curso-claude-completo`. Plan: [PLAN.md](PLAN.md).

## Fase actual
**Fase 1 · Auditoría, investigación y consolidación de C0** (en curso).

## Hecho
| Fecha | Paso | Comprobación |
|---|---|---|
| 23/10/2026 | Fase 0: rama, `temario.yml` de la vía C (títulos y 94 temas; sin Typst), esqueletos C1–C9 regenerados, índice de la vía, referencias «C0.2» → «C0.5» en M0, M5, M6 y M7 | `generar_estructura.jl --comprobar`: 64 correctas |

| 23/10/2026 | Registro de 73 comandos y fuentes de Claude Code (commit 0f6868d) | YAML válido; 67 verificados, 3 cambiados, 1 eliminado, 2 pendientes |

## Pendiente inmediato
1. ~~Investigación documental (FUENTES.md, comandos.yml).~~ Hecho para Claude Code; falta historia (C0) y GSD.
2. C0: reordenar en 10 temas, historia y línea temporal, nuevos apartados.
   Hitos ya verificados en fuente primaria (23/10/2026): Turing 1950, *Mind* LIX(236):433–460 ·
   Rosenblatt 1958, *Psychological Review* 65(6):386–408 · Vaswani et al., arXiv:1706.03762 (v1 12/06/2017) ·
   Krizhevsky, Sutskever y Hinton, *CACM* 60(6):84–90 (2017; reedición del trabajo de 2012, pendiente de confirmar) ·
   Claude y Claude Instant, 14/03/2023 (anthropic.com/news/introducing-claude) · MCP, 25/11/2024
   (anthropic.com/news/model-context-protocol) · Claude Code en vista previa limitada con Claude 3.7 Sonnet,
   24/02/2025 (anthropic.com/news/claude-3-7-sonnet).
   Pendientes: ELIZA 1966 y Rumelhart et al. 1986 (Crossref devolvió 429), Dartmouth 1955–56 (servidor de
   Stanford rechazó la conexión), ChatGPT 30/11/2022 y Nobel 2024 (403).
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
