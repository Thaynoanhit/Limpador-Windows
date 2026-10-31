param(
    [ValidateSet('auditar', 'corrigir')]
    [string]$Modo = 'auditar'
)

$ErrorActionPreference = 'Continue'
$pasta = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$log = Join-Path $pasta 'limpador.log'
$script:Resultados = @()

function Add-Log([string]$mensagem) {
    $agora = Get-Date
    $linha = '{0:dd/MM/yyyy} {1:HH:mm:ss} AUDITOR {2}' -f $agora, $agora, $mensagem
    Add-Content -LiteralPath $log -Value $linha -Encoding Ascii
}

function Add-Resultado {
    param(
        [string]$Id,
        [string]$Checagem,
        [string]$Esperado,
        [string]$Encontrado,
        [string]$Status,
        [string]$Recomendacao
    )
    $script:Resultados += [PSCustomObject]@{
        ID           = $Id
        Checagem     = $Checagem
        Esperado     = $Esperado
        Encontrado   = $Encontrado
        Status       = $Status
        Recomendacao = if ($Status -eq 'APROVADO') { '-' } else { $Recomendacao }
    }
}

function Get-Status([bool]$ok) {
    if ($ok) { 'APROVADO' } else { 'REPROVADO' }
}

function Get-PoliticaValor([string[]]$Politica, [string]$Nome) {
    $linha = $Politica | Where-Object { $_ -match ("^{0}\s*=" -f [regex]::Escape($Nome)) } | Select-Object -First 1
    if (-not $linha) { return $null }
    $parte = ($linha -split '=', 2)[1]
    if ($null -eq $parte) { return $null }
    $texto = $parte.Trim()
    $num = 0
    if ([int]::TryParse($texto, [ref]$num)) { return $num }
    return $null
}

function Invoke-Checagens {
    $script:Resultados = @()
    $cfg = Join-Path $env:TEMP ("limpador-secpol-{0}.cfg" -f [guid]::NewGuid().ToString('N'))
    $Politica = @()

    try {
        & secedit.exe /export /cfg $cfg /areas SECURITYPOLICY 2>$null | Out-Null
        if (Test-Path -LiteralPath $cfg) {
            $Politica = @(Get-Content -LiteralPath $cfg -ErrorAction SilentlyContinue)
        }
    } catch {
        $Politica = @()
    }

    try {
        # FW
        try {
            foreach ($perfil in @(Get-NetFirewallProfile -ErrorAction Stop)) {
                $ativo = [bool]$perfil.Enabled
                Add-Resultado -Id ("FW-{0}" -f $perfil.Name) `
                    -Checagem ("Firewall ativo (perfil {0})" -f $perfil.Name) `
                    -Esperado 'True' -Encontrado ("{0}" -f $perfil.Enabled) `
                    -Status (Get-Status $ativo) `
                    -Recomendacao ("Set-NetFirewallProfile -Profile {0} -Enabled True" -f $perfil.Name)
            }
        } catch {
            Add-Resultado -Id 'FW' -Checagem 'Firewall' -Esperado 'True' `
                -Encontrado ("Erro: {0}" -f $_.Exception.Message) -Status 'ERRO' -Recomendacao 'Verificar manualmente'
        }

        # AV-01
        try {
            $defender = [bool](Get-MpComputerStatus -ErrorAction Stop).RealTimeProtectionEnabled
            Add-Resultado -Id 'AV-01' -Checagem 'Defender: protecao em tempo real' `
                -Esperado 'True' -Encontrado ("{0}" -f $defender) -Status (Get-Status $defender) `
                -Recomendacao 'Set-MpPreference -DisableRealtimeMonitoring $false'
        } catch {
            Add-Resultado -Id 'AV-01' -Checagem 'Defender: protecao em tempo real' -Esperado 'True' `
                -Encontrado 'Defender indisponivel (outro antivirus?)' -Status 'ERRO' -Recomendacao 'Verificar o antivirus instalado'
        }

        # AV-02
        try {
            $mp = Get-MpComputerStatus -ErrorAction Stop
            $atualizado = $mp.AntivirusSignatureLastUpdated
            if ($null -eq $atualizado) {
                Add-Resultado -Id 'AV-02' -Checagem 'Defender: definicoes recentes (<= 7 dias)' `
                    -Esperado '<= 7 dias' -Encontrado 'Data desconhecida' -Status 'ERRO' `
                    -Recomendacao 'Update-MpSignature'
            } else {
                $idade = [int]((Get-Date) - [datetime]$atualizado).TotalDays
                Add-Resultado -Id 'AV-02' -Checagem 'Defender: definicoes recentes (<= 7 dias)' `
                    -Esperado '<= 7 dias' -Encontrado ("{0} dia(s)" -f $idade) `
                    -Status (Get-Status ($idade -le 7)) `
                    -Recomendacao 'Update-MpSignature'
            }
        } catch {
            Add-Resultado -Id 'AV-02' -Checagem 'Defender: definicoes recentes (<= 7 dias)' -Esperado '<= 7 dias' `
                -Encontrado ("Erro: {0}" -f $_.Exception.Message) -Status 'ERRO' -Recomendacao 'Update-MpSignature'
        }

        # NET-01 SMBv1
        try {
            $smb1 = [bool](Get-SmbServerConfiguration -ErrorAction Stop).EnableSMB1Protocol
            Add-Resultado -Id 'NET-01' -Checagem 'SMBv1 desativado' `
                -Esperado 'False' -Encontrado ("{0}" -f $smb1) -Status (Get-Status (-not $smb1)) `
                -Recomendacao 'Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force'
        } catch {
            Add-Resultado -Id 'NET-01' -Checagem 'SMBv1 desativado' -Esperado 'False' `
                -Encontrado ("Erro: {0}" -f $_.Exception.Message) -Status 'ERRO' -Recomendacao 'Verificar manualmente'
        }

        # NET-02 RDP
        try {
            $rdp = Get-ItemPropertyValue 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -ErrorAction Stop
            Add-Resultado -Id 'NET-02' -Checagem 'RDP desativado' `
                -Esperado '1' -Encontrado ("{0}" -f $rdp) -Status (Get-Status ($rdp -eq 1)) `
                -Recomendacao 'Desativar em Configuracoes > Sistema > Area de Trabalho Remota'
        } catch {
            Add-Resultado -Id 'NET-02' -Checagem 'RDP desativado' -Esperado '1' `
                -Encontrado 'Chave nao encontrada' -Status 'ERRO' -Recomendacao 'Verificar manualmente'
        }

        # SYS-01 UAC
        try {
            $uac = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'EnableLUA' -ErrorAction Stop
            Add-Resultado -Id 'SYS-01' -Checagem 'UAC ativo' `
                -Esperado '1' -Encontrado ("{0}" -f $uac) -Status (Get-Status ($uac -eq 1)) `
                -Recomendacao 'Ativar o UAC (EnableLUA = 1) e reiniciar'
        } catch {
            Add-Resultado -Id 'SYS-01' -Checagem 'UAC ativo' -Esperado '1' `
                -Encontrado 'Chave nao encontrada' -Status 'ERRO' -Recomendacao 'Verificar manualmente'
        }

        # SYS-02 LSASS (1 = ativo, 2 = ativo com trava UEFI)
        try {
            $lsa = [int](Get-ItemPropertyValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'RunAsPPL' -ErrorAction Stop)
            $okLsa = ($lsa -eq 1 -or $lsa -eq 2)
            Add-Resultado -Id 'SYS-02' -Checagem 'Protecao do LSASS (RunAsPPL)' `
                -Esperado '1 ou 2' -Encontrado ("{0}" -f $lsa) -Status (Get-Status $okLsa) `
                -Recomendacao 'Criar RunAsPPL = 1 em HKLM:\SYSTEM\CurrentControlSet\Control\Lsa e reiniciar'
        } catch {
            Add-Resultado -Id 'SYS-02' -Checagem 'Protecao do LSASS (RunAsPPL)' `
                -Esperado '1 ou 2' -Encontrado 'Nao configurado' -Status 'REPROVADO' `
                -Recomendacao 'Criar RunAsPPL = 1 em HKLM:\SYSTEM\CurrentControlSet\Control\Lsa e reiniciar'
        }

        # SYS-03 Secure Boot
        try {
            $sb = Confirm-SecureBootUEFI -ErrorAction Stop
            Add-Resultado -Id 'SYS-03' -Checagem 'Secure Boot ativo' `
                -Esperado 'True' -Encontrado ("{0}" -f $sb) -Status (Get-Status ([bool]$sb)) `
                -Recomendacao 'Ativar Secure Boot no firmware UEFI'
        } catch {
            Add-Resultado -Id 'SYS-03' -Checagem 'Secure Boot ativo' -Esperado 'True' `
                -Encontrado 'Indisponivel (BIOS legado ou sem suporte)' -Status 'ERRO' `
                -Recomendacao 'Verificar firmware UEFI'
        }

        # SYS-04 Autologon
        try {
            $auto = '0'
            try {
                $auto = [string](Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name 'AutoAdminLogon' -ErrorAction Stop)
            } catch {
                $auto = '0'
            }
            $okAuto = ($auto -ne '1')
            Add-Resultado -Id 'SYS-04' -Checagem 'Autologon desligado' `
                -Esperado '0 / ausente' -Encontrado $auto -Status (Get-Status $okAuto) `
                -Recomendacao 'Definir AutoAdminLogon = 0 em Winlogon'
        } catch {
            Add-Resultado -Id 'SYS-04' -Checagem 'Autologon desligado' -Esperado '0 / ausente' `
                -Encontrado ("Erro: {0}" -f $_.Exception.Message) -Status 'ERRO' -Recomendacao 'Verificar manualmente'
        }

        # ACC-01 Guest
        try {
            $convidado = Get-LocalUser -ErrorAction Stop | Where-Object { $_.SID.Value -like '*-501' } | Select-Object -First 1
            if (-not $convidado) {
                Add-Resultado -Id 'ACC-01' -Checagem 'Conta Convidado desativada' -Esperado 'Desativada' `
                    -Encontrado 'Conta nao encontrada' -Status 'ERRO' -Recomendacao 'Verificar manualmente'
            } else {
                $desativada = -not $convidado.Enabled
                Add-Resultado -Id 'ACC-01' -Checagem 'Conta Convidado desativada' `
                    -Esperado 'Desativada' -Encontrado $(if ($desativada) { 'Desativada' } else { 'Ativa' }) `
                    -Status (Get-Status $desativada) `
                    -Recomendacao ("Disable-LocalUser -Name '{0}'" -f $convidado.Name)
            }
        } catch {
            Add-Resultado -Id 'ACC-01' -Checagem 'Conta Convidado desativada' -Esperado 'Desativada' `
                -Encontrado ("Erro: {0}" -f $_.Exception.Message) -Status 'ERRO' -Recomendacao 'Verificar manualmente'
        }

        # PWD-01 / PWD-02
        if ($Politica.Count -eq 0) {
            Add-Resultado -Id 'PWD-01' -Checagem 'Tamanho minimo de senha' -Esperado '>= 14' `
                -Encontrado 'Politica indisponivel (rode como admin)' -Status 'ERRO' `
                -Recomendacao 'net accounts /minpwlen:14'
            Add-Resultado -Id 'PWD-02' -Checagem 'Limite de tentativas antes do bloqueio' -Esperado '1 a 5' `
                -Encontrado 'Politica indisponivel (rode como admin)' -Status 'ERRO' `
                -Recomendacao 'net accounts /lockoutthreshold:5'
        } else {
            $tamanho = Get-PoliticaValor $Politica 'MinimumPasswordLength'
            if ($null -eq $tamanho) {
                Add-Resultado -Id 'PWD-01' -Checagem 'Tamanho minimo de senha' -Esperado '>= 14' `
                    -Encontrado 'Nao encontrado' -Status 'ERRO' -Recomendacao 'net accounts /minpwlen:14'
            } else {
                Add-Resultado -Id 'PWD-01' -Checagem 'Tamanho minimo de senha' `
                    -Esperado '>= 14' -Encontrado ("{0}" -f $tamanho) -Status (Get-Status ($tamanho -ge 14)) `
                    -Recomendacao 'net accounts /minpwlen:14'
            }

            $bloqueio = Get-PoliticaValor $Politica 'LockoutBadCount'
            if ($null -eq $bloqueio) {
                Add-Resultado -Id 'PWD-02' -Checagem 'Limite de tentativas antes do bloqueio' -Esperado '1 a 5' `
                    -Encontrado 'Nao encontrado' -Status 'ERRO' -Recomendacao 'net accounts /lockoutthreshold:5'
            } else {
                Add-Resultado -Id 'PWD-02' -Checagem 'Limite de tentativas antes do bloqueio' `
                    -Esperado '1 a 5' -Encontrado ("{0}" -f $bloqueio) `
                    -Status (Get-Status ($bloqueio -ge 1 -and $bloqueio -le 5)) `
                    -Recomendacao 'net accounts /lockoutthreshold:5'
            }
        }

        # DISK-01 BitLocker
        try {
            $vol = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
            $prot = [string]$vol.ProtectionStatus
            $okBit = ($prot -eq 'On')
            Add-Resultado -Id 'DISK-01' -Checagem ("BitLocker no disco {0}" -f $env:SystemDrive) `
                -Esperado 'On' -Encontrado $prot -Status (Get-Status $okBit) `
                -Recomendacao 'Ativar BitLocker em Configuracoes > Privacidade e seguranca'
        } catch {
            Add-Resultado -Id 'DISK-01' -Checagem ("BitLocker no disco {0}" -f $env:SystemDrive) `
                -Esperado 'On' -Encontrado 'Indisponivel nesta edicao/VM' -Status 'ERRO' `
                -Recomendacao 'Verificar se a edicao do Windows oferece BitLocker'
        }

        # UPD-01
        try {
            $svc = Get-Service -Name 'wuauserv' -ErrorAction Stop
            $okUpd = ($svc.StartType -ne 'Disabled')
            Add-Resultado -Id 'UPD-01' -Checagem 'Windows Update nao desativado' `
                -Esperado 'Automatic/Manual' -Encontrado ("{0}" -f $svc.StartType) `
                -Status (Get-Status $okUpd) `
                -Recomendacao 'Set-Service -Name wuauserv -StartupType Manual'
        } catch {
            Add-Resultado -Id 'UPD-01' -Checagem 'Windows Update nao desativado' -Esperado 'Automatic/Manual' `
                -Encontrado ("Erro: {0}" -f $_.Exception.Message) -Status 'ERRO' -Recomendacao 'Verificar manualmente'
        }
    } finally {
        if (Test-Path -LiteralPath $cfg) {
            Remove-Item -LiteralPath $cfg -Force -ErrorAction SilentlyContinue
        }
    }
}

function Show-Resultados {
    $script:Resultados | Format-Table ID, Checagem, Encontrado, Status -AutoSize
    $total = @($script:Resultados).Count
    $aprovados = @($script:Resultados | Where-Object Status -eq 'APROVADO').Count
    $reprovados = @($script:Resultados | Where-Object Status -eq 'REPROVADO').Count
    $erros = @($script:Resultados | Where-Object Status -eq 'ERRO').Count
    $nota = 0
    if ($total -gt 0) { $nota = [math]::Round(($aprovados / $total) * 100) }
    Write-Host ("Pontuacao: {0} de {1} ({2}%) | REPROVADO={3} ERRO={4}" -f $aprovados, $total, $nota, $reprovados, $erros)
    Add-Log ("nota={0}% aprovados={1} total={2} reprovado={3} erro={4}" -f $nota, $aprovados, $total, $reprovados, $erros)
    return @{ Total = $total; Aprovados = $aprovados; Nota = $nota }
}

function Export-Relatorios {
    param($Resumo)

    $data = Get-Date -Format 'yyyyMMdd-HHmmss'
    $jsonPath = Join-Path $pasta ("auditoria-{0}.json" -f $data)
    $htmlPath = Join-Path $pasta ("auditoria-{0}.html" -f $data)

    $payload = [PSCustomObject]@{
        Computador = $env:COMPUTERNAME
        Usuario    = $env:USERNAME
        Data       = (Get-Date).ToString('o')
        Pontuacao  = $Resumo.Nota
        Aprovados  = $Resumo.Aprovados
        Total      = $Resumo.Total
        Itens      = $script:Resultados
    }
    $payload | ConvertTo-Json -Depth 5 | Out-File -LiteralPath $jsonPath -Encoding utf8

    $linhas = New-Object System.Text.StringBuilder
    [void]$linhas.AppendLine('<!DOCTYPE html>')
    [void]$linhas.AppendLine('<html lang="pt-BR"><head><meta charset="utf-8">')
    [void]$linhas.AppendLine('<title>Auditoria de Seguranca</title>')
    [void]$linhas.AppendLine(@'
<style>
body{font-family:Consolas,Segoe UI,monospace;margin:0;padding:32px;background:#0b0f0c;color:#9fff9f}
h1{color:#39ff14;margin:0 0 8px 0;font-size:22px}
.meta{color:#7fbf7f;margin-bottom:20px}
table{border-collapse:collapse;width:100%;background:#101610}
th,td{padding:8px 10px;border-bottom:1px solid #1e2a1e;text-align:left;vertical-align:top;font-size:13px}
th{background:#152015;color:#39ff14}
.ok{color:#39ff14;font-weight:700}
.falha{color:#ff4d4d;font-weight:700}
.erro{color:#ffcc00;font-weight:700}
.foot{margin-top:18px;color:#7fbf7f;font-size:12px}
</style>
'@)
    [void]$linhas.AppendLine('</head><body>')
    [void]$linhas.AppendLine('<h1>A Matrix | Auditoria de Seguranca</h1>')
    [void]$linhas.AppendLine(('<div class="meta">{0} | {1} | Pontuacao: {2} de {3} ({4}%) | {5}</div>' -f `
        $env:COMPUTERNAME, $env:USERNAME, $Resumo.Aprovados, $Resumo.Total, $Resumo.Nota, (Get-Date -Format 'dd/MM/yyyy HH:mm')))
    [void]$linhas.AppendLine('<table><thead><tr><th>ID</th><th>Checagem</th><th>Esperado</th><th>Encontrado</th><th>Status</th><th>Recomendacao</th></tr></thead><tbody>')

    foreach ($item in $script:Resultados) {
        $cls = 'erro'
        if ($item.Status -eq 'APROVADO') { $cls = 'ok' }
        elseif ($item.Status -eq 'REPROVADO') { $cls = 'falha' }
        $id = [System.Net.WebUtility]::HtmlEncode([string]$item.ID)
        $ch = [System.Net.WebUtility]::HtmlEncode([string]$item.Checagem)
        $esp = [System.Net.WebUtility]::HtmlEncode([string]$item.Esperado)
        $enc = [System.Net.WebUtility]::HtmlEncode([string]$item.Encontrado)
        $st = [System.Net.WebUtility]::HtmlEncode([string]$item.Status)
        $rec = [System.Net.WebUtility]::HtmlEncode([string]$item.Recomendacao)
        [void]$linhas.AppendLine(('<tr><td>{0}</td><td>{1}</td><td>{2}</td><td>{3}</td><td class="{4}">{5}</td><td>{6}</td></tr>' -f `
            $id, $ch, $esp, $enc, $cls, $st, $rec))
    }

    [void]$linhas.AppendLine('</tbody></table>')
    [void]$linhas.AppendLine('<div class="foot">So leitura na auditoria. Correcoes manuais de senha/LSASS ficam na recomendacao.</div>')
    [void]$linhas.AppendLine('</body></html>')
    [System.IO.File]::WriteAllText($htmlPath, $linhas.ToString(), [System.Text.UTF8Encoding]::new($false))

    Write-Host ("Relatorios: {0}" -f $htmlPath)
    Write-Host ("JSON: {0}" -f $jsonPath)
    try { Start-Process -FilePath $htmlPath } catch { }

    return $htmlPath
}

function Invoke-CorrecoesSeguras {
    $corrigidos = 0
    $falhas = 0
    $manuais = @()

    foreach ($item in @($script:Resultados | Where-Object Status -eq 'REPROVADO')) {
        switch -Regex ($item.ID) {
            '^FW-' {
                $perfil = $item.ID.Substring(3)
                try {
                    Set-NetFirewallProfile -Profile $perfil -Enabled True -ErrorAction Stop
                    Write-Host ("Corrigido: firewall {0}" -f $perfil)
                    Add-Log ("corrigido firewall {0}" -f $perfil)
                    $corrigidos++
                } catch {
                    Write-Host ("Falhou firewall {0}" -f $perfil)
                    $falhas++
                }
            }
            '^AV-01$' {
                try {
                    Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction Stop
                    Write-Host 'Corrigido: Defender tempo real'
                    Add-Log 'corrigido defender realtime'
                    $corrigidos++
                } catch {
                    Write-Host 'Falhou Defender tempo real'
                    $falhas++
                }
            }
            '^NET-01$' {
                try {
                    Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -ErrorAction Stop
                    Write-Host 'Corrigido: SMBv1 desativado'
                    Add-Log 'corrigido smb1'
                    $corrigidos++
                } catch {
                    Write-Host 'Falhou SMBv1'
                    $falhas++
                }
            }
            '^NET-02$' {
                try {
                    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -Value 1 -Type DWord -ErrorAction Stop
                    Write-Host 'Corrigido: RDP desativado'
                    Add-Log 'corrigido rdp'
                    $corrigidos++
                } catch {
                    Write-Host 'Falhou RDP'
                    $falhas++
                }
            }
            '^ACC-01$' {
                try {
                    $convidado = Get-LocalUser | Where-Object { $_.SID.Value -like '*-501' } | Select-Object -First 1
                    if ($convidado -and $convidado.Enabled) {
                        Disable-LocalUser -Name $convidado.Name -ErrorAction Stop
                        Write-Host ("Corrigido: conta {0} desativada" -f $convidado.Name)
                        Add-Log ('corrigido convidado {0}' -f $convidado.Name)
                        $corrigidos++
                    }
                } catch {
                    Write-Host 'Falhou conta Convidado'
                    $falhas++
                }
            }
            '^(PWD-01|PWD-02|SYS-02)$' {
                $manuais += ("{0}: {1}" -f $item.ID, $item.Recomendacao)
            }
            default {
                # AV-02, DISK-01, SYS-03, SYS-04, UPD-01 etc. ficam manuais ou fora do escopo seguro
                if ($item.ID -match '^(PWD-|SYS-02)') { }
                else { $manuais += ("{0}: {1}" -f $item.ID, $item.Recomendacao) }
            }
        }
    }

    Write-Host ''
    Write-Host ("Correcoes aplicadas: {0} | Falhas: {1}" -f $corrigidos, $falhas)
    if ($corrigidos -eq 0 -and $manuais.Count -gt 0) {
        Write-Host 'Nenhuma falha segura para corrigir automaticamente.'
        Write-Host 'O novo relatorio deve ficar quase igual: o que falta e manual.'
    }
    if ($manuais.Count -gt 0) {
        Write-Host 'Ficaram so como recomendacao manual:'
        foreach ($m in $manuais) { Write-Host (" - {0}" -f $m) }
    }
    Add-Log ("corrigir aplicados={0} falhas={1} manuais={2}" -f $corrigidos, $falhas, $manuais.Count)
    return @{ Ok = ($falhas -eq 0); Corrigidos = $corrigidos }
}

# --- main ---
Write-Host 'A Matrix | Auditoria de Seguranca do Windows'
Write-Host ''

Invoke-Checagens
$resumo = Show-Resultados

if ($Modo -eq 'auditar') {
    Export-Relatorios -Resumo $resumo | Out-Null
    if ($resumo.Nota -lt 100) { exit 1 }
    exit 0
}

Write-Host ''
Write-Host 'Aplicando apenas correcoes seguras (firewall, Defender, SMBv1, RDP, Convidado)...'
Write-Host 'Senha minima, lockout, BitLocker e LSASS NAO serao alterados automaticamente.'
Write-Host ''
$resultado = Invoke-CorrecoesSeguras
Write-Host ''
Write-Host 'Reauditoria apos correcoes:'
Invoke-Checagens
$resumo2 = Show-Resultados
Export-Relatorios -Resumo $resumo2 | Out-Null
if (-not $resultado.Ok -or $resumo2.Nota -lt 100) { exit 1 }
exit 0
