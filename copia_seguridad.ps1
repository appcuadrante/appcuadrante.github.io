# Copia de seguridad del proyecto App Cuadrante (código, SQL, documentación, Excel, iconos…)
# Crea un .zip con la fecha en el Google Drive de la cuenta del proyecto («Mi unidad\Copias AppCuadrante», con
# Google Drive para ordenador) y guarda las 15 últimas. Contiene datos personales (Excel del cuadrante): nunca en una
# nube personal. Si no encuentra el Drive del proyecto, no hace la copia y avisa.
# Uso: doble clic en Copia_Seguridad.bat (en la carpeta del proyecto).
$ErrorActionPreference = "Stop"
$raiz = Split-Path $PSScriptRoot -Parent

# Google Drive para ordenador monta «Mi unidad» (o «My Drive») en una letra de unidad, normalmente G:
$drive = Get-PSDrive -PSProvider FileSystem | ForEach-Object { foreach($n in "Mi unidad", "My Drive"){ Join-Path $_.Root $n } } |
         Where-Object { Test-Path $_ } | Select-Object -First 1
if(-not $drive){
  Write-Host ""
  Write-Host "  NO SE HA HECHO LA COPIA" -ForegroundColor Red
  Write-Host "  No encuentro el Google Drive del proyecto (Google Drive para ordenador, con appcuadrante.turnos@gmail.com)."
  Write-Host "  Ábrelo, espera a que aparezca «Mi unidad» en el Explorador y vuelve a intentarlo."
  Write-Host ""
  exit 1
}
$destino = Join-Path $drive "Copias AppCuadrante"
New-Item -ItemType Directory -Force $destino | Out-Null
$zip = Join-Path $destino ("AppCuadrante_" + (Get-Date -Format "yyyy-MM-dd_HHmm") + ".zip")

# Todo el proyecto menos la configuración local y las notas de trabajo (.claude)
$elementos = Get-ChildItem $raiz -Force | Where-Object { $_.Name -ne ".claude" }
Compress-Archive -Path $elementos.FullName -DestinationPath $zip -CompressionLevel Optimal -Force

# Comprobación: el zip se puede abrir y tiene el archivo principal de la app
Add-Type -AssemblyName System.IO.Compression.FileSystem
$z = [IO.Compression.ZipFile]::OpenRead($zip)
$n = $z.Entries.Count; $ok = [bool]($z.Entries | Where-Object FullName -eq "app-cuadrante-conectado.html"); $z.Dispose()
if (-not $ok) { throw "La copia no contiene app-cuadrante-conectado.html" }

# Guardar solo las 15 copias más recientes
Get-ChildItem $destino -Filter "AppCuadrante_*.zip" | Sort-Object LastWriteTime -Descending | Select-Object -Skip 15 | Remove-Item -Force

Write-Host ""
Write-Host "  COPIA DE SEGURIDAD HECHA" -ForegroundColor Green
Write-Host ("  " + $zip)
Write-Host ("  {0} archivos · {1:N0} KB" -f $n, ((Get-Item $zip).Length / 1KB))
Write-Host ("  Copias guardadas: " + (Get-ChildItem $destino -Filter "AppCuadrante_*.zip").Count + " (se guardan las 15 últimas)")
Write-Host "  Está en el Google Drive del proyecto: se sube sola a la nube."
Write-Host ""
