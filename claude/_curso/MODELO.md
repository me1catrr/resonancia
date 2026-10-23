# Modelo didáctico de la vía C

Cómo se cumplen los 17 puntos del encargo dentro de la plantilla fija de seis secciones de
`CLAUDE.md`, sin que todas las unidades tengan la misma estructura visual. Cada unidad adapta los
recursos a su contenido: una unidad conceptual (C0, C1) usa más historia y simulaciones; una
técnica (C3, C4) usa más prácticas reproducibles y referencias de comandos.

## Correspondencia con la plantilla

| # | Punto del encargo | Dónde va en la unidad | Recurso habitual |
|---|---|---|---|
| 1 | Introducción y contexto histórico | Inicio de «Teoría breve» o en cada tema | Cuadro `.historia` con fuente y fecha; línea temporal |
| 2 | Objetivos de aprendizaje | 1 · Objetivos y prerrequisitos | Lista «Al terminar la unidad sabrás…» |
| 3 | Prerrequisitos | 1 · Objetivos y prerrequisitos | Enlaces a unidades; `requiere` en la cabecera |
| 4 | Conceptos fundamentales | 2 · Teoría breve | Cajas `{#def-…}`, tablas comparativas |
| 5 | Explicación técnica rigurosa | 2 · Teoría breve | Texto propio con citas y enlaces a la documentación |
| 6 | Ejemplos sencillos | 2 · Teoría breve | `{#exm-…}`, simulaciones OJS |
| 7 | Ejemplos profesionales | 3 · Práctica guiada | Casos A–E con datos sintéticos |
| 8 | Código ejecutable | 3 · Práctica guiada | Pestañas Julia/Python; versión probada en `python/` y `julia/` |
| 9 | Resultados esperados | 3 · Práctica guiada | Salida esperada junto a cada orden |
| 10 | Ejercicios guiados | 2 · Teoría breve (intercalados) | `.ejercicio` tras cada tema |
| 11 | Ejercicios autónomos | 5 · Ejercicios | Enunciado y solución plegada, separados |
| 12 | Tests o criterios de comprobación | 3 y 4 · *Verifica* | pytest, `Test` de Julia, rúbricas |
| 13 | Errores frecuentes | Donde aparecen | `.callout-warning` |
| 14 | Buenas prácticas | Donde aparecen | `.callout-tip .idea-clave` |
| 15 | Resumen de conocimientos | 6 · «La doy por superada si…» | Lista verificable |
| 16 | Preguntas de autoevaluación | 2 (intercalados) y 6 | Ejercicios `vf`, `opcion`, `numerico` |
| 17 | Fuentes y lecturas recomendadas | Al margen y al final | Citas de `bibliografia.bib`; enlaces con fecha |

## Niveles de dificultad

| Nivel | Para quién | Qué se le exige | Unidades |
|---|---|---|---|
| **Básico** | Sin experiencia previa en terminal ni programación | Seguir instrucciones, entender conceptos, verificar resultados | C0, C1, C2 |
| **Intermedio** | Usa la terminal y Git con soltura | Trabajar con Claude Code en proyectos reales, escribir pruebas | C3, C4, C5, C6 |
| **Avanzado** | Domina el flujo intermedio | Personalizar, automatizar, integrar la API | C7, C8, C9 |

- Cada unidad declara su nivel en la cabecera (`nivel: básico | intermedio | avanzado`).
- Un apartado más difícil que el resto de la unidad se marca con
  `::: {.callout-note .avanzado collapse="true" title="Avanzado: …"}`. Va plegado y nada posterior
  depende de él, de modo que el itinerario básico se completa sin leerlo.

## Etiquetas de ejecución

Toda práctica indica cómo se ejecuta, con una de estas etiquetas (clase `.ejec` en `styles.css`):

| Etiqueta | Marca | Significado |
|---|---|---|
| Local gratuita | `[Local gratuita]{.ejec .ejec-local}` | Solo el ordenador del alumno; sin cuenta ni red |
| Simulación | `[Simulación]{.ejec .ejec-sim}` | Se ejecuta en el navegador; no llama a ningún servicio |
| Requiere cuenta | `[Requiere cuenta]{.ejec .ejec-cuenta}` | Necesita una cuenta (Claude, GitHub…) pero no genera coste por sí misma |
| Puede generar coste | `[Puede generar coste]{.ejec .ejec-coste}` | Consume API o uso del plan; se indica cómo limitarlo y la alternativa local |

## Ficha de reproducibilidad (prácticas)

Toda práctica con código o con Claude Code lleva estos ocho puntos: objetivo, archivos necesarios,
versiones, instalación, comandos, resultado esperado, cómo comprobarlo y problemas frecuentes.

## Estilo

- Español de España; término inglés entre paréntesis la primera vez.
- Lenguaje técnico claro; sin tono comercial ni afirmaciones grandilocuentes.
- Los ejemplos con Claude son **ilustrativos** y se rotulan como tales: las respuestas reales varían.
- Ninguna afirmación técnica sin fuente o comprobación; lo no verificable se dice.

## Auditoría de C0 frente al modelo (23/10/2026)

Cubiertos: 1 (historia, ELIZA, línea temporal), 2, 3, 4, 5, 6 (dos simulaciones), 10 (20 ejercicios
intercalados), 11, 12 (rúbricas y criterios), 13 y 14 (C0.9), 15, 16, 17.
No aplican: 7–9 (unidad conceptual sin código; los casos de empresa empiezan en C5–C6).
Pendiente: probar las simulaciones en el navegador (Playwright, Fase 2).
