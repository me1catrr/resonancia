#!/bin/bash
# PreToolUse (Bash): bloquea órdenes de riesgo ANTES de ejecutarlas.
# Entrada: JSON por stdin (campo tool_input.command). Salida: exit 2 + motivo por stderr = bloquea.
# Es una lista de patrones sencilla y revisable, no una defensa completa: los permisos
# y el sandbox siguen siendo la defensa de fondo.
entrada=$(cat)
orden=$(printf '%s' "$entrada" | jq -r '.tool_input.command // empty')
[ -z "$orden" ] && exit 0

bloquea() { echo "Bloqueado por validar-comando.sh: $1" >&2; exit 2; }

case "$orden" in
  *"rm -rf"*|*"rm -fr"*)            bloquea "borrado recursivo forzado (rm -rf); pide confirmación o usa una ruta concreta" ;;
  *"git push --force"*|*"git push -f"*) bloquea "push forzado: reescribe la historia remota" ;;
  *"git reset --hard"*)             bloquea "git reset --hard descarta trabajo sin confirmar" ;;
  *sudo\ *)                         bloquea "sudo: no se ejecutan órdenes con privilegios de administrador" ;;
esac
if printf '%s' "$orden" | grep -Eq '(curl|wget)[^|]*\|[[:space:]]*(ba|z)?sh'; then
  bloquea "descarga y ejecución directa (curl | sh): descarga el script, léelo y ejecútalo después"
fi
exit 0
