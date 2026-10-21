param(
    [ValidateSet('listar', 'aplicar')]
    [string]$Modo = 'listar'
)

$ErrorActionPreference = 'Continue'
$log = Join-Path $PSScriptRoot 'limpador.log'

$bloqueio = @(
    'Common Files', 'WindowsApps', 'Windows Defender', 'Windows Mail',
    'Windows Media Player', 'Windows NT', 'Windows Photo Viewer',
    'Windows Portable Devices', 'Windows Security', 'WindowsPowerShell',
    'Windows Sidebar', 'Internet Explorer', 'Microsoft', 'Microsoft Office',
    'Microsoft Office 15', 'Microsoft Visual Studio', 'Microsoft SDKs',
    'Reference Assemblies', 'MSBuild', 'dotnet', 'IIS', 'IIS Express',
    'Package Cache', 'Packages', 'NVIDIA', 'NVIDIA Corporation', 'AMD',
    'Intel', 'Realtek', 'Windows', 'ModifiableWindowsApps', 'Microsoft.NET',
    'Google', 'Mozilla Firefox', 'BraveSoftware', 'Opera', 'Adobe',
    'Microsoft Edge', 'Edge'
)

function Add-Log([string]$mensagem) {
    $agora = Get-Date
    $linha = '{0:dd/MM/yyyy} {1:HH:mm:ss} RESTO {2}' -f $agora, $agora, $mensagem
    Add-Content -LiteralPath $log -Value $linha -Encoding Ascii
}

function Test-Protegido([string]$nome) {
    if ([string]::IsNullOrWhiteSpace($nome)) { return $false }
    $limpo = $nome.Trim()
    foreach ($prefixo in @('Microsoft', 'Windows')) {
        if ($limpo.StartsWith($prefixo, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    if ($limpo -match '(?i)(security update|hotfix|^update for|\bKB\d{6,}\b)') { return $true }
    return $false
}

function Get-ExeDeComando([string]$comando) {
    if ([string]::IsNullOrWhiteSpace($comando)) { return $null }
    $comando = [Environment]::ExpandEnvironmentVariables($comando.Trim())
    if ($comando -match '(?i)msiexec(\.exe)?') { return $null }
    if ($comando.StartsWith('"')) {
        if ($comando -match '^"([^"]+)"') { return $Matches[1] }
    }
    if ($comando -match '(?i)([A-Za-z]:\\.+?\.exe)') { return $Matches[1].Trim() }
    return $null
}

function Get-RaizesPermitidas {
    $lista = @()
    foreach ($candidato in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData)) {
        if ([string]::IsNullOrWhiteSpace($candidato)) { continue }
        if (-not (Test-Path -LiteralPath $candidato)) { continue }
        $cheia = [IO.Path]::GetFullPath($candidato).TrimEnd('\')
        if ($lista -notcontains $cheia) { $lista += $cheia }
    }
    return $lista
}

function Test-Reparse([string]$pasta) {
    $item = Get-Item -LiteralPath $pasta -Force -ErrorAction SilentlyContinue
    if ($null -eq $item) { return $true }
    return (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
}

function Test-PastaSegura([string]$pasta, $raizes) {
    if ([string]::IsNullOrWhiteSpace($pasta)) { return $false }
    if (-not (Test-Path -LiteralPath $pasta -PathType Container)) { return $false }
    try { $cheia = [IO.Path]::GetFullPath($pasta).TrimEnd('\') } catch { return $false }
    if (Test-Reparse $cheia) { return $false }
    foreach ($raiz in $raizes) {
        if ($cheia.Equals($raiz, [StringComparison]::OrdinalIgnoreCase)) { return $false }
        $prefixo = $raiz + '\'
        if (-not $cheia.StartsWith($prefixo, [StringComparison]::OrdinalIgnoreCase)) { continue }
        $resto = $cheia.Substring($prefixo.Length)
        $primeiro = $resto.Split('\')[0]
        if ([string]::IsNullOrWhiteSpace($primeiro)) { return $false }
        foreach ($nome in $script:bloqueio) {
            if ($primeiro.Equals($nome, [StringComparison]::OrdinalIgnoreCase)) { return $false }
        }
        return $true
    }
    return $false
}

function Test-AindaInstalado([string]$pasta) {
    try {
        $achou = @(Get-ChildItem -LiteralPath $pasta -Recurse -Force -File -ErrorAction Stop |
            Where-Object { $_.Extension -match '(?i)^\.(exe|sys)$' } |
            Select-Object -First 1)
    } catch {
        return $true
    }
    return ($achou.Count -gt 0)
}

function Get-Tamanho([string]$pasta) {
    $soma = (Get-ChildItem -LiteralPath $pasta -Recurse -Force -File -ErrorAction SilentlyContinue |
        Measure-Object -Property Length -Sum).Sum
    if ($null -eq $soma) { return [int64]0 }
    return [int64]$soma
}

function Format-Mb([int64]$bytes) {
    $mb = [math]::Floor($bytes / 1MB)
    $resto = [math]::Floor((($bytes % 1MB) * 10) / 1MB)
    return ('{0}.{1} MB' -f $mb, $resto)
}

function Get-Restos {
    $raizes = Get-RaizesPermitidas
    $itens = @()
    $vistos = @{}
    $chaves = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    foreach ($raiz in $chaves) {
        if (-not (Test-Path -LiteralPath $raiz)) { continue }
        foreach ($chave in @(Get-ChildItem -LiteralPath $raiz -ErrorAction SilentlyContinue)) {
            $prop = Get-ItemProperty -LiteralPath $chave.PSPath -ErrorAction SilentlyContinue
            if ($null -eq $prop) { continue }
            $nome = [string]$prop.DisplayName
            if ([string]::IsNullOrWhiteSpace($nome)) { continue }
            if (Test-Protegido $nome) { continue }
            if (Test-Protegido ([string]$prop.Publisher)) { continue }
            if (([string]$prop.SystemComponent) -eq '1') { continue }
            if (([string]$prop.WindowsInstaller) -eq '1') { continue }
            if (-not [string]::IsNullOrWhiteSpace([string]$prop.ParentKeyName)) { continue }

            $texto = (([string]$prop.UninstallString) + ' ' + ([string]$prop.QuietUninstallString))
            if ($texto -match '(?i)msiexec') { continue }

            $exe = Get-ExeDeComando ([string]$prop.UninstallString)
            if (-not $exe) { $exe = Get-ExeDeComando ([string]$prop.QuietUninstallString) }
            if ($exe -and (Test-Path -LiteralPath $exe)) { continue }
            if (-not $exe) { continue }

            $pasta = ''
            if (-not [string]::IsNullOrWhiteSpace([string]$prop.InstallLocation)) {
                $pasta = [Environment]::ExpandEnvironmentVariables(([string]$prop.InstallLocation).Trim().Trim('"')).TrimEnd('\')
            }
            if ([string]::IsNullOrWhiteSpace($pasta)) {
                $pasta = Split-Path -Parent $exe
            }

            $idChave = $chave.PSPath
            if (-not $vistos.ContainsKey($idChave)) {
                $apagarPasta = $false
                if (Test-PastaSegura $pasta $raizes) {
                    if (Test-AindaInstalado $pasta) { continue }
                    $apagarPasta = $true
                } elseif (Test-Path -LiteralPath $pasta -PathType Container) {
                    continue
                }

                $vistos[$idChave] = $true
                if ($apagarPasta) {
                    $marca = $pasta.ToLowerInvariant()
                    if (-not $vistos.ContainsKey($marca)) {
                        $vistos[$marca] = $true
                        $itens += [pscustomobject]@{
                            Tipo = 'pasta'
                            Nome = $nome
                            Alvo = $pasta
                            Extra = ''
                            Bytes = (Get-Tamanho $pasta)
                        }
                    }
                }
                $itens += [pscustomobject]@{
                    Tipo = 'chave'
                    Nome = $nome
                    Alvo = $chave.PSPath
                    Extra = $chave.Name
                    Bytes = [int64]0
                }
            }
        }
    }

    $execucoes = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
    )
    foreach ($caminho in $execucoes) {
        if (-not (Test-Path -LiteralPath $caminho)) { continue }
        $prop = Get-ItemProperty -LiteralPath $caminho -ErrorAction SilentlyContinue
        if ($null -eq $prop) { continue }
        foreach ($valor in @($prop.PSObject.Properties)) {
            if ($valor.Name -match '^(PSPath|PSParentPath|PSChildName|PSDrive|PSProvider)$') { continue }
            $comando = [string]$valor.Value
            $exe = Get-ExeDeComando $comando
            if (-not $exe) { continue }
            if (Test-Path -LiteralPath $exe) { continue }
            $marca = ($caminho + '|' + $valor.Name).ToLowerInvariant()
            if ($vistos.ContainsKey($marca)) { continue }
            $vistos[$marca] = $true
            $itens += [pscustomobject]@{
                Tipo = 'execucao'
                Nome = $valor.Name
                Alvo = $caminho
                Extra = $comando
                Bytes = [int64]0
            }
        }
    }

    $pastasInicio = @(
        [Environment]::GetFolderPath('Startup'),
        [Environment]::GetFolderPath('CommonStartup')
    )
    $shell = $null
    try { $shell = New-Object -ComObject WScript.Shell } catch { $shell = $null }
    if ($shell) {
        foreach ($inicio in $pastasInicio) {
            if ([string]::IsNullOrWhiteSpace($inicio)) { continue }
            if (-not (Test-Path -LiteralPath $inicio)) { continue }
            foreach ($lnk in @(Get-ChildItem -LiteralPath $inicio -Filter *.lnk -File -ErrorAction SilentlyContinue)) {
                $alvo = ''
                try { $alvo = [string]$shell.CreateShortcut($lnk.FullName).TargetPath } catch { $alvo = '' }
                if ([string]::IsNullOrWhiteSpace($alvo)) { continue }
                $alvo = [Environment]::ExpandEnvironmentVariables($alvo)
                if (Test-Path -LiteralPath $alvo) { continue }
                $marca = $lnk.FullName.ToLowerInvariant()
                if ($vistos.ContainsKey($marca)) { continue }
                $vistos[$marca] = $true
                $itens += [pscustomobject]@{
                    Tipo = 'atalho'
                    Nome = $lnk.Name
                    Alvo = $lnk.FullName
                    Extra = $alvo
                    Bytes = [int64]$lnk.Length
                }
            }
        }
    }

    return $itens
}

function Show-Restos($itens) {
    $bytes = [int64]0
    foreach ($item in $itens) {
        $bytes += [int64]$item.Bytes
        switch ($item.Tipo) {
            'pasta' {
                Write-Host ('PASTA   {0}  {1}' -f (Format-Mb ([int64]$item.Bytes)), $item.Nome)
                Write-Host ('        {0}' -f $item.Alvo)
            }
            'chave' {
                Write-Host ('ENTRADA {0}' -f $item.Nome)
                Write-Host ('        {0}' -f $item.Extra)
            }
            'execucao' {
                Write-Host ('INICIO  {0}' -f $item.Nome)
                Write-Host ('        {0}' -f $item.Extra)
            }
            'atalho' {
                Write-Host ('ATALHO  {0}' -f $item.Nome)
                Write-Host ('        {0}' -f $item.Extra)
            }
        }
    }
    Write-Host ''
    Write-Host ('Total: {0} itens. Pastas somam {1}.' -f @($itens).Count, (Format-Mb $bytes))
}

function Remove-Restos($itens) {
    $falhas = 0
    $pastaFalhou = @{}
    foreach ($item in $itens) {
        try {
            switch ($item.Tipo) {
                'pasta' {
                    $pai = Split-Path -Parent $item.Alvo
                    $temp = Join-Path $pai ('.resto-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
                    [IO.Directory]::Move($item.Alvo, $temp)
                    try {
                        Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction Stop
                    } catch {
                        try { [IO.Directory]::Move($temp, $item.Alvo) } catch { }
                        throw
                    }
                    Write-Host ('Apagada pasta: {0}' -f $item.Nome)
                    Add-Log ('apagada pasta {0}' -f $item.Alvo)
                }
                'chave' {
                    if ($pastaFalhou.ContainsKey($item.Nome)) { continue }
                    Remove-Item -LiteralPath $item.Alvo -Recurse -Force -ErrorAction Stop
                    Write-Host ('Removida entrada: {0}' -f $item.Nome)
                    Add-Log ('removida entrada {0}' -f $item.Extra)
                }
                'execucao' {
                    Remove-ItemProperty -LiteralPath $item.Alvo -Name $item.Nome -ErrorAction Stop
                    Write-Host ('Removido inicio: {0}' -f $item.Nome)
                    Add-Log ('removido inicio {0}' -f $item.Nome)
                }
                'atalho' {
                    Remove-Item -LiteralPath $item.Alvo -Force -ErrorAction Stop
                    Write-Host ('Apagado atalho: {0}' -f $item.Nome)
                    Add-Log ('apagado atalho {0}' -f $item.Alvo)
                }
            }
        } catch {
            $falhas += 1
            if ($item.Tipo -eq 'pasta') { $pastaFalhou[$item.Nome] = $true }
            Write-Host ('Nao deu para limpar: {0}' -f $item.Nome)
            Add-Log ('falhou {0}' -f $item.Nome)
        }
    }
    if ($falhas -gt 0) { exit 1 }
    exit 0
}

$restos = @(Get-Restos)
if ($restos.Count -eq 0) {
    Write-Host 'Nenhum resto encontrado.'
    exit 2
}

if ($Modo -eq 'listar') {
    Show-Restos $restos
    exit 0
}

Remove-Restos $restos
