#!/bin/zsh
# Ejecuta el análisis y deja un registro. Uso: scripts/ejecutar.zsh [fichero.csv]
# Códigos de salida: 0 correcto; 2 entrada ausente; 3 datos no válidos; 4 Python no disponible.
set -u                                  # error si se usa una variable sin definir
raiz=${0:A:h:h}                         # carpeta del proyecto (padre de scripts/)
entrada=${1:-$raiz/datos/aceleracion.csv}
salida=$raiz/resultados
registro=$salida/registro.log
mkdir -p "$salida"

anota() { print -r -- "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$registro"; }

if [[ ! -f $entrada ]]; then
  anota "ERROR entrada ausente: $entrada"
  print -u2 "No existe $entrada"
  exit 2
fi
if ! command -v python3 >/dev/null 2>&1; then
  anota "ERROR python3 no encontrado"
  exit 4
fi

anota "INICIO $entrada"
python3 "$raiz/scripts/analiza.py" "$entrada" "$salida"
codigo=$?
if (( codigo != 0 )); then
  anota "FALLO código $codigo"
  exit $codigo
fi
if command -v quarto >/dev/null 2>&1; then
  quarto render "$salida/informe.md" --to html >/dev/null 2>&1 && anota "Informe HTML generado" || anota "AVISO quarto render falló"
else
  anota "AVISO quarto no instalado: solo informe.md"
fi
anota "FIN correcto sha256=$(shasum -a 256 "$salida/resumen.csv" | cut -d' ' -f1)"
