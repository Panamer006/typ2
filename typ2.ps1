function Apply-TYP2Pack {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)] [string]$ProjectPath,
    [Parameter(Mandatory=$true)] [string]$ZipPath,
    [string]$MetaEditorPath,                # например: "C:\Program Files\MetaTrader 5\metaeditor64.exe"
    [switch]$Compile,                       # если указать  попробует скомпилить
    [switch]$Git,                           # если указать  закоммитит и запушит
    [string]$GitMessage = "feat: apply TYP2 pack"
  )
  if (!(Test-Path $ProjectPath)) { throw "ProjectPath not found: $ProjectPath" }
  if (!(Test-Path $ZipPath))     { throw "ZipPath not found: $ZipPath" }

  # 1) Бэкап
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $backup = Join-Path $ProjectPath "backups\$stamp"
  New-Item $backup -ItemType Directory -Force | Out-Null
  $toBackup = @("Experts","Indicators","Files","docs")
  foreach ($d in $toBackup) {
    $src = Join-Path $ProjectPath $d
    if (Test-Path $src) { Copy-Item $src $backup -Recurse -Force -ErrorAction SilentlyContinue }
  }

  # 2) Применить пак
  Expand-Archive -Path $ZipPath -DestinationPath $ProjectPath -Force

  # 3) (опц.) Компиляция
  if ($Compile -and $MetaEditorPath) {
    $mq5 = Join-Path $ProjectPath "Experts\TYP2\TakeYourProfit2.mq5"
    if (Test-Path $mq5) {
      & $MetaEditorPath "/compile:$mq5" "/log:$($ProjectPath)\compile.log"
      Write-Host "Compiled. Log: $($ProjectPath)\compile.log"
    } else { Write-Warning "Файл не найден: $mq5  пропускаю компиляцию." }
  }

  # 4) (опц.) Git commit+push
  if ($Git) {
    Push-Location $ProjectPath
    git add -A
    git commit -m $GitMessage
    git push
    Pop-Location
  }

  Write-Host "Done. Backup: $backup"
}
