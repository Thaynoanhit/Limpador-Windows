# Coloca o limpador para abrir escondido quando você entra no Windows.
$exe = Join-Path $PSScriptRoot "LimpadorWindows.exe"
$startup = [Environment]::GetFolderPath("Startup")
$atalho = Join-Path $startup "LimpadorWindows.lnk"

$shell = New-Object -ComObject WScript.Shell
$link = $shell.CreateShortcut($atalho)
if (Test-Path -LiteralPath $exe) {
    $link.TargetPath = $exe
    $link.Arguments = "--vigiar"
} else {
    $pythonw = Join-Path (Split-Path (Get-Command python).Source) "pythonw.exe"
    $script = Join-Path $PSScriptRoot "limpador.py"
    $link.TargetPath = $pythonw
    $link.Arguments = "`"$script`" --vigiar"
}
$link.WorkingDirectory = $PSScriptRoot
$link.WindowStyle = 7
$link.Description = "Organiza Downloads e limpa Temp e Prefetch em segundo plano"
$link.Save()

Write-Host "Atalho criado em: $atalho"
Write-Host "Na próxima entrada no Windows ele passa a vigiar a pasta Downloads."
