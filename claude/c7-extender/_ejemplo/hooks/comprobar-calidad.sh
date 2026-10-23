#!/bin/bash
# PostToolUse (Edit|Write): tras editar un .py, comprueba que compila y, si hay tests/ junto al
# fichero, que las pruebas pasan. Si falla, devuelve {"decision":"block","reason":...} para que
# Claude vea el problema y lo corrija. Se construye el JSON con jq (escapa comillas y saltos).
entrada=$(cat)
fichero=$(printf '%s' "$entrada" | jq -r '.tool_input.file_path // empty')
case "$fichero" in *.py) ;; *) exit 0 ;; esac
[ -f "$fichero" ] || exit 0

problema=""
salida=$(python3 -m py_compile "$fichero" 2>&1) || problema="Error de sintaxis en $fichero:
$salida"

if [ -z "$problema" ]; then
  raiz=$(dirname "$fichero")
  while [ "$raiz" != "/" ] && [ ! -d "$raiz/tests" ]; do raiz=$(dirname "$raiz"); done
  if [ -d "$raiz/tests" ]; then
    # Orden de pruebas configurable (por defecto, pytest del Python del sistema; con uv: "uv run --with pytest pytest").
    orden=${COMPROBAR_PYTEST:-python3 -m pytest}
    salida=$(cd "$raiz" && $orden tests -q -x 2>&1); codigo=$?
    # pytest: 0 = todo bien, 5 = no hay pruebas; cualquier otro código = problema real.
    if [ "$codigo" -ne 0 ] && [ "$codigo" -ne 5 ]; then
      problema="Las pruebas fallan tras editar $fichero (código $codigo):
$(printf '%s' "$salida" | tail -15)"
    fi
  fi
fi

if [ -n "$problema" ]; then
  jq -n --arg r "$problema" '{decision: "block", reason: $r}'
fi
exit 0
