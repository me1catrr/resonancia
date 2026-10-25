# M02 — registro de continuidad

Documento de trabajo (no se publica: la carpeta empieza por «_»). El plan aprobado está en `~/.claude/plans/pasted-content-id-471d-prompt-idempotent-cookie.md`; aquí se anota lo hecho y lo que sigue.

## Decisiones del responsable (25-10-2026)
- Estructura: portada `index.qmd` + una página por apartado, sin nuevos `id` en `temario.yml` (como las subpáginas de R1).
- `temario.yml`: subtemas M2.1.1–M2.1.7 y `python: true` en M2 (aplicado).
- Dependencias: solo SciPy en Python (con `uv add` y confirmación); Julia sin paquetes nuevos.
- FigureLabs: hasta 12 imágenes, solo conceptuales, por lotes y con inventario previo.

## Hecho
- Fase 0 (auditoría y plan) aprobada.
- `temario.yml`: subtemas M2.1.1–M2.1.7 y `python: true`; `generar_estructura.jl` ordena los temas por todos los números de la clave. `--comprobar`: 64 unidades correctas.

## Siguiente (Fase 1)
1. `Resonancia.jl`: matrices estructuradas, normas, condicionamiento (con tests).
2. `recursos/js/matematicas.js` con tests (Deno).
3. Bibliografía de álgebra verificada.
4. Figuras TikZ y página `matrices/`.
5. Python (`uv add scipy`, `python/` con pytest) y `referencia/*.json`.
6. Portada de M02 y laboratorios L1, L2, L4, L5, L7.
