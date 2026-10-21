#!/usr/bin/env bash
# PreToolUse (Bash|PowerShell): segunda barrera para datos/privados/.
# Lee por stdin el JSON de la llamada y bloquea (exit 2) si menciona la carpeta.
entrada=$(cat)
if printf '%s' "$entrada" | grep -Eqi 'datos[/\\]+privados'; then
  echo "Bloqueado: el comando menciona datos/privados, que no se lee, lista ni toca (ver CLAUDE.md)." >&2
  exit 2
fi
exit 0
