# Ejecuta el análisis y deja un registro. Uso: ./scripts/ejecutar.ps1 [-Entrada fichero.csv]
# Códigos de salida: 0 correcto; 2 entrada ausente; 3 datos no válidos; 4 Python no disponible.
param([string]$Entrada)
Set-StrictMode -Version Latest          # error si se usa una variable sin definir
$raiz = Split-Path -Parent $PSScriptRoot
if (-not $Entrada) { $Entrada = Join-Path $raiz 'datos/aceleracion.csv' }
$salida = Join-Path $raiz 'resultados'
$registro = Join-Path $salida 'registro.log'
New-Item -ItemType Directory -Force -Path $salida | Out-Null

function Anota([string]$Mensaje) {
  Add-Content -Path $registro -Value ('{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Mensaje)
}

if (-not (Test-Path -LiteralPath $Entrada -PathType Leaf)) {
  Anota "ERROR entrada ausente: $Entrada"
  Write-Error "No existe $Entrada"
  exit 2
}
# En Windows el intérprete suele llamarse «python»; en macOS, «python3».
$python = Get-Command python3, python -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $python) { Anota 'ERROR Python no encontrado'; exit 4 }

Anota "INICIO $Entrada"
& $python.Source (Join-Path $raiz 'scripts/analiza.py') $Entrada $salida
if ($LASTEXITCODE -ne 0) { Anota "FALLO código $LASTEXITCODE"; exit $LASTEXITCODE }
if (Get-Command quarto -ErrorAction SilentlyContinue) {
  quarto render (Join-Path $salida 'informe.md') --to html *> $null
  if ($LASTEXITCODE -eq 0) { Anota 'Informe HTML generado' } else { Anota 'AVISO quarto render falló' }
} else { Anota 'AVISO quarto no instalado: solo informe.md' }
$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $salida 'resumen.csv')).Hash.ToLower()
Anota "FIN correcto sha256=$hash"
