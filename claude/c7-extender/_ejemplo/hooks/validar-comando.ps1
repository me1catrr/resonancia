# PreToolUse (Bash/PowerShell): equivalente en PowerShell de validar-comando.sh.
# Lee el JSON de stdin; exit 2 con el motivo por stderr bloquea la orden.
$entrada = [Console]::In.ReadToEnd() | ConvertFrom-Json
$orden = $entrada.tool_input.command
if (-not $orden) { exit 0 }

function Bloquea([string]$motivo) { [Console]::Error.WriteLine("Bloqueado por validar-comando.ps1: $motivo"); exit 2 }

if ($orden -match 'rm\s+-(rf|fr)|Remove-Item.*-Recurse.*-Force') { Bloquea 'borrado recursivo forzado' }
if ($orden -match 'git\s+push\s+(--force|-f)\b')                 { Bloquea 'push forzado' }
if ($orden -match 'git\s+reset\s+--hard')                        { Bloquea 'git reset --hard descarta trabajo sin confirmar' }
if ($orden -match '\bsudo\s')                                    { Bloquea 'sudo' }
if ($orden -match '(curl|wget|iwr|irm).*\|\s*(ba|z)?sh|\|\s*iex') { Bloquea 'descarga y ejecución directa' }
exit 0
