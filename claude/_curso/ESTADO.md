# Estado del curso de la vía C

Documento vivo. Léelo (junto con `git log`) antes de continuar en una sesión nueva.
Rama de trabajo: `docs/curso-claude-completo`. Plan: [PLAN.md](PLAN.md).

## Fase actual
**Fase 1 · Auditoría, investigación y consolidación de C0**: cerrada el 23/10/2026.
Siguiente: **Fase 2 · Arquitectura docente** (en curso: indicador hecho; sigue `auditar_claude.jl`, responsive y portada). Entorno: sin `uv`, `deno` ni `pwsh`; Claude Code instalado 2.1.306.

## Hecho
| Fecha | Paso | Comprobación |
|---|---|---|
| 23/10/2026 | Fase 0: rama, `temario.yml` de la vía C (títulos y 94 temas; sin Typst), esqueletos C1–C9 regenerados, índice de la vía, referencias «C0.2» → «C0.5» en M0, M5, M6 y M7 | `generar_estructura.jl --comprobar`: 64 correctas |
| 23/10/2026 | Registro de 73 comandos y fuentes de Claude Code (commit 0f6868d) | YAML válido; 67 verificados, 3 cambiados, 1 eliminado, 2 pendientes |
| 23/10/2026 | C0 en diez temas: historia (C0.1), redes y transformers (C0.2), asistentes y agentes (C0.4), supervisión humana (C0.9); 2 simulaciones OJS; línea temporal (15 hitos, 2 con fuente secundaria declarada); 9 referencias nuevas; diapositivas | `quarto render` sin avisos; 15 citas resueltas; 20 ejercicios; Deno 34/34 |
| 23/10/2026 | Fase 2.1: `claude/_versiones.yml` + `scripts/version_unidad.lua` (rótulo bajo el título, falla si falta la entrada) | `quarto render` de C0 y C1: rótulo visible, sin avisos |
| 23/10/2026 | Modelo didáctico, niveles y etiquetas de ejecución ([MODELO.md](MODELO.md)) | Revisado manualmente |

## Pendiente inmediato (Fase 2)
1. ~~Indicador de versión~~ (hecho).
2. `scripts/auditar_claude.jl --comprobar` y hoja de consulta generada desde `comandos.yml`.
3. Diseño responsive (`grid`, `.dos-columnas`) y portada de la vía C.
4. Componentes: ciclo del agente, explorador de terminal, visualizador Git y worktrees, jerarquía de CLAUDE.md…
5. Dependencias (pyproject con uv; DataFrames, CSV, XLSX y CairoMakie en Julia) con confirmación; datos sintéticos A–E.
6. Playwright a 5 anchuras; comprobador de enlaces internos. Probar en navegador las simulaciones de C0.

## Pruebas ejecutadas (última vez)
| Prueba | Resultado | Fecha |
|---|---|---|
| `generar_estructura.jl --comprobar` | Verificado (64/64) | 23/10/2026 |
| `generar_bibliografia.jl --comprobar` | Verificado (30 entradas) | 23/10/2026 |
| Deno `recursos/js/` | Verificado (34/34) | 23/10/2026 |
| `quarto render` del sitio completo | Verificado (sin errores; control de `docs/` en verde) | 23/10/2026 |
| Simulaciones OJS de C0 en navegador | Pendiente (Playwright, Fase 2) | — |

## Bloqueos y acciones del responsable
- Dependencias Julia y Python: pedirán confirmación al instalarlas (Fase 2).
- Playwright y Chromium: descarga con confirmación (Fase 2).
- FigureLabs: el responsable añadirá el dominio de descarga a `.claude/settings.local.json`.
- Publicación: al cerrar cada fase, `main` local queda adelantado por avance rápido; el responsable ejecuta `git push` (el entorno aislado no llega a GitHub).

## Problemas conocidos
- Ninguno abierto.
