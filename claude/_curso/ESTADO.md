# Estado del curso de la vía C

Documento vivo. Léelo (junto con `git log`) antes de continuar en una sesión nueva.
Rama de trabajo: `docs/curso-claude-completo`. Plan: [PLAN.md](PLAN.md).

## Fase actual
**Fase 2 · Arquitectura docente**: cerrada el 23/10/2026 (los componentes interactivos se construyen en la unidad que los usa).
**C0–C9 redactadas.** Siguiente: revisión final transversal (coherencia, enlaces, verificación de pendientes) y `INFORME.md`. Entorno: `uv` 0.13.5, `deno` 2.7.14, `pwsh` 7.6.8 (macOS; no Windows PowerShell 5.1); Claude Code instalado 2.1.306.

## Hecho
| Fecha | Paso | Comprobación |
|---|---|---|
| 23/10/2026 | Fase 0: rama, `temario.yml` de la vía C (títulos y 94 temas; sin Typst), esqueletos C1–C9 regenerados, índice de la vía, referencias «C0.2» → «C0.5» en M0, M5, M6 y M7 | `generar_estructura.jl --comprobar`: 64 correctas |
| 23/10/2026 | Registro de 73 comandos y fuentes de Claude Code (commit 0f6868d) | YAML válido; 67 verificados, 3 cambiados, 1 eliminado, 2 pendientes |
| 23/10/2026 | C0 en diez temas: historia (C0.1), redes y transformers (C0.2), asistentes y agentes (C0.4), supervisión humana (C0.9); 2 simulaciones OJS; línea temporal (15 hitos, 2 con fuente secundaria declarada); 9 referencias nuevas; diapositivas | `quarto render` sin avisos; 15 citas resueltas; 20 ejercicios; Deno 34/34 |
| 23/10/2026 | Fase 2.1: `claude/_versiones.yml` + `scripts/version_unidad.lua` (rótulo bajo el título, falla si falta la entrada) | `quarto render` de C0 y C1: rótulo visible, sin avisos |
| 23/10/2026 | Fase 2.2: `scripts/auditar_claude.jl --comprobar` (versiones, registro de comandos, versión instalada 2.1.306) | Verificado: 10 unidades, 73 comandos, 2 avisos (`gh-pr`, `gsd` pendientes) |
| 23/10/2026 | Fase 2.3: `grid` en `_quarto.yml` (cuerpo 880 px) y CSS adaptable (tablas y código con desplazamiento propio, `.dos-columnas`) | Render de C0 sin avisos; **sin prueba visual** (falta Playwright) |
| 23/10/2026 | Fase 2.4: `pyproject.toml` + `uv.lock` (pandas, openpyxl, matplotlib; dev: pytest, playwright); `pruebas/web/test_vista.py` (5 anchuras sobre la vía C) | **Verificado**: 55/55 (sin desbordamiento, recursos rotos ni errores JS); captura de C0 a 390 px revisada |
| 23/10/2026 | Fase 2.5: `pruebas/web/test_enlaces.py` (enlaces y anclas internos de la vía C); corregido el enlace «Diapositivas» (`slides.qmd` → `slides.html`) en C0–C9 | **Verificado**: 21/21 |
| 23/10/2026 | Fase 2.6: portada de la vía C (itinerarios, niveles, estado) y datos sintéticos A–E (`scripts/datos/generar_casos.jl`, semilla 20261023, fichas `.meta.toml`) | Portada: render y 26 pruebas web verdes. Datos: salida idéntica en dos ejecuciones; picos del caso E en 12,5 y 41,0 Hz (DFT directa) |
| 23/10/2026 | Fase 2.7: hoja de consulta generada (`scripts/generar_hoja.jl` → `claude/hoja-consulta.qmd` y `descargas/hoja-consulta.txt`), enlazada desde la portada | `--comprobar` al día; render sin avisos |
| 23/10/2026 | Fase 3.1: auditoría de C0 (v0.3.0): analogía modal, atención causal/bidireccional, objetivo de entrenamiento frente a verificación factual, interpretación de softmax, seudonimización, vigencia del Reglamento 2024/1689 y su ómnibus 2026/1744, bins frente a resolución efectiva; `omnibus2026` en la bibliografía | Ejercicios numéricos recalculados (0,1; 0,8808; 0,982); enlaces externos: 21/27 en 200, 5 con 403 de bots, 1 artefacto del extractor; EUR-Lex sin acceso (normativa **solo con fuentes secundarias**); pruebas de interacción de las simulaciones (2/2) |
| 23/10/2026 | Fase 3.2: **C1 redactada** (v0.2.0): nueve temas, 10 ejercicios intercalados, práctica con el caso A (cifras de referencia recalculadas con Julia: 109/108/5, 6 069 845,38 €), portada TikZ, diapositivas, 9 fuentes nuevas | Render sin avisos; pruebas web verdes. Estado «pendiente de revisión»: planes y límites vía resúmenes automáticos |
| 23/10/2026 | Pruebas web ampliadas: imágenes decodificadas, accesibilidad HTML (ids, alt, h1) y duplicado «Referencias» en el índice (se oculta con CSS acotado) | Verificado |
| 23/10/2026 | Fase 3.3: **C2 redactada** (v0.2.0, solo macOS y Windows): once temas, 12 áreas del prompt maestro, 17 ejercicios intercalados, tres prácticas (inspección de proyecto Quarto, automatización Python + informe, auditoría de comandos de IA), proyecto `_ejemplo/proyecto-viga` con script Python (6 pruebas pytest) y scripts `ejecutar.zsh`/`ejecutar.ps1`; títulos de C2 ajustados en `temario.yml` | Zsh 5.9 y **PowerShell 7.6.8 sobre macOS** ejecutados con las mismas salidas (3 TODO, 2049 líneas, f_dominante 12,5 Hz, SHA-256 idéntico); códigos de salida 0/2/3 probados en ambas shells. **No ejecutadas**: órdenes solo de Windows (`Get-Acl`, `icacls`, winget, Programador de tareas), red y `launchctl` (plist validado con `plutil -lint`) |
| 23/10/2026 | Fase 3.4: **C3 redactada** (v0.2.0): diez temas, 14 ejercicios intercalados, ejercicio central rama → Claude Code → pruebas → diff → integración, portada TikZ, diapositivas, 4 fuentes nuevas; prueba de C2 hecha robusta (lee columnas por nombre) | Git 2.55.0 probado en repositorios temporales (flujo, ramas, conflicto, rebase, merge, tag, stash, revert, worktree, ignorados); solución de referencia: 8 pruebas, pico_a_pico = 2,56584 (parche con `git apply --check`); YAML de Actions validado en local. **No ejecutado**: Claude Code en el ejercicio, GitHub (remotos, PR, Actions) |
| 23/10/2026 | Fase 3.5: **C4 redactada** (v0.2.0): nueve temas, 11 ejercicios intercalados, Simulación 3 (evaluador de reglas de permisos `recursos/js/componentes/permisos.js`, 9 pruebas Deno y 1 de navegador), `CLAUDE.md` de ejemplo, tabla de comandos cambiados, práctica con lectura del `CLAUDE.md` y `.claude/settings.json` reales, portada, diapositivas, 4 fuentes nuevas | `claude --help` 2.1.306 contiene las opciones citadas; `claude doctor` ejecutado. **No ejecutado**: instalación en macOS/Windows, sesión interactiva de la práctica (requieren cuenta y red) |
| 23/10/2026 | Fase 4.1: **C5 redactada** (v0.2.0): nueve temas, 14 ejercicios intercalados, ejemplo `_ejemplo/` en Python y Julia (media_movil y detectar_picos, versión errónea para depurar y traducción MATLAB→Julia), portada, diapositivas, 3 fuentes nuevas | Ejecutado: 10 pruebas pytest, 10 aserciones Julia; coincidencia Python/Julia sobre el caso E (23 picos > 0,8; índices desplazados 1). **No ejecutado**: MATLAB (no instalado), diálogos con Claude |
| 23/10/2026 | Fase 4.2: **C6 redactada** (v0.2.0): ocho temas, 11 ejercicios intercalados, cinco casos sintéticos (A–E), tres figuras CairoMakie (SVG), informe Quarto de ejemplo del caso E (`engine: julia`, HTML y PDF), Excel (XLSX.jl/openpyxl), lotes y laboratorios; `temario.yml`: C6.8 pasa a «turnos y vibración» (decisión aprobada); referencia Harris 1978 verificada en Crossref | Ejecutado: 23 aserciones Julia y 8 pruebas Python (cifras idénticas en ambos lenguajes); informe renderizado a HTML y PDF con Quarto 1.10.19. **No probado**: Excel de Microsoft; diálogos con Claude |
| 23/10/2026 | Fase 5.1: **C7 redactada** (v0.2.0): mapa de mecanismos, skill `validar-tabla` (CSV/XLSX → informe Quarto), hooks (`validar-comando` en Zsh y PowerShell, `comprobar-calidad`), subagente `revisor-datos`, servidor MCP local de solo lectura; 6 fuentes | Ejecutado fuera de Claude Code: 14 comprobaciones de hooks, 6 pruebas pytest de la skill, cliente del SDK `mcp` 2.3.0 contra el servidor. **No ejecutado**: nada dentro de una sesión de Claude Code, `claude mcp add` |
| 23/10/2026 | Fase 5.2: **C8 redactada** (v0.2.0): modo no interactivo con límites, subagentes/worktrees/equipos, Actions, sandbox, evaluación de GSD (no verificado en su repositorio) | `ejecutar_tarea.sh` y `.ps1` probados con un `claude` falso: 15 comprobaciones Zsh + PowerShell 7 en macOS; YAML y plist solo sintácticos. **No ejecutado**: llamadas reales, Actions, Docker, launchctl |
| 23/10/2026 | Fase 5.3: **C9 redactada** (v0.2.0): API, errores, coste, salida estructurada, evaluación, proyecto integrador (informe Quarto con IA opcional) | SDK `anthropic` 2.2.0 sobre transporte simulado: 26 pruebas pytest + 4 aserciones Julia (puente). **Ninguna llamada real**. Reglas de la API desde la skill `claude-api` (fuente secundaria) |
| 23/10/2026 | Modelo didáctico, niveles y etiquetas de ejecución ([MODELO.md](MODELO.md)) | Revisado manualmente |
| 23/10/2026 | Dependencias de la fase 2: Julia (DataFrames 1.8.2, CSV 1.1.0, XLSX 0.13.2, CairoMakie 0.15.16) y Python (`pandas`, `openpyxl`, `matplotlib`; pytest 9.1.1) | `julia ok`; `python ok`; `pytest 9.1.1` |

## Pendiente inmediato (Fase 2)
1. ~~Indicador de versión~~ (hecho).
2. ~~auditar_claude.jl~~ (hecho); falta la hoja de consulta generada desde `comandos.yml`.
3. ~~Diseño responsive y portada~~ (hecho).
4. Componentes (ciclo del agente, explorador de terminal, visualizador Git, jerarquía de CLAUDE.md…): **aplazados**; cada uno se crea con su unidad (C2, C3, C4, C7), con alternativa textual y prueba Deno.
5. ~~Dependencias Julia y Python~~ (instaladas el 23/10/2026). Datos sintéticos A–E hechos.
6. ~~Playwright y enlaces~~ (hechos); falta probar la interacción de las simulaciones de C0.

## Pruebas ejecutadas (última vez)
| Prueba | Resultado | Fecha |
|---|---|---|
| `generar_estructura.jl --comprobar` | Verificado (64/64) | 23/10/2026 |
| `generar_bibliografia.jl --comprobar` | Verificado (30 entradas) | 23/10/2026 |
| Deno `recursos/js/` | Verificado (43/43) | 23/10/2026 |
| `quarto render` del sitio completo | Verificado (sin errores; control de `docs/` en verde) | 23/10/2026 |
| `using DataFrames, CSV, XLSX, CairoMakie` | Verificado (`julia ok`) | 23/10/2026 |
| `import pandas, openpyxl, matplotlib` y `pytest --version` | Verificado (`python ok`, pytest 9.1.1) | 23/10/2026 |
| Playwright 5 anchuras, vía C (Chromium headless) | Verificado (55/55; Safari no probado) | 23/10/2026 |
| Interacción de las simulaciones OJS de C0 | Verificado (2/2, Chromium) | 23/10/2026 |

## Bloqueos y acciones del responsable
- Dependencias Julia y Python: instaladas y comprobadas el 23/10/2026. `Project.toml`, `Manifest.toml`, `pyproject.toml` y `uv.lock` quedan modificados, sin commit.
- Playwright y Chromium: descarga con confirmación (Fase 2).
- FigureLabs: el responsable añadirá el dominio de descarga a `.claude/settings.local.json`.
- Publicación: al cerrar cada fase, `main` local queda adelantado por avance rápido; el responsable ejecuta `git push` (el entorno aislado no llega a GitHub).

## Problemas conocidos
- Fuera de la vía C: las 58 páginas M/J/L/R con `other-links: href: slides.qmd` enlazan a un fichero que no existe en `_site/` (debería ser `slides.html`). Sin tocar: es decisión del responsable. `generar_estructura.jl` (línea 216) sigue generando `slides.qmd` en los esqueletos nuevos.

## Notas de entorno
- uv necesita `dangerouslyDisableSandbox` (caché `~/.cache/uv` fuera del sandbox). Playwright de pip espera Chromium 1248; se usa el headless shell ya en caché (`PLAYWRIGHT_CHROMIUM` para otra ruta).
- El servidor de pruebas es flaky con JS de Quarto: la prueba recarga una vez antes de fallar.
- `pwsh` 7.6.8 en macOS permite verificar PowerShell 7 pero no Windows PowerShell 5.1 ni Windows.
- Crear la carpeta `datos/` exigió salir del sandbox (bloquea el directorio padre de los datos protegidos); los ficheros sintéticos se escriben ya dentro del sandbox.
- `_site/` contiene ficheros duplicados con sufijo « 2» (síntoma de sincronización de Escritorio con iCloud, que choca con la decisión de no sincronizar el repositorio). Son residuos ignorados por Git; conviene mover el repositorio fuera de Escritorio.
- Código en línea largo desbordaba en móvil: corregido con `white-space: pre-wrap` en `styles.css`.
- Quarto avisa de «fenced div» si falta una línea en blanco antes de `::: {.solucion}`/`.opciones` o antes de un cierre `:::` tras un párrafo: dejar siempre línea en blanco.
- Quarto con `engine: julia` encuentra los paquetes solo si el `.qmd` está bajo un árbol con `Project.toml`; en una carpeta aislada falla («Package CairoMakie not found»). Ningún `.qmd` de las vías M/J/L usa aún `engine: julia`, así que no existe `_freeze/`; los informes de ejemplo están en carpetas `_ejemplo` (excluidas del render del sitio).
