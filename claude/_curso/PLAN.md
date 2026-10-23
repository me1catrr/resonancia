# Plan: curso completo de Claude y Claude Code (vía C de Resonancia)

## Contexto
El responsable quiere convertir la vía C (`claude/`, unidades C0–C9) en un curso universitario-profesional completo, progresivo, interactivo y reproducible sobre Claude, Claude Code y programación asistida por IA, con casos de empresa (Excel, CSV, informes, mantenimiento, RR. HH., investigación), Julia + Python, Quarto como plataforma, fuentes oficiales verificadas, componentes interactivos, indicador de versión por página y diseño responsive. Encargo integral en cinco fases, con estado persistente para continuar entre sesiones.

**Estado actual** (comprobado): rama `main` sincronizada con `origin`; solo `_freeze/` sin seguimiento. C0 redactada (476 líneas, ejercicios, figuras); C1–C9 son esqueletos (~60 líneas). `Project.toml` solo tiene YAML; no hay `pyproject.toml`. Claude Code instalado: **2.1.304**. La documentación oficial es accesible en `https://code.claude.com/docs/en/<página>.md` (228 páginas: cli-reference, commands, interactive-mode, settings, permissions, memory, skills, hooks, sub-agents, agent-teams, worktrees, mcp, headless, github-actions, sandboxing, costs, devcontainer, changelog…).

**Infraestructura reutilizable**: cajas y estilos (`styles.css`), ejercicios intercalados (`scripts/ejercicios.lua` + `recursos/js/ejercicios.js`, 7 tipos, pruebas Deno), referencias al margen y al final (`scripts/referencias.lua`), R5 generada (`scripts/generar_bibliografia.jl`), TikZ (`scripts/compilar_tikz.jl`, `recursos/tikz/resonancia.sty`), OJS + módulos JS con pruebas, generador de estructura (`scripts/generar_estructura.jl --comprobar`), portadas TikZ, cuadros de historia y noticias.

## Decisiones del responsable
- **Dependencias**: Julia (DataFrames, CSV, XLSX, CairoMakie; Statistics/Test/Dates estándar) y Python con `uv` (pandas, openpyxl, matplotlib, pytest). Cada `Pkg.add`/`uv add` pedirá confirmación.
- **Pruebas visuales**: Playwright con `uv` (dependencia de desarrollo + Chromium); requiere red y aprobación.
- **FigureLabs**: máximo **6 generaciones** en todo el curso, solo ilustraciones conceptuales de alto valor. El responsable añadirá el dominio de descarga a `.claude/settings.local.json` (yo no puedo editarlo; le daré el fragmento). Antes de publicar, verificar sus condiciones de uso.
- **Indicador de versión**: solo vía C.
- **Typst** descartado: Quarto para web, HTML y PDF.
- No copiar material de Anthropic Academy ni de la documentación (AI Fluency es CC BY-NC-SA, incompatible con CC BY-SA): texto original, citas y enlaces.

## Fase 0 · Preparación (al aprobar el plan)
1. Crear la rama `docs/curso-claude-completo` (`git switch -c`). Nada de push/merge sin petición.
2. Estado persistente en `claude/_curso/` (el prefijo `_` evita que Quarto lo publique):
   - `PLAN.md` (este plan, ampliado por fases), `ESTADO.md` (hecho/pendiente/tests/commits/próximo paso), `DECISIONES.md`, `FUENTES.md` (tema · fuente · URL · fecha de consulta · estado · compatibilidad · observaciones) y `comandos.yml` (registro único de comandos, ver Fase 2).
   - `CLAUDE.md` solo recibe una línea que apunte a `claude/_curso/` (se mantiene conciso).
3. **Cambio de `temario.yml`** (queda aprobado con este plan): mismos identificadores y slugs (rutas públicas intactas); títulos y temas nuevos según el encargo; se eliminan C6.3–C6.6 (Typst); `python: true` en C5, C6 y C9; C9 sigue `opcional`. Títulos: C0 Fluidez en IA, fundamentos e historia · C1 Claude y el ecosistema Anthropic · C2 Preparación del entorno y terminal · C3 Git, GitHub y worktrees · C4 Claude Code: fundamentos y trabajo cotidiano · C5 Programación profesional asistida por IA · C6 Excel, datos, Quarto e informes · C7 Personalización: CLAUDE.md, skills, hooks y MCP · C8 Automatización, agentes y entornos avanzados · C9 API, investigación y proyectos integradores. Después: `julia --project=. scripts/generar_estructura.jl` y `--comprobar`.

## Fase 1 · Auditoría, investigación y consolidación de C0
- Auditar C0–C9, navegación, dependencias y patrones; registrar hallazgos en `ESTADO.md`.
- **Investigación documental**: leer en la documentación oficial (`.md`) las páginas clave y anotar en `FUENTES.md` y `comandos.yml` qué es estable, experimental, dependiente de plan o con habilitación previa (p. ej., agent teams). Comandos de la lista del encargo (`claude doctor`, `/cost`, `/review`…) se verifican uno a uno; si no existen o cambiaron, se corrige la referencia. Versión documentada: la del `changelog`; versión instalada: `claude --version`. Fuentes inaccesibles se registran como tales.
- **C0**: ampliar con historia de la IA (línea temporal original y verificada), IA simbólica/estadística, aprendizaje automático, redes y *transformers*, de asistentes a agentes, LLM vs. asistente vs. agente, evaluación, uso responsable en empresa y supervisión humana. Reutilizar lo existente (no reescribir sin motivo).
- Fijar el **modelo didáctico** (17 puntos, adaptado por unidad) y los niveles Básico/Intermedio/Avanzado.
- Entregable: C0 renderizable y verificada; commit.

## Fase 2 · Arquitectura docente, portada y navegación
- **Indicador de versión** (vía C): `claude/_versiones.yml` con versión global del curso y, por unidad, `version` (semver), `actualizado` (DD/MM/AAAA real), `claude_code_documentada`, `claude_code_instalada`, `estado` (verificado | pendiente de revisión | histórico) e `historial`. Filtro `scripts/version_unidad.lua` (patrón de `ejercicios.lua`) que inserta un rótulo discreto bajo el título de las páginas con `via: C`; falla de forma visible si falta la entrada.
- **Mantenibilidad**: `claude/_curso/comandos.yml` (por comando: tipo [sistema, git, opción CLI, comando interactivo, skill, terceros], unidades, ejemplo, fuente, versión y fecha de verificación) y `scripts/auditar_claude.jl` (`--comprobar`): compara con `claude --version` y `_versiones.yml` y lista unidades, comandos, ejemplos y figuras a revisar. La hoja de consulta rápida (HTML imprimible + `.md` descargable) se **genera** desde `comandos.yml`.
- **Diseño responsive**: `grid` en `_quarto.yml` (anchos de barra lateral, cuerpo y margen) y CSS: texto con longitud de línea cómoda; tablas, código, gráficas y simulaciones en `column-page`/`column-screen-inset`; clase `.dos-columnas` con CSS grid que pasa a una columna por debajo de 768 px; sin desplazamiento horizontal. (Es un ajuste compartido de todo el sitio: se justifica en `DECISIONES.md`.)
- **Portada de la vía C** (`claude/index.qmd`): itinerarios, estados, prerrequisitos, niveles y versión, alimentados por `temario.yml` y `_versiones.yml`.
- **Componentes interactivos** (`recursos/js/componentes/`, módulos ES sin dependencias externas, accesibles por teclado, con alternativa textual y pruebas Deno): línea temporal, ciclo del agente, explorador de terminal (sistema de ficheros simulado), visualizador Git (commits y ramas) y de worktrees, jerarquía de `CLAUDE.md`, ventana de contexto y memoria, comparador de prompts, ejecución de hooks, MCP, coordinación multiagente; análisis de datos con OJS.
- **Datos y código**: `pyproject.toml` (uv) y dependencias Julia; `datos/sinteticos/curso-claude/` con casos A–E generados con semilla fija por `scripts/datos/generar_casos.jl`, con ficha `.meta.toml` cada uno. Por unidad: `python/` (pytest) y `julia/` (con `test/`). Páginas que ejecutan Julia: `engine: julia` y `_freeze/` commiteado. Código Python de las pestañas: no se ejecuta en la web; su versión probada vive en `python/` (CLAUDE.md). Las funciones del curso son didácticas y se quedan en cada unidad (no en `Resonancia.jl`).
- **Pruebas web**: `pruebas/web/` con Playwright + pytest: anchuras 390/768/1280/1920/2560 px, desbordamiento horizontal, recursos rotos, foco y teclado en componentes; capturas en `_capturas/` (ignorado por Git). Comprobador de enlaces internos sobre `_site/`.

## Fase 3 · Fundamentos: C1–C4
- **C1** Anthropic, historia y familias de Claude (con fecha), interfaces (chat, Code, API…), conversación frente a agente, selección de modelos, planes y autenticación, datos, introducción al *prompting*, tareas tipo y relación con Anthropic Academy (enlaces).
- **C2** desde cero: sistemas y shells (macOS, Linux, Windows/WSL), rutas, PATH, variables, gestores de paquetes, entornos Python y Julia, VS Code, Quarto, Git, Claude Code y Docker, *checklist* y diagnóstico; práctica de instalación y verificación; comandos peligrosos explicados antes.
- **C3** a fondo: modelo de Git, staging, ramas, merge/rebase, conflictos, PR y revisión, tags/releases, Actions, recuperación de errores y una sección completa de **worktrees** (con Claude Code); visualizador interactivo; práctica de dos personas en ramas distintas.
- **C4**: arquitectura y bucle agéntico, instalación, permisos, Plan Mode, exploración, edición, tests, revisión, commits, sesiones, contexto y compactación, coste, diagnóstico; referencia **verificada** de comandos que distingue sistema / Git / opciones CLI / interactivos / skills / terceros, cada uno con qué hace, sintaxis, ejemplo, resultado, precauciones y fuente; hoja de consulta.

## Fase 4 · Aplicaciones profesionales: C5–C6
- **C5** ciclo explorar → planificar → implementar → probar → revisar → documentar → commit; especificaciones y criterios de aceptación, TDD, refactorización, depuración, revisión, errores, logs, tipado, seguridad, cuándo verificar a mano; Julia y Python alternados con pruebas.
- **C6** Excel/CSV de principio a fin (lectura/escritura, validación, ausentes, duplicados, formatos, agrupación, indicadores, estadística, gráficas, comparación de periodos), informes Quarto HTML/PDF (dependencias de PDF explicadas), lotes y automatización; laboratorios de los casos A–D (p. ej., «C6.03 · mantenimiento») con datos, código, comprobación y producto final.

## Fase 5 · Avanzado y cierre: C7–C9
- **C7** `CLAUDE.md` (jerarquía, ubicaciones, modularidad), **skills** (con una skill de ejemplo que valida un Excel de indicadores y genera un informe Quarto), **hooks** (ejemplo que valida ficheros modificados y lanza comprobaciones), **MCP** (arquitectura, tools/resources/prompts, seguridad, servidor local de solo lectura; cuándo un script es mejor).
- **C8** subagentes, agent teams y worktrees (sin presentarlos como equivalentes), orquestación, supervisión, coste, Docker/devcontainers, CI, modo no interactivo, credenciales; **GSD** como herramienta de terceros (verificar repositorio, instalación y comandos vigentes; no instalarlo ni usar opciones que omitan permisos); ejemplo multiagente sobre análisis de datos.
- **C9** API (autenticación, SDK, parámetros, tokens y coste, salidas estructuradas, documentos, errores, límites, evaluación, reproducibilidad), Python y Julia (interfaces soportadas); todo lo que cuesta dinero, **opcional** y con alternativa local gratuita; proyecto integrador **caso E**.
- Revisión final editorial, técnica, jurídica y pedagógica; `claude/_curso/INFORME.md` con lo implementado, lo comprobado y las limitaciones.

## Reglas transversales
- Cada unidad: portada TikZ, historia (con fuente y fecha), ejercicios intercalados, ejemplos sencillos y profesionales, errores frecuentes, buenas prácticas, autoevaluación, fuentes, diapositivas; niveles de dificultad marcados.
- Toda afirmación técnica verificada o marcada como hipótesis; nada inventado. Ejemplos con Claude: ilustrativos y marcados como tales. Etiquetas de ejecución: local gratuita / requiere cuenta / puede generar coste / simulación.
- Figuras: TikZ y SVG/HTML propios; FigureLabs como máximo 6 veces. Nada decorativo: título, pie, texto alternativo y finalidad.
- Commits pequeños en español en la rama de trabajo; `ESTADO.md` actualizado tras cada paso validado.
- Me detengo solo en: dependencias y descargas (te pedirán confirmación), dominio de FigureLabs, push/merge, credenciales o API de pago; el resto continúa.

## Verificación (cada fase)
- `quarto render` de la vía C y del sitio sin errores ni avisos nuevos; `scripts/no_publicar_docs.ts` en verde.
- `generar_estructura.jl --comprobar`, `compilar_tikz.jl --comprobar`, `generar_bibliografia.jl --comprobar`, `auditar_claude.jl --comprobar`.
- Pruebas: Deno (`recursos/js/`), pytest (`python/`, `pruebas/web/`), Julia (`test/` de cada unidad).
- Playwright a 5 anchuras, sin desbordamientos ni recursos rotos; enlaces internos válidos.
- Cada resultado se informa como **Verificado / Revisado manualmente / Pendiente / No verificable en el entorno**.
