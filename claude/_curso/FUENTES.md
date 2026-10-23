# Registro de fuentes verificadas

Estados: **Verificado** (leído y contrastado), **Parcial** (leída solo una parte), **Pendiente**, **No accesible**.

- Claude Code **instalado**: `2.1.304` (`claude --version`, 23/10/2026).
- Claude Code **documentado**: `2.1.309`, del 22/10/2026 (cabecera del changelog, consultado el 23/10/2026).
- Otras herramientas: git 2.55.0 · quarto 1.10.19 · uv 0.12.23 · julia 1.12.3 · macOS 27.0.1.
- Método: las páginas oficiales se leen en su versión `.md` (`https://code.claude.com/docs/en/<página>.md`). Se anotan sintaxis y comportamiento; el texto del curso es propio (la documentación no se copia).

## Claude Code

| Tema | Fuente | URL | Consulta | Estado | Observaciones |
|---|---|---|---|---|---|
| Índice de la documentación | Anthropic | https://code.claude.com/docs/llms.txt | 23/10/2026 | Verificado | 228 páginas, todas en `.md` |
| Changelog | Anthropic | https://code.claude.com/docs/en/changelog.md | 23/10/2026 | Parcial | Leídas las 10 últimas versiones (2.1.300–2.1.309). 2.1.304 corrige que `claude --worktree` borrase el worktree sin preguntar con HEAD separado |
| Referencia de la CLI | Anthropic | https://code.claude.com/docs/en/cli-reference.md | 23/10/2026 | Verificado | Subcomandos y opciones; `claude --help` no lista todas |
| Comandos interactivos | Anthropic | https://code.claude.com/docs/en/commands.md | 23/10/2026 | Verificado | ~120 comandos; marca cuáles son skills incluidas |
| Modos de permisos | Anthropic | https://code.claude.com/docs/en/permission-modes.md | 23/10/2026 | Verificado | Seis modos; `auto` por defecto desde 2.1.283 |
| Ajustes y precedencia | Anthropic | https://code.claude.com/docs/en/settings.md | 23/10/2026 | Verificado | Gestionado > línea de órdenes > local > proyecto > usuario; las listas se combinan |
| Memoria (CLAUDE.md) | Anthropic | https://code.claude.com/docs/en/memory.md | 23/10/2026 | Verificado | Ubicaciones, `@ruta` (hasta 4 saltos), `.claude/rules/`, AGENTS.md (desde 2.1.277), memoria automática (200 líneas / 25 KB) |
| Hooks | Anthropic | https://code.claude.com/docs/en/hooks.md | 23/10/2026 | Parcial | Leído el primer 37 %: eventos, tipos, estructura, códigos de salida, ubicaciones |
| Skills | Anthropic | https://code.claude.com/docs/en/skills.md | 23/10/2026 | Parcial | Ubicaciones, campos de SKILL.md, invocación, límites; los comandos personalizados se han fusionado con las skills |
| MCP | Anthropic | https://code.claude.com/docs/en/mcp.md | 23/10/2026 | Parcial | Transportes (SSE obsoleto), ámbitos, `claude mcp`, límites de salida; pendiente: recursos y prompts |
| Subagentes | Anthropic | https://code.claude.com/docs/en/sub-agents.md | 23/10/2026 | Parcial | Integrados (Explore, Plan, general-purpose), ubicaciones y prioridad, campos; anidación hasta 3 niveles |
| Agent teams | Anthropic | https://code.claude.com/docs/en/agent-teams.md | 23/10/2026 | Verificado | **Experimental**, desactivado por defecto (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`); solo sesiones interactivas; comparación con subagentes |
| Worktrees | Anthropic | https://code.claude.com/docs/en/worktrees.md | 23/10/2026 | Verificado | `--worktree`/`-w`, `.claude/worktrees/`, limpieza, `isolation: worktree`, `.worktreeinclude` |
| Modo no interactivo | Anthropic | https://code.claude.com/docs/en/headless.md | 23/10/2026 | Verificado | `-p`, formatos de salida, `--bare`, `--permission-prompts none` |
| Puntos de control | Anthropic | https://code.claude.com/docs/en/checkpointing.md | 23/10/2026 | Verificado | `/rewind`, Esc Esc; no sigue cambios de Bash ni remotos; no sustituye a Git |
| Cómo funciona | Anthropic | https://code.claude.com/docs/en/how-claude-code-works.md | 23/10/2026 | Verificado | Bucle en tres fases: reunir contexto, actuar, verificar; cinco categorías de herramientas |
| Instalación avanzada | Anthropic | https://code.claude.com/docs/en/setup.md | 23/10/2026 | Verificado | Requisitos, instaladores, canales `latest`/`stable`, `claude doctor`, desinstalación; no usar `sudo npm install -g` |

## Claude, productos y Academy (C1)

| Tema | URL | Consulta | Estado | Observaciones |
|---|---|---|---|---|
| Modelos | https://platform.claude.com/docs/en/models/overview | 23/10/2026 | Verificado | Fable 5.1, Opus 5.5, Sonnet 5.5, Haiku 5.5; contexto 1M; precios y retirada |
| Planes | https://claude.com/pricing | 23/10/2026 | Parcial | Resumen automático; no se copian precios de planes (cambian) |
| Términos de consumidores | https://www.anthropic.com/news/updates-to-our-consumer-terms | 23/10/2026 | Parcial | 28/08/2025; entrenamiento con consentimiento; 30 días / 5 años |
| Proyectos, artefactos, archivos | support.claude.com (9517075, 9487310, 8241126) | 23/10/2026 | Parcial | Resúmenes automáticos |
| Guía de prompting | https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices | 23/10/2026 | Parcial | Secciones generales leídas; contexto largo: consulta al final |
| Claude Academy | https://academy.claude.com/ | 23/10/2026 | Parcial | Tres cursos; sin licencia declarada en la página (no se copia nada) |
| Reglamento 2026/1744 (ómnibus IA) | EUR-Lex | 23/10/2026 | No accesible | Datos de fuentes secundarias (Freshfields y otras) |

## Correcciones al encargo inicial (resultado de la verificación)

| Lo que decía el encargo | Lo que dice la documentación vigente | Tratamiento en el curso |
|---|---|---|
| `/cost` | Existe como **alias de `/usage`** | Se enseña `/usage` y se cita el alias |
| `/review` | Existe como **alias de la skill `/code-review`** | Se enseña `/code-review`, distinguiéndola de un comando interno |
| `/agents` | Desde 2.1.198 solo imprime un recordatorio; ya no es un asistente | Se crea el subagente pidiéndoselo a Claude o editando `.claude/agents/` |
| `/doctor` y `claude doctor` | Son cosas distintas: diagnóstico de solo lectura en la shell frente a skill que propone y aplica arreglos | Se presentan juntos y se contrastan |
| `/vim` (guías antiguas) | Eliminado en 2.1.92 | Se menciona solo como aviso |
| Comandos personalizados en `.claude/commands/` | Fusionados con las skills; siguen funcionando | Se enseñan las skills como forma recomendada |
| Agent teams | Experimental y desactivado por defecto | Se rotula como experimental; nunca equivalente a subagentes o worktrees |

## Pendientes

| Tema | Por qué | Fase |
|---|---|---|
| GSD (repositorio, instalación, comandos) | Herramienta de terceros; verificar en su repositorio oficial | 5 |
| Versión local de `gh` | El entorno aislado no lee su configuración | 2 |
| Historia de la IA (C0) | Fuentes primarias para cada hito de la línea temporal | 1 |
| Historia de Anthropic: fechas de Claude 2, 3, 4 y 5 | Solo se citan los tres anuncios ya verificados (2023, 2024, 2025) | 3 |
| Anthropic Academy / AI Fluency | Solo enlace y paráfrasis (CC BY-NC-SA, incompatible) | 1 y 3 |
