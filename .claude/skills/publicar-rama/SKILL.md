---
name: publicar-rama
description: Prepara y sube la rama actual de Resonancia — comprueba que _freeze/ y los SVG de TikZ están al día, pasa los tests de Resonancia.jl, agrupa los cambios en commits pequeños en español y hace push. Úsalo cuando el usuario pida «publicar», «subir la rama» o «hacer push».
disable-model-invocation: true
---

# Publicar la rama actual

Invocar este skill (`/publicar-rama`) **es la petición explícita de push** que exige el CLAUDE.md del
proyecto. No hace nada más allá de subir la rama: **no** ejecuta `quarto publish`, **no** crea PR ni
toca la configuración de GitHub salvo que el usuario lo pida aparte.

## Pasos

1. **Estado.** `git status --short`, `git branch --show-current` y `git log --oneline origin/main..HEAD`.
   Si la rama es `main`, para y pregunta: no se hace push directo a `main`.
2. **Comprobaciones previas** (en este orden; si una falla, para e informa):
   - `julia --project=Resonancia.jl -e 'using Pkg; Pkg.test()'` si hay cambios en `Resonancia.jl/`.
   - `julia --project=. scripts/compilar_tikz.jl --comprobar` si hay cambios en `fig/*.tex`.
   - Para cada `.qmd` modificado con `engine: julia`: debe existir y estar actualizado su
     `_freeze/<ruta>/`. Si no lo está, `quarto render <fichero>` y comprueba que no hay errores.
   - Si cambió `recursos/bibliografia.bib`: `julia --project=. scripts/generar_bibliografia.jl --comprobar`.
3. **Qué entra.** Revisa cada fichero modificado o nuevo y añade **solo lo que pertenece al trabajo de la rama**,
   por ruta (nunca `git add -A` ni `git add .`). Deja fuera lo que sea de otro trabajo (por ejemplo `videos/`
   si no es el tema de la rama) y dilo. Nunca entran `datos/privados/`, `docs/`, `.env`, ni carpetas
   `.claude/.cc-writes`. No uses `git add -f`.
4. **Commits pequeños**, mensaje en español en imperativo («Añade unidad M3»), una idea por commit:
   - el paquete (`Resonancia.jl/`, `Project.toml`, `Manifest.toml`) antes que las páginas que lo usan;
   - cada página con sus `fig/` y su `_freeze/` en el **mismo** commit.
   Cierra cada mensaje con las líneas de atribución que indique el sistema.
5. **Push.** `git push -u origin <rama>` (sin `--force`). Si falla por permisos o red, informa del error y para;
   no lo esquives con `git -C`, `sh -c` ni scripts.
6. **Informe corto:** commits creados (hash y título), qué se dejó fuera y por qué, y el resultado del push.
   Ofrece, sin hacerlo, abrir un PR hacia `main`.

## Reglas que no se saltan

- Nada de `push --force`, `reset --hard`, `rebase`, `clean` ni `checkout -- .`.
- Si el árbol tiene cambios que no sabes de quién son, pregunta antes de incluirlos.
- Los resultados de Julia se leen de `_freeze/`: una página con código Julia sin `_freeze/` actualizado
  hace fallar la publicación en GitHub Actions.
