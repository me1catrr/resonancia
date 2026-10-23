# Equivalente en PowerShell de ejecutar_tarea.sh: tarea no interactiva de Claude Code con límites, registro y reintentos.
# Uso: ./ejecutar_tarea.ps1 -Prompt "texto" [-Carpeta ruta]
# Variables de entorno: CLAUDE_BIN, HERRAMIENTAS, MAX_TURNOS, MAX_COSTE_USD, REINTENTOS, ESPERA_S, LIMITE_S, REGISTRO
# Códigos de salida: 0 correcto · 1 uso incorrecto · 3 otra ejecución en curso · 4 agotados los intentos · 5 sin respuesta válida
param([string]$Prompt, [string]$Carpeta = (Get-Location).Path)
$ErrorActionPreference = 'Stop'   # un error no esperado detiene el script con código distinto de 0
function Get-Var($n, $def) { $v = [Environment]::GetEnvironmentVariable($n); if ($v) { $v } else { $def } }
if (-not $Prompt) { [Console]::Error.WriteLine('Uso: ejecutar_tarea.ps1 -Prompt "texto" [-Carpeta ruta]'); exit 1 }
$claude = Get-Var 'CLAUDE_BIN' 'claude'
$herr = Get-Var 'HERRAMIENTAS' 'Read,Grep,Glob'
$turnos = Get-Var 'MAX_TURNOS' '8'
$coste = Get-Var 'MAX_COSTE_USD' '0.50'
$reintentos = [int](Get-Var 'REINTENTOS' '2')
$espera = [int](Get-Var 'ESPERA_S' '5')
$limite = [int](Get-Var 'LIMITE_S' '300')
$registro = Get-Var 'REGISTRO' (Join-Path (Get-Location).Path 'registro-tarea.log')
function Anota($m) { Add-Content -Path $registro -Value ('{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m) }

# Bloqueo: un fichero creado con CreateNew falla si ya existe (atómico).
$hash = [BitConverter]::ToString([Security.Cryptography.SHA1]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($Carpeta))).Replace('-', '').Substring(0, 12)
$cerrojo = Join-Path ([IO.Path]::GetTempPath()) "ejecutar-tarea.$hash.lock"
try { $fs = [IO.File]::Open($cerrojo, 'CreateNew') ; $fs.Close() } catch { Anota "OMITIDA otra ejecución en curso ($cerrojo)"; exit 3 }

try {
    for ($i = 1; $i -le $reintentos; $i++) {
        Anota "INICIO intento $i/$reintentos carpeta=$Carpeta"
        $args_ = @('--bare', '-p', $Prompt, '--permission-mode', 'dontAsk', '--allowedTools', $herr,
                   '--max-turns', $turnos, '--max-budget-usd', $coste, '--output-format', 'json')
        $psi = [Diagnostics.ProcessStartInfo]::new($claude)
        foreach ($a in $args_) { $psi.ArgumentList.Add($a) }
        $psi.WorkingDirectory = $Carpeta; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
        $p = [Diagnostics.Process]::Start($psi)
        $out = $p.StandardOutput.ReadToEndAsync(); $err = $p.StandardError.ReadToEndAsync()
        if (-not $p.WaitForExit($limite * 1000)) {
            $p.Kill($true); Anota "FALLO intento ${i}: superado el límite de ${limite}s (proceso terminado)"
        } elseif ($p.ExitCode -eq 0) {
            $json = $out.Result | ConvertFrom-Json
            if (-not $json.result) { Anota 'FALLO respuesta sin campo result'; exit 5 }
            Anota ("FIN correcto coste_usd={0}" -f $(if ($null -ne $json.total_cost_usd) { $json.total_cost_usd } else { 'desconocido' }))
            Write-Output $json.result; exit 0
        } else {
            Anota "FALLO intento ${i}: código $($p.ExitCode)"
        }
        if ($i -lt $reintentos) { Anota "ESPERA ${espera}s antes de reintentar"; Start-Sleep -Seconds $espera; $espera *= 2 }
    }
    Anota "ABANDONO tras $reintentos intentos"; exit 4
} finally { Remove-Item $cerrojo -ErrorAction SilentlyContinue }
