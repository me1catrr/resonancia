#!/bin/bash
# Sustituto de `claude` para PROBAR el script sin llamar al servicio. Se elige el comportamiento con FALSO_MODO.
# Registra los argumentos recibidos en $FALSO_ARGS para poder comprobarlos.
[ -n "${FALSO_ARGS:-}" ] && printf '%s\n' "$*" >> "$FALSO_ARGS"
case "${FALSO_MODO:-ok}" in
  ok)        echo '{"type":"result","result":"Resumen de prueba","total_cost_usd":0.0123,"session_id":"falsa-1"}'; exit 0 ;;
  falla)     echo "error simulado" >&2; exit 1 ;;
  sin_campo) echo '{"type":"result"}'; exit 0 ;;
  cuelga)    sleep 30; exit 0 ;;
  falla_una_vez)
    n=$(cat "${FALSO_CONTADOR:?}" 2>/dev/null || echo 0); echo $((n+1)) > "$FALSO_CONTADOR"
    if [ "$n" -eq 0 ]; then echo "fallo transitorio" >&2; exit 1; fi
    echo '{"type":"result","result":"ok tras reintento","total_cost_usd":0.01}'; exit 0 ;;
esac
