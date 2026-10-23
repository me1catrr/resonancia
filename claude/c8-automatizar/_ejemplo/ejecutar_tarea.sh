#!/bin/zsh
# Ejecuta UNA tarea no interactiva de Claude Code con límites, registro, reintentos y bloqueo.
#
# Uso:  ejecutar_tarea.sh "prompt" [carpeta_de_trabajo]
# Variables (con valores por defecto prudentes):
#   CLAUDE_BIN       orden de Claude Code                        (claude)
#   HERRAMIENTAS     herramientas permitidas sin preguntar       (Read,Grep,Glob)
#   MAX_TURNOS       tope de turnos                              (8)
#   MAX_COSTE_USD    tope de gasto por ejecución                 (0.50)
#   REINTENTOS       intentos totales ante fallo                 (2)
#   ESPERA_S         pausa entre intentos, se duplica            (5)
#   LIMITE_S         tiempo máximo por intento, en segundos      (300)
#   REGISTRO         fichero de registro                         (./registro-tarea.log)
# Códigos de salida: 0 correcto · 1 uso incorrecto · 3 otra ejecución en curso · 4 agotados los intentos · 5 sin respuesta válida
set -u
prompt=${1:-}; carpeta=${2:-$PWD}
[[ -z $prompt ]] && { print -u2 "Uso: $0 \"prompt\" [carpeta]"; exit 1; }

CLAUDE_BIN=${CLAUDE_BIN:-claude}
HERRAMIENTAS=${HERRAMIENTAS:-Read,Grep,Glob}
MAX_TURNOS=${MAX_TURNOS:-8}
MAX_COSTE_USD=${MAX_COSTE_USD:-0.50}
REINTENTOS=${REINTENTOS:-2}
ESPERA_S=${ESPERA_S:-5}
LIMITE_S=${LIMITE_S:-300}
REGISTRO=${REGISTRO:-$PWD/registro-tarea.log}
cerrojo="${TMPDIR:-/tmp}/ejecutar-tarea.$(print -rn -- "$carpeta" | shasum | cut -c1-12).lock"

anota() { print -r -- "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$REGISTRO"; }

# Bloqueo: mkdir es atómico; si existe, hay otra ejecución en curso.
if ! mkdir "$cerrojo" 2>/dev/null; then anota "OMITIDA otra ejecución en curso ($cerrojo)"; exit 3; fi
trap 'rmdir "$cerrojo" 2>/dev/null' EXIT

salida=$(mktemp)
intento=1; espera=$ESPERA_S
while (( intento <= REINTENTOS )); do
  anota "INICIO intento $intento/$REINTENTOS carpeta=$carpeta"
  # Intento con tiempo máximo: el proceso va en segundo plano y un vigilante lo termina (SIGTERM) pasado el límite.
  ( cd "$carpeta" && "$CLAUDE_BIN" --bare -p "$prompt" \
        --permission-mode dontAsk --allowedTools "$HERRAMIENTAS" \
        --max-turns "$MAX_TURNOS" --max-budget-usd "$MAX_COSTE_USD" \
        --output-format json > "$salida" 2>>"$REGISTRO" ) &
  pid=$!
  ( sleep "$LIMITE_S"; kill -TERM "$pid" 2>/dev/null ) >/dev/null 2>&1 &
  vigilante=$!
  wait "$pid"; codigo=$?
  pkill -P "$vigilante" 2>/dev/null; kill "$vigilante" 2>/dev/null; wait "$vigilante" 2>/dev/null   # el vigilante y su `sleep`

  if (( codigo == 0 )); then
    resultado=$(jq -r '.result // empty' "$salida" 2>/dev/null)
    coste=$(jq -r '.total_cost_usd // empty' "$salida" 2>/dev/null)
    if [[ -z $resultado ]]; then anota "FALLO respuesta sin campo result"; rm -f "$salida"; exit 5; fi
    anota "FIN correcto coste_usd=${coste:-desconocido}"
    print -r -- "$resultado"
    rm -f "$salida"; exit 0
  fi
  if (( codigo == 143 )); then anota "FALLO intento $intento: superado el límite de ${LIMITE_S}s (terminado por SIGTERM)"
  else anota "FALLO intento $intento: código $codigo"; fi
  (( intento < REINTENTOS )) && { anota "ESPERA ${espera}s antes de reintentar"; sleep "$espera"; espera=$(( espera * 2 )); }
  (( intento++ ))
done
anota "ABANDONO tras $REINTENTOS intentos"
rm -f "$salida"; exit 4
