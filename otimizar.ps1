param(
    [ValidateSet('bloat', 'privacidade', 'performance', 'servicos')]
    [string]$Modo = 'bloat'
)

$ErrorActionPreference = 'Continue'
$log = Join-Path $PSScriptRoot 'limpador.log'

function Add-Log([string]$mensagem) {
    $agora = Get-Date
    $linha = '{0:dd/MM/yyyy} {1:HH:mm:ss} OTIMIZAR {2}' -f $agora, $agora, $mensagem
    Add-Content -LiteralPath $log -Value $linha -Encoding Ascii
}

function Reg-Add([string]$path, [string]$name, [string]$type, [string]$value) {
    & reg.exe add $path /v $name /t $type /d $value /f 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Test-PacoteProtegido([string]$nome) {
    if ([string]::IsNullOrWhiteSpace($nome)) { return $false }
    return ($nome -match '(?i)(Xbox|GamingServices|GamingApp|GameBar|PeopleExperienceHost|ShellExperienceHost|StartMenuExperienceHost|SearchUI|Windows\.Photos|MSPaint|Paint|ScreenSketch|HEIFImageExtension|VP9VideoExtensions|WebMediaExtensions|WebpImageExtension|WindowsStore|Store)')
}

function Invoke-Bloat {
    $padroes = @(
        '*YourPhone*', '*PhoneExperience*',
        '*ZuneMusic*', '*ZuneVideo*',
        '*MixedReality*',
        '*Solitaire*',
        '*BingWeather*', '*BingNews*', '*BingFinance*', '*BingSports*',
        'Microsoft.People',
        '*WindowsMaps*',
        '*WindowsFeedbackHub*',
        '*WindowsAlarms*',
        '*SkypeApp*',
        '*3DViewer*', '*Print3D*',
        '*GetHelp*', '*Getstarted*',
        '*Messaging*', '*OneConnect*',
        '*windowscommunicationsapps*',
        '*Microsoft.Wallet*',
        '*Microsoft.Whiteboard*',
        '*Microsoft.NetworkSpeedTest*',
        '*Microsoft.StorePurchaseApp*'
    )
    $removidos = 0
    $pulados = 0
    $falhas = 0

    foreach ($padrao in $padroes) {
        $pacotes = @(Get-AppxPackage -Name $padrao -ErrorAction SilentlyContinue)
        foreach ($pkg in $pacotes) {
            if (Test-PacoteProtegido $pkg.Name) {
                Write-Host ('Pulado (protegido): {0}' -f $pkg.Name)
                Add-Log ('bloat pulado protegido {0}' -f $pkg.Name)
                $pulados++
                continue
            }
            try {
                Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
                Write-Host ('Removido: {0}' -f $pkg.Name)
                Add-Log ('bloat removido {0}' -f $pkg.Name)
                $removidos++
            } catch {
                Write-Host ('Nao deu para remover: {0}' -f $pkg.Name)
                Add-Log ('bloat falhou {0}' -f $pkg.Name)
                $falhas++
            }
        }

        $prov = @()
        try {
            $prov = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop |
                Where-Object { $_.DisplayName -like $padrao })
        } catch {
            $prov = @()
        }
        foreach ($p in $prov) {
            if (Test-PacoteProtegido $p.DisplayName) {
                Write-Host ('Pulado provisionado (protegido): {0}' -f $p.DisplayName)
                $pulados++
                continue
            }
            try {
                Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -ErrorAction Stop | Out-Null
                Write-Host ('Removido da imagem: {0}' -f $p.DisplayName)
                Add-Log ('bloat provisionado {0}' -f $p.DisplayName)
                $removidos++
            } catch {
                Add-Log ('bloat provisionado falhou {0}' -f $p.DisplayName)
                $falhas++
            }
        }
    }

    Write-Host ''
    Write-Host ('Bloat: removidos={0} pulados={1} falhas={2}' -f $removidos, $pulados, $falhas)
    Add-Log ('bloat fim removidos={0} pulados={1} falhas={2}' -f $removidos, $pulados, $falhas)
    if ($falhas -gt 0) { return 1 }
    return 0
}

function Invoke-Privacidade {
    $falhas = 0
    $pares = @(
        @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowTelemetry'; Type = 'REG_DWORD'; Value = '0' },
        @{ Path = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection'; Name = 'AllowTelemetry'; Type = 'REG_DWORD'; Value = '0' },
        @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name = 'AllowCortana'; Type = 'REG_DWORD'; Value = '0' },
        @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name = 'DisableWebSearch'; Type = 'REG_DWORD'; Value = '1' },
        @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name = 'ConnectedSearchUseWeb'; Type = 'REG_DWORD'; Value = '0' },
        @{ Path = 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; Name = 'Enabled'; Type = 'REG_DWORD'; Value = '0' },
        @{ Path = 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy'; Name = 'TailoredExperiencesWithDiagnosticDataEnabled'; Type = 'REG_DWORD'; Value = '0' },
        @{ Path = 'HKCU\SOFTWARE\Microsoft\Siuf\Rules'; Name = 'NumberOfSIUFInPeriod'; Type = 'REG_DWORD'; Value = '0' },
        @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'DoNotShowFeedbackNotifications'; Type = 'REG_DWORD'; Value = '1' },
        @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'EnableActivityFeed'; Type = 'REG_DWORD'; Value = '0' },
        @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'PublishUserActivities'; Type = 'REG_DWORD'; Value = '0' },
        @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'UploadUserActivities'; Type = 'REG_DWORD'; Value = '0' },
        @{ Path = 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SilentInstalledAppsEnabled'; Type = 'REG_DWORD'; Value = '0' },
        @{ Path = 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SystemPaneSuggestionsEnabled'; Type = 'REG_DWORD'; Value = '0' },
        @{ Path = 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338388Enabled'; Type = 'REG_DWORD'; Value = '0' },
        @{ Path = 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338389Enabled'; Type = 'REG_DWORD'; Value = '0' },
        @{ Path = 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-353698Enabled'; Type = 'REG_DWORD'; Value = '0' }
    )

    foreach ($p in $pares) {
        if (Reg-Add $p.Path $p.Name $p.Type $p.Value) {
            Write-Host ('OK: {0}\{1}' -f $p.Path, $p.Name)
        } else {
            Write-Host ('Falhou: {0}\{1}' -f $p.Path, $p.Name)
            $falhas++
        }
    }

    Add-Log ('privacidade fim falhas={0}' -f $falhas)
    Write-Host ''
    Write-Host 'Privacidade aplicada. Telemetria, anuncios e Cortana reduzidos.'
    if ($falhas -gt 0) { return 1 }
    return 0
}

function Get-GuidPlano([string]$nome) {
    $linha = powercfg /list 2>$null | Select-String -Pattern ([regex]::Escape($nome)) | Select-Object -First 1
    if (-not $linha) { return $null }
    if ($linha.Line -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') {
        return $Matches[1]
    }
    return $null
}

function Set-ValorPlano([string]$guid, [string]$sub, [string]$setting, [string]$valor) {
    & powercfg.exe /setacvalueindex $guid $sub $setting $valor 2>$null | Out-Null
    & powercfg.exe /setdcvalueindex $guid $sub $setting $valor 2>$null | Out-Null
}

function Ensure-UltimatePlan {
    $nome = 'ChrisTitus - Ultimate Power Plan'
    $guid = Get-GuidPlano $nome
    if ($guid) {
        Write-Host ('Plano ja existe: {0}' -f $nome)
        return $guid
    }

    $alto = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
    if (-not (powercfg /list 2>$null | Select-String $alto)) {
        & powercfg.exe /restoredefaultschemes 2>$null | Out-Null
    }
    if (-not (powercfg /list 2>$null | Select-String $alto)) {
        Write-Host 'Nao achou o plano Alto Desempenho para duplicar.'
        return $null
    }

    $saida = & powercfg.exe /duplicatescheme $alto 2>&1 | Out-String
    if ($saida -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') {
        $guid = $Matches[1]
    } else {
        Write-Host 'Nao deu para duplicar o plano de energia.'
        return $null
    }

    & powercfg.exe /changename $guid $nome 'Ultimate Power Plan baseado no Chris Titus' 2>$null | Out-Null
    Write-Host ('Plano criado: {0}' -f $nome)
    return $guid
}

function Apply-UltimateSettings([string]$guid) {
    # Processador: sem idle states, minimo 100%, maximo 100%
    Set-ValorPlano $guid 'SUB_PROCESSOR' 'IDLEDISABLE' '1'
    Set-ValorPlano $guid 'SUB_PROCESSOR' 'PROCTHROTTLEMIN' '100'
    Set-ValorPlano $guid 'SUB_PROCESSOR' 'PROCTHROTTLEMAX' '100'
    Set-ValorPlano $guid '54533251-82be-4824-96c1-47b60b740d00' '4d2b0152-7d5c-498b-88e2-34345392a2c5' '1'

    # Disco: nunca desligar
    Set-ValorPlano $guid 'SUB_DISK' 'DISKIDLE' '0'

    # Suspender / hibernar: nunca
    Set-ValorPlano $guid 'SUB_SLEEP' 'STANDBYIDLE' '0'
    Set-ValorPlano $guid 'SUB_SLEEP' 'HIBERNATEIDLE' '0'
    Set-ValorPlano $guid 'SUB_SLEEP' 'HYBRIDSLEEP' '0'

    # USB selective suspend: desligado
    Set-ValorPlano $guid 'SUB_USB' 'USBSELECTIVESUSPEND' '0'

    # PCI Express Link State: desligado
    Set-ValorPlano $guid 'SUB_PCIEXPRESS' 'ASPM' '0'

    # Wi-Fi: desempenho maximo
    Set-ValorPlano $guid '19cbb8fa-5279-450e-b866-8245135f3cc7' '12bbebe6-58d6-4636-95bb-483d05467fac' '0'

    # Tela: nao desligar sozinha no AC (0 = nunca)
    & powercfg.exe /change monitor-timeout-ac 0 2>$null | Out-Null
    & powercfg.exe /change standby-timeout-ac 0 2>$null | Out-Null
    & powercfg.exe /change hibernate-timeout-ac 0 2>$null | Out-Null
    & powercfg.exe /change disk-timeout-ac 0 2>$null | Out-Null

    & powercfg.exe /setactive $guid 2>$null | Out-Null
}

function Invoke-Performance {
    $falhas = 0
    $pares = @(
        @{ Path = 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'; Name = 'VisualFXSetting'; Type = 'REG_DWORD'; Value = '2' },
        @{ Path = 'HKCU\Control Panel\Desktop\WindowMetrics'; Name = 'MinAnimate'; Type = 'REG_SZ'; Value = '0' },
        @{ Path = 'HKCU\System\GameConfigStore'; Name = 'GameDVR_Enabled'; Type = 'REG_DWORD'; Value = '0' },
        @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR'; Name = 'AllowGameDVR'; Type = 'REG_DWORD'; Value = '0' }
    )

    foreach ($p in $pares) {
        if (Reg-Add $p.Path $p.Name $p.Type $p.Value) {
            Write-Host ('OK: {0}\{1}' -f $p.Path, $p.Name)
        } else {
            Write-Host ('Falhou: {0}\{1}' -f $p.Path, $p.Name)
            $falhas++
        }
    }

    $guid = Ensure-UltimatePlan
    if ($guid) {
        Apply-UltimateSettings $guid
        Write-Host 'Plano ativo: ChrisTitus - Ultimate Power Plan'
        Write-Host 'Disco, USB suspend, PCI Express e processador ajustados para desempenho.'
        Add-Log ('performance ultimate guid={0}' -f $guid)
    } else {
        Write-Host 'Nao deu para preparar o plano Ultimate.'
        $falhas++
        Add-Log 'performance ultimate falhou'
    }

    Add-Log ('performance fim falhas={0}' -f $falhas)
    Write-Host ''
    Write-Host 'Performance aplicada. Game DVR e animacoes reduzidos. Xbox/Game Bar nao foram removidos.'
    if ($falhas -gt 0) { return 1 }
    return 0
}

function Invoke-Servicos {
    $servicos = @(
        'Fax',
        'MapsBroker',
        'RetailDemo',
        'wisvc',
        'WerSvc',
        'wercplsupport',
        'DiagTrack',
        'dmwappushservice',
        'RemoteRegistry',
        'TrkWks',
        'WMPNetworkSvc',
        'WSearch'
    )
    $bloqueio = @('XblAuthManager', 'XblGameSave', 'XboxNetApiSvc', 'XboxGipSvc', 'SysMain')
    $ok = 0
    $ausentes = 0
    $falhas = 0

    foreach ($nome in $servicos) {
        if ($bloqueio -contains $nome) {
            Write-Host ('Pulado (protegido): {0}' -f $nome)
            continue
        }
        if ($nome -match '(?i)^Xbox' -or $nome -match '(?i)^Xbl') {
            Write-Host ('Pulado (Xbox): {0}' -f $nome)
            continue
        }

        $svc = Get-Service -Name $nome -ErrorAction SilentlyContinue
        if (-not $svc) {
            Write-Host ('Ausente: {0}' -f $nome)
            $ausentes++
            continue
        }
        try {
            Stop-Service -Name $nome -Force -ErrorAction SilentlyContinue
            Set-Service -Name $nome -StartupType Disabled -ErrorAction Stop
            Write-Host ('Desativado: {0}' -f $nome)
            Add-Log ('servico desativado {0}' -f $nome)
            $ok++
        } catch {
            Write-Host ('Nao deu para desativar: {0}' -f $nome)
            Add-Log ('servico falhou {0}' -f $nome)
            $falhas++
        }
    }

    Write-Host ''
    Write-Host 'Aviso: WSearch desligado enfraquece a busca do menu Iniciar e do Explorer.'
    Write-Host ('Servicos: desativados={0} ausentes={1} falhas={2}' -f $ok, $ausentes, $falhas)
    Add-Log ('servicos fim ok={0} ausentes={1} falhas={2}' -f $ok, $ausentes, $falhas)
    if ($falhas -gt 0) { return 1 }
    return 0
}

$codigo = 0
switch ($Modo) {
    'bloat' { $codigo = Invoke-Bloat }
    'privacidade' { $codigo = Invoke-Privacidade }
    'performance' { $codigo = Invoke-Performance }
    'servicos' { $codigo = Invoke-Servicos }
}
exit $codigo
