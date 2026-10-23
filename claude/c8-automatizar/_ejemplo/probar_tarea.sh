#!/bin/zsh
# Prueba ejecutar_tarea.sh con un `claude` falso. No llama a ningún servicio ni gasta nada.
cd "${0:A:h}" || exit 1
tmp=$(mktemp -d); falla=0
export CLAUDE_BIN="$PWD/claude-falso.sh" ESPERA_S=1 TMPDIR="$tmp"
ok()  { print "OK   $1"; }
mal() { print "FALLA $1"; falla=1; }
corre() { REGISTRO="$tmp/reg.log" ./ejecutar_tarea.sh "$@"; }

: > $tmp/reg.log
out=$(FALSO_MODO=ok FALSO_ARGS=$tmp/args ./ejecutar_tarea.sh "resume" "$tmp" 2>/dev/null); cod=$?
REGISTRO=$tmp/reg.log
[[ $cod -eq 0 && $out == "Resumen de prueba" ]] && ok "éxito: código 0 y resultado" || mal "éxito ($cod, $out)"
for f in --bare --permission-mode\ dontAsk --allowedTools\ Read,Grep,Glob --max-turns\ 8 --max-budget-usd\ 0.50 --output-format\ json; do
  grep -q -- "$f" $tmp/args && ok "argumento presente: $f" || mal "falta argumento: $f"
done

export REGISTRO=$tmp/reg2.log
FALSO_MODO=falla REINTENTOS=3 ./ejecutar_tarea.sh "x" "$tmp" >/dev/null 2>&1; cod=$?
[[ $cod -eq 4 ]] && ok "fallo persistente: código 4" || mal "fallo persistente ($cod)"
[[ $(grep -c "^.* INICIO" $REGISTRO) -eq 3 ]] && ok "3 intentos registrados" || mal "intentos"
grep -q "ABANDONO" $REGISTRO && ok "abandono registrado" || mal "abandono"

export REGISTRO=$tmp/reg3.log; print 0 > $tmp/cont; 
out=$(FALSO_MODO=falla_una_vez FALSO_CONTADOR=$tmp/cont REINTENTOS=2 ./ejecutar_tarea.sh "x" "$tmp" 2>/dev/null); cod=$?
[[ $cod -eq 0 && $out == "ok tras reintento" ]] && ok "reintento con éxito" || mal "reintento ($cod, $out)"

export REGISTRO=$tmp/reg4.log
FALSO_MODO=sin_campo ./ejecutar_tarea.sh "x" "$tmp" >/dev/null 2>&1; cod=$?
[[ $cod -eq 5 ]] && ok "respuesta sin result: código 5" || mal "sin result ($cod)"

export REGISTRO=$tmp/reg5.log
inicio=$SECONDS; FALSO_MODO=cuelga LIMITE_S=2 REINTENTOS=1 ./ejecutar_tarea.sh "x" "$tmp" >/dev/null 2>&1; cod=$?; dur=$(( SECONDS - inicio ))
[[ $cod -eq 4 && $dur -lt 10 ]] && grep -q "límite de 2s" $REGISTRO && ok "límite de tiempo: terminado a los ${dur}s" || mal "límite ($cod, ${dur}s)"

export REGISTRO=$tmp/reg6.log
cerr="$tmp/ejecutar-tarea.$(print -rn -- "$tmp" | shasum | cut -c1-12).lock"; mkdir "$cerr"
FALSO_MODO=ok ./ejecutar_tarea.sh "x" "$tmp" >/dev/null 2>&1; cod=$?
[[ $cod -eq 3 ]] && grep -q "OMITIDA" $REGISTRO && ok "bloqueo: segunda ejecución omitida (código 3)" || mal "bloqueo ($cod)"
rmdir "$cerr"
./ejecutar_tarea.sh >/dev/null 2>&1; [[ $? -eq 1 ]] && ok "sin prompt: código 1" || mal "uso"
exit $falla
