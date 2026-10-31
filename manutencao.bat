@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0"
color 0A
title A Matrix

if /i "%~1"=="simular" (
    call :simular_limpeza
    exit /b
)

net session >nul 2>&1
if %errorlevel% neq 0 (
    if "%~1"=="" (
        powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    ) else (
        powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs"
    )
    if errorlevel 1 (
        echo Nao foi possivel abrir como administrador.
        pause
    )
    exit /b
)
set "ADMIN=Sim"
mode con cols=100 lines=48 >nul 2>&1
call :desligar_automatico
if /i "%~1"=="vigiar" exit /b

if /i "%~1"=="organizar" (
    call :organizar_downloads
    exit /b
)
if /i "%~1"=="tudo" (
    call :aplicar_tudo
    exit /b
)

set "task_count=0"
call :task simular_limpeza "Simular organizacao de Downloads, Area de trabalho e limpeza"
call :task organizar_downloads "Organizar Downloads, Area de trabalho e limpar temporarios"
call :task clean_updates "Limpar arquivos de atualizacoes desnecessarios"
call :task flush_dns "Limpar cache DNS"
call :task clean_trash "Esvaziar lixeira"
call :task reset_spooler "Reiniciar a fila de impressao"
call :task check_disk "Verificar disco (CHKDSK online)"
call :task check_image "Verificar imagem do Windows (DISM ScanHealth)"
call :task verify_system "Verificar arquivos protegidos (SFC verifyonly)"
call :task repair_image "Reparar imagem do Windows (DISM RestoreHealth)"
call :task repair_system "Corrigir arquivos do Windows (SFC scannow)"
call :task optimize_disk "Otimizar disco (SSD/HD)"
call :task aliviar_processos "Aliviar processos em segundo plano"
call :task limpar_caches "Limpar caches do sistema e da placa de video"
call :task limpar_restos "Tirar restos de programas desinstalados"
call :task verificar_virus "Verificar virus (Windows Defender)"
call :task varredura_offline "Varredura offline contra virus (reinicia o PC)"
call :task remover_bloat "Remover apps pre-instalados (sem Xbox)"
call :task privacidade "Privacidade (telemetria, anuncios, Cortana)"
call :task performance_leve "Performance leve (Game DVR, animacoes, energia)"
call :task desativar_servicos "Desativar servicos inuteis (inclui WSearch)"
call :task otimizar_windows "Otimizar Windows (bloat, privacidade, performance, servicos)"

goto header

:task
set /a task_count+=1
set "task_func[%task_count%]=%~1"
set "task_alias[%task_count%]=%~2"
exit /b

:list_task
for /l %%i in (1,1,%task_count%) do echo %%i - !task_alias[%%i]!
exit /b

:run_task
if not defined task_func[%~1] (
    echo Opcao invalida.
    exit /b
)
call :!task_func[%~1]!
exit /b

:perguntar_sn
choice /C SN /N /M "%~1 [S/N]"
if errorlevel 2 exit /b 1
if errorlevel 1 exit /b 0
exit /b 1

:perguntar_sim
set "confirma="
set /p "confirma=%~1 "
if /i "!confirma!"=="SIM" exit /b 0
if /i "!confirma!"=="S" exit /b 0
exit /b 1

:header
if not defined ABERTURA (
    call :abertura
) else (
    cls
)
color 0A
title A Matrix
set "DRIVE=%SystemDrive%"
set "LIVREGB=?"
set "TOTALGB=?"
set "LIVREPCT=100"
set "STATUSDISCO=DESCONHECIDO"

for /f "usebackq tokens=1-3" %%A in (`powershell -NoProfile -Command "$d = Get-CimInstance Win32_LogicalDisk | Where-Object DeviceID -eq '%DRIVE%'; if ($d.Size) { '{0} {1} {2}' -f [math]::Floor($d.FreeSpace/1GB), [math]::Floor($d.Size/1GB), [math]::Floor($d.FreeSpace*100/$d.Size) }"`) do (
    set "LIVREGB=%%A"
    set "TOTALGB=%%B"
    set "LIVREPCT=%%C"
    set "STATUSDISCO=BOM"
)

if "%STATUSDISCO%"=="BOM" (
    if !LIVREPCT! LEQ 20 set "STATUSDISCO=ATENCAO"
    if !LIVREPCT! LEQ 10 set "STATUSDISCO=CRITICO"
)

set "REDE=Desconectada"
ping -n 1 -w 1500 8.8.8.8 >nul 2>&1
if not errorlevel 1 set "REDE=Conectada"

set "IP=Nao identificado"
for /f "tokens=2 delims=:" %%i in ('ipconfig ^| findstr /i "IPv4"') do (
    set "IP=%%i"
)
if "!IP:~0,1!"==" " set "IP=!IP:~1!"

cls
echo ==========================================================
echo                         A MATRIX  
echo ==========================================================
echo Administrador : %ADMIN%
echo Computador    : %COMPUTERNAME%
echo Usuario       : %USERNAME%
echo Rede          : %REDE%
echo IP            : !IP!
echo Disco !DRIVE:~0,1!       : !LIVREGB! GB livres de !TOTALGB! GB ^(!LIVREPCT!%%^) - !STATUSDISCO!
echo Data/Hora     : %DATE% %TIME:~0,5%
echo ==========================================================
echo.
echo                         ** MENU **
echo.
echo ==========================================================
call :list_task
echo 0 - Sair ^(desconectar^)
echo ==========================================================
echo.
set "opcao="
set /p opcao=Escolha a pilula: 
if "%opcao%"=="0" exit /b
call :run_task "%opcao%"
echo.
pause
goto header

:abertura
set "ABERTURA=1"
color 0A
if exist "%~dp0chuva.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0chuva.ps1" -Segundos 3
)
color 0A
cls
echo.
echo  ========================================
echo   Acorde, %USERNAME%.
echo  ========================================
timeout /t 1 >nul
echo   A Matrix te pegou...
timeout /t 1 >nul
echo   Siga o coelho branco.
timeout /t 1 >nul
echo   A escolha e sua: menu ou aplicar.bat.
timeout /t 1 >nul
echo.
exit /b

:desligar_automatico
if exist "%~dp0sem-vigia.flag" del /f /q "%~dp0sem-vigia.flag" >nul 2>&1
powershell -NoProfile -Command "$lnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'LimpadorWindows.lnk'; if (Test-Path -LiteralPath $lnk) { Remove-Item -LiteralPath $lnk -Force }; $t = Get-ScheduledTask -TaskName 'LimpadorWindows' -ErrorAction SilentlyContinue; if ($t) { Unregister-ScheduledTask -TaskName 'LimpadorWindows' -Confirm:$false }" >nul 2>&1
exit /b 0

:aliviar_processos
echo.
echo Isso encerra so processos em segundo plano desta lista:
echo  - Barra de jogos Xbox
echo  - Widgets do Windows
echo  - Vincular ao celular
echo  - OneDrive
echo  - Atualizadores do Edge, do Google e da Adobe
echo  - Telemetria de compatibilidade do Windows
echo.
echo Navegador, jogos, Explorer e antivirus ficam abertos.
echo O Windows pode reabrir alguns desses itens depois.
echo.
call :perguntar_sn "Encerrar esses processos agora"
if errorlevel 1 (
    echo Cancelado.
    exit /b 0
)
set "LOG=%~dp0limpador.log"
set "ENCERRADOS=0"
set "AUSENTES=0"
set "FALHOU_PROC=0"
for %%P in (
    GameBar.exe
    GameBarFTServer.exe
    GameBarPresenceWriter.exe
    Widgets.exe
    WidgetService.exe
    PhoneExperienceHost.exe
    YourPhone.exe
    YourPhoneAppProxy.exe
    OneDrive.exe
    MicrosoftEdgeUpdate.exe
    GoogleUpdate.exe
    GoogleCrashHandler.exe
    GoogleCrashHandler64.exe
    AdobeIPCBroker.exe
    CompatTelRunner.exe
) do call :encerrar_processo %%P
echo.
echo Encerrados: %ENCERRADOS%. Nao estavam abertos: %AUSENTES%. Falhas: %FALHOU_PROC%.
call :registrar "ALIVIAR encerrados=%ENCERRADOS% ausentes=%AUSENTES% falhas=%FALHOU_PROC%"
if %FALHOU_PROC% GTR 0 exit /b 1
exit /b 0

:encerrar_processo
tasklist /FI "IMAGENAME eq %~1" /NH 2>nul | findstr /I /C:"%~1" >nul
if errorlevel 1 (
    set /a AUSENTES+=1
    exit /b 0
)
taskkill /IM "%~1" >nul 2>&1
if not errorlevel 1 goto encerrou_processo
taskkill /F /IM "%~1" >nul 2>&1
if errorlevel 1 (
    echo Nao deu para encerrar %~1
    call :registrar "ALIVIAR falhou %~1"
    set /a FALHOU_PROC+=1
    exit /b 1
)
:encerrou_processo
echo Encerrado: %~1
call :registrar "ALIVIAR encerrado %~1"
set /a ENCERRADOS+=1
exit /b 0

:limpar_caches
echo.
echo Limpa caches que o Windows e a placa de video recriam sozinhos:
echo  - shaders DirectX, NVIDIA, AMD e Intel
echo  - miniaturas e icones do Explorer
echo  - cache de fontes
echo  - cache de Otimizacao de Entrega
echo.
echo Navegador fica de fora. Conta salva, cookie e sessao nao sao apagados.
echo O primeiro jogo depois disso pode demorar um pouco mais para abrir.
echo DNS, atualizacao do Windows e Prefetch continuam nas outras opcoes.
echo.
call :perguntar_sn "Limpar esses caches agora"
if errorlevel 1 (
    echo Cancelado.
    exit /b 0
)
set "LOG=%~dp0limpador.log"
set "CACHE_LIBERADO=0"
set "CACHE_EM_USO=0"
call :esvaziar_cache "%LOCALAPPDATA%\D3DSCache" "Shaders DirectX"
call :esvaziar_cache "%LOCALAPPDATA%\NVIDIA\DXCache" "Shaders NVIDIA DX"
call :esvaziar_cache "%LOCALAPPDATA%\NVIDIA\GLCache" "Shaders NVIDIA GL"
call :esvaziar_cache "%LOCALAPPDATA%\NVIDIA\OptixCache" "Shaders NVIDIA OptiX"
call :esvaziar_cache "%PROGRAMDATA%\NVIDIA Corporation\NV_Cache" "Cache NVIDIA"
call :esvaziar_cache "%LOCALAPPDATA%\AMD\DxCache" "Shaders AMD DX"
call :esvaziar_cache "%LOCALAPPDATA%\AMD\DxcCache" "Shaders AMD DXC"
call :esvaziar_cache "%LOCALAPPDATA%\AMD\GLCache" "Shaders AMD GL"
call :esvaziar_cache "%LOCALAPPDATA%\AMD\VkCache" "Shaders AMD Vulkan"
call :esvaziar_cache "%LOCALAPPDATA%\Intel\ShaderCache" "Shaders Intel"
call :limpar_miniaturas
echo Parando o cache de fontes...
net stop FontCache >nul 2>&1
call :esvaziar_cache "%SystemRoot%\ServiceProfiles\LocalService\AppData\Local\FontCache" "Fontes"
if exist "%SystemRoot%\System32\FNTCACHE.DAT" del /f /q "%SystemRoot%\System32\FNTCACHE.DAT" >nul 2>&1
net start FontCache >nul 2>&1
call :esvaziar_cache "%SystemRoot%\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache" "Otimizacao de Entrega"
powershell -NoProfile -Command "if (Get-Command Delete-DeliveryOptimizationCache -ErrorAction SilentlyContinue) { Delete-DeliveryOptimizationCache -Force -ErrorAction SilentlyContinue }" >nul 2>&1
call :mostrar_caches
call :registrar "CACHE liberado=%CACHE_LIBERADO% bytes em_uso=%CACHE_EM_USO%"
exit /b 0

:limpar_miniaturas
set "CACHE_ALVO=%LOCALAPPDATA%\Microsoft\Windows\Explorer"
if not exist "%CACHE_ALVO%\" (
    echo Ausente: Miniaturas
    call :registrar "CACHE ausente Miniaturas"
    exit /b 0
)
for /f "usebackq delims=" %%N in (`powershell -NoProfile -Command "$s=(Get-ChildItem -LiteralPath $env:CACHE_ALVO -Force -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'thumbcache_*.db' -or $_.Name -like 'iconcache_*.db' } | Measure-Object -Property Length -Sum).Sum; if($null -eq $s){'0'}else{[convert]::ToString([int64]$s,10)}"`) do set "ANTES=%%N"
if "%ANTES%"=="" set "ANTES=0"
if "%ANTES%"=="0" (
    echo Vazio: Miniaturas
    call :registrar "CACHE vazio Miniaturas"
    exit /b 0
)
del /f /q /a "%CACHE_ALVO%\thumbcache_*.db" >nul 2>&1
del /f /q /a "%CACHE_ALVO%\iconcache_*.db" >nul 2>&1
for /f "usebackq delims=" %%N in (`powershell -NoProfile -Command "$s=(Get-ChildItem -LiteralPath $env:CACHE_ALVO -Force -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'thumbcache_*.db' -or $_.Name -like 'iconcache_*.db' } | Measure-Object -Property Length -Sum).Sum; if($null -eq $s){'0'}else{[convert]::ToString([int64]$s,10)}"`) do set "DEPOIS=%%N"
if "%DEPOIS%"=="" set "DEPOIS=0"
call :somar_cache
if not "%DEPOIS%"=="0" (
    echo Em uso, ficou resto: Miniaturas
    set "CACHE_EM_USO=1"
    call :registrar "CACHE em uso Miniaturas"
) else (
    echo Limpo: Miniaturas
    call :registrar "CACHE limpo Miniaturas"
)
exit /b 0

:esvaziar_cache
set "CACHE_ALVO=%~1"
if not exist "%CACHE_ALVO%\" (
    echo Ausente: %~2
    call :registrar "CACHE ausente %~2"
    exit /b 0
)
call :medir_cache
set "ANTES=%MEDIDA%"
if "%ANTES%"=="0" (
    echo Vazio: %~2
    call :registrar "CACHE vazio %~2"
    exit /b 0
)
del /f /s /q /a "%CACHE_ALVO%\*" >nul 2>&1
for /d %%D in ("%CACHE_ALVO%\*") do rd /s /q "%%D" >nul 2>&1
call :medir_cache
set "DEPOIS=%MEDIDA%"
call :somar_cache
if not "%DEPOIS%"=="0" (
    echo Em uso, ficou resto: %~2
    set "CACHE_EM_USO=1"
    call :registrar "CACHE em uso %~2"
) else (
    echo Limpo: %~2
    call :registrar "CACHE limpo %~2"
)
exit /b 0

:medir_cache
set "MEDIDA=0"
for /f "usebackq delims=" %%N in (`powershell -NoProfile -Command "$s=(Get-ChildItem -LiteralPath $env:CACHE_ALVO -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum; if($null -eq $s){'0'}else{[convert]::ToString([int64]$s,10)}"`) do set "MEDIDA=%%N"
if "%MEDIDA%"=="" set "MEDIDA=0"
exit /b 0

:somar_cache
for /f "usebackq delims=" %%N in (`powershell -NoProfile -Command "$l=[int64]$env:CACHE_LIBERADO; $a=[int64]$env:ANTES; $d=[int64]$env:DEPOIS; if($a -lt $d){$a=$d}; [convert]::ToString($l + $a - $d, 10)"`) do set "CACHE_LIBERADO=%%N"
exit /b 0

:mostrar_caches
for /f "usebackq delims=" %%N in (`powershell -NoProfile -Command "$b=[int64]$env:CACHE_LIBERADO; $mb=[math]::Floor($b/1MB); $resto=[math]::Floor(($b %% 1MB)*10/1MB); '{0}.{1}' -f $mb,$resto"`) do set "CACHE_MB=%%N"
echo.
echo Espaco liberado nos caches: %CACHE_MB% MB
if "%CACHE_EM_USO%"=="1" echo Alguns arquivos estavam em uso e ficaram para a proxima vez.
echo Navegadores nao foram alterados.
exit /b 0

:limpar_restos
echo.
echo Procura restos de programas que ja foram desinstalados.
echo A pasta so e apagada em Arquivos de Programas ou ProgramData,
echo quando o desinstalador sumiu e nao restou nenhum programa.
echo Tambem tira a entrada fantasma da lista de programas
echo e o inicio automatico que aponta para arquivo que nao existe.
echo AppData, pasta do usuario, navegador e pecas do Windows ficam de fora.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0restos.ps1" -Modo listar
if errorlevel 2 exit /b 0
if errorlevel 1 (
    echo Nao deu para procurar os restos.
    exit /b 1
)
echo.
call :perguntar_sn "Apagar esses restos agora"
if errorlevel 1 (
    echo Cancelado.
    exit /b 0
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0restos.ps1" -Modo aplicar
if errorlevel 1 (
    echo Limpeza de restos terminou com aviso.
    exit /b 1
)
echo Limpeza de restos concluida.
exit /b 0

:verificar_virus
echo.
echo Verifica virus com o Windows Defender, que ja vem no Windows.
echo Atualiza as definicoes e faz a varredura rapida.
echo Leva alguns minutos. Nao feche a janela.
echo A varredura do disco inteiro fica na Seguranca do Windows: pode levar horas.
echo.
call :perguntar_sn "Verificar virus agora"
if errorlevel 1 (
    echo Cancelado.
    exit /b 0
)
set "LOG=%~dp0limpador.log"
powershell -NoProfile -Command "try { $s = Get-MpComputerStatus -ErrorAction Stop; if (-not $s.AntivirusEnabled) { exit 2 }; if (-not $s.RealTimeProtectionEnabled) { Write-Output 'Protecao em tempo real esta desligada. A varredura mesmo assim vai rodar.' } } catch { exit 2 }"
if errorlevel 2 (
    echo O Windows Defender nao esta ativo neste PC.
    call :registrar "VIRUS defender inativo"
    exit /b 1
)
echo Atualizando definicoes...
powershell -NoProfile -Command "try { Update-MpSignature -ErrorAction Stop; exit 0 } catch { exit 1 }"
if errorlevel 1 echo Nao deu para atualizar as definicoes. A varredura segue com as que ja estao no PC.
echo Varredura rapida em andamento...
powershell -NoProfile -Command "try { Start-MpScan -ScanType QuickScan -ErrorAction Stop; exit 0 } catch { Write-Output $_.Exception.Message; exit 1 }"
if errorlevel 1 (
    echo A varredura nao terminou.
    call :registrar "VIRUS varredura falhou"
    exit /b 1
)
powershell -NoProfile -Command "$t = Get-MpThreat -ErrorAction SilentlyContinue; if (-not $t) { Write-Output 'Nenhuma ameaca encontrada.'; exit 0 }; foreach ($a in @($t)) { Write-Output ('Ameaca: ' + $a.ThreatName) }; exit 3"
if errorlevel 3 (
    echo Abra a Seguranca do Windows para ver a ameaca e decidir o que fazer.
    call :registrar "VIRUS ameaca encontrada"
    exit /b 1
)
call :registrar "VIRUS nenhuma ameaca"
exit /b 0

:varredura_offline
echo.
echo Use isto quando um virus continua rodando junto com o Windows.
echo O PC reinicia e o Defender examina o disco antes do sistema abrir.
echo Salve seus arquivos. A volta ao Windows pode demorar.
echo.
call :perguntar_sim "Digite SIM para reiniciar e varrer:"
if errorlevel 1 (
    echo Cancelado.
    exit /b 0
)
set "LOG=%~dp0limpador.log"
powershell -NoProfile -Command "try { $s = Get-MpComputerStatus -ErrorAction Stop; if (-not $s.AntivirusEnabled) { exit 2 } } catch { exit 2 }"
if errorlevel 2 (
    echo O Windows Defender nao esta ativo neste PC.
    call :registrar "VIRUS defender inativo"
    exit /b 1
)
echo Atualizando definicoes...
powershell -NoProfile -Command "try { Update-MpSignature -ErrorAction Stop; exit 0 } catch { exit 1 }"
if errorlevel 1 echo Nao deu para atualizar as definicoes. A varredura segue com as que ja estao no PC.
echo Reiniciando para a varredura offline...
call :registrar "VIRUS varredura offline iniciada"
powershell -NoProfile -Command "try { Start-MpWDOScan -ErrorAction Stop; exit 0 } catch { Write-Output $_.Exception.Message; exit 1 }"
if errorlevel 1 (
    echo Nao deu para iniciar a varredura offline.
    call :registrar "VIRUS varredura offline falhou"
    exit /b 1
)
exit /b 0

:remover_bloat
echo.
echo Remove apps pre-instalados: Bing, Skype, Solitaire, Mapas,
echo Feedback Hub, Vincular ao celular e similares.
echo Xbox, Game Bar, Store, Paint e codecs de imagem ficam no lugar.
echo.
call :perguntar_sn "Remover esses apps agora"
if errorlevel 1 (
    echo Cancelado.
    exit /b 0
)
if not exist "%~dp0otimizar.ps1" (
    echo Arquivo otimizar.ps1 nao encontrado.
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0otimizar.ps1" -Modo bloat
if errorlevel 1 (
    echo Remocao de apps terminou com aviso.
    exit /b 1
)
echo Remocao de apps concluida.
exit /b 0

:privacidade
echo.
echo Reduz telemetria, anuncios, Cortana e sugestoes do Windows.
echo Nao remove Xbox nem Game Bar.
echo.
call :perguntar_sn "Aplicar privacidade agora"
if errorlevel 1 (
    echo Cancelado.
    exit /b 0
)
if not exist "%~dp0otimizar.ps1" (
    echo Arquivo otimizar.ps1 nao encontrado.
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0otimizar.ps1" -Modo privacidade
if errorlevel 1 (
    echo Privacidade terminou com aviso.
    exit /b 1
)
echo Privacidade aplicada.
exit /b 0

:performance_leve
echo.
echo Desliga Game DVR, reduz animacoes e ativa o plano
echo ChrisTitus - Ultimate Power Plan (cria se ainda nao existir).
echo Disco, USB, PCI Express e processador no maximo.
echo Xbox e Game Bar nao sao removidos.
echo.
call :perguntar_sn "Aplicar performance leve agora"
if errorlevel 1 (
    echo Cancelado.
    exit /b 0
)
if not exist "%~dp0otimizar.ps1" (
    echo Arquivo otimizar.ps1 nao encontrado.
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0otimizar.ps1" -Modo performance
if errorlevel 1 (
    echo Performance leve terminou com aviso.
    exit /b 1
)
echo Performance leve aplicada.
exit /b 0

:desativar_servicos
echo.
echo Desativa Fax, telemetria, RemoteRegistry, WSearch e similares.
echo WSearch desligado enfraquece a busca do menu Iniciar e do Explorer.
echo Servicos Xbox, SysMain, spooler, Update e Defender ficam ativos.
echo.
call :perguntar_sn "Desativar esses servicos agora"
if errorlevel 1 (
    echo Cancelado.
    exit /b 0
)
if not exist "%~dp0otimizar.ps1" (
    echo Arquivo otimizar.ps1 nao encontrado.
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0otimizar.ps1" -Modo servicos
if errorlevel 1 (
    echo Desativacao de servicos terminou com aviso.
    exit /b 1
)
echo Servicos desativados.
exit /b 0

:otimizar_windows
echo.
echo Pacote completo: apps pre-instalados, privacidade,
echo performance leve e servicos inuteis.
echo Xbox e Game Bar nao sao tocados.
echo WSearch sera desativado. Salve o que estiver aberto.
echo.
call :perguntar_sim "Digite SIM para otimizar o Windows agora:"
if errorlevel 1 (
    echo Cancelado.
    exit /b 0
)
if not exist "%~dp0otimizar.ps1" (
    echo Arquivo otimizar.ps1 nao encontrado.
    exit /b 1
)
set "LOG=%~dp0limpador.log"
set "OTIM_OK=0"
set "OTIM_FALHOU=0"
echo.
echo [1/4] Apps pre-instalados...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0otimizar.ps1" -Modo bloat
if errorlevel 1 (set /a OTIM_FALHOU+=1) else (set /a OTIM_OK+=1)
echo.
echo [2/4] Privacidade...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0otimizar.ps1" -Modo privacidade
if errorlevel 1 (set /a OTIM_FALHOU+=1) else (set /a OTIM_OK+=1)
echo.
echo [3/4] Performance leve...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0otimizar.ps1" -Modo performance
if errorlevel 1 (set /a OTIM_FALHOU+=1) else (set /a OTIM_OK+=1)
echo.
echo [4/4] Servicos inuteis...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0otimizar.ps1" -Modo servicos
if errorlevel 1 (set /a OTIM_FALHOU+=1) else (set /a OTIM_OK+=1)
echo.
echo ==========================================================
echo  Otimizacao concluida. Ok: %OTIM_OK%  Falhou: %OTIM_FALHOU%
echo ==========================================================
call :registrar "OTIMIZAR pacote ok=%OTIM_OK% falhou=%OTIM_FALHOU%"
if %OTIM_FALHOU% GTR 0 exit /b 1
exit /b 0

:simular_limpeza
echo Simulacao. Nada sera movido nem apagado.
call :executar_limpeza simular 1
exit /b

:organizar_downloads
echo Organizando Downloads e Area de trabalho.
echo Limpando temporarios, dumps e Prefetch.
echo Atalhos da Area de trabalho ficam no lugar. Instalador antigo so e movido.
call :executar_limpeza aplicar 1
exit /b %ERRORLEVEL%

:aplicar_tudo
cls
color 0A
title A Matrix - Manutencao completa
echo.
echo  ========================================
echo   ENTRANDO NA MATRIX...
echo   Manutencao completa em andamento.
echo   Nao feche esta janela.
echo  ========================================
echo.
echo  Etapas longas pela frente:
echo   - DISM RestoreHealth : cerca de 10 a 30 min
echo   - SFC scannow        : cerca de 10 a 20 min
echo   - CHKDSK online      : cerca de 5 a 15 min
echo   - Otimizar disco     : varia conforme o disco
echo.
timeout /t 4 >nul

set "RESUMO_COUNT=0"
set "RESUMO_OK=0"
set "RESUMO_FALHOU=0"
set "ESPACO_LIMPEZA=0.0 MB"
set "BYTES_LIMPEZA=0"
call :disco_livre LIVRE_ANTES

call :rodar_passo "Organizar Downloads, Area de trabalho e limpar temporarios" organizar_downloads
call :rodar_passo "Limpar arquivos de atualizacao" clean_updates
call :rodar_passo "Limpar cache DNS" flush_dns
call :rodar_passo "Esvaziar lixeira" clean_trash
call :rodar_passo "Reiniciar fila de impressao" reset_spooler
call :rodar_passo "Reparar imagem do Windows (DISM)" repair_image
call :rodar_passo "Corrigir arquivos do Windows (SFC)" repair_system
call :rodar_passo "Verificar disco (CHKDSK)" check_disk
call :rodar_passo "Otimizar disco" optimize_disk

call :disco_livre LIVRE_DEPOIS
call :mostrar_resumo
call :gravar_relatorio
echo.
echo  Relatorio salvo em:
echo  %ARQUIVO_RELATORIO%
echo.
echo  A Matrix te devolve o controle. Enter para sair.
pause >nul
exit /b

:rodar_passo
set /a RESUMO_COUNT+=1
set "RESUMO_NOME[%RESUMO_COUNT%]=%~1"
echo.
echo  ----------------------------------------
echo  [%RESUMO_COUNT%/9] %~1
echo  ----------------------------------------
call :%~2
if errorlevel 1 (
    set "RESUMO_STATUS[%RESUMO_COUNT%]=FALHOU"
    set /a RESUMO_FALHOU+=1
    echo  Resultado: FALHOU
) else (
    set "RESUMO_STATUS[%RESUMO_COUNT%]=OK"
    set /a RESUMO_OK+=1
    echo  Resultado: OK
)
exit /b 0

:aviso_longo
echo.
echo  ========================================
echo   ATENCAO
echo   %~1
echo   Pode demorar cerca de %~2. Nao feche a janela.
echo  ========================================
echo.
timeout /t 3 >nul
exit /b

:disco_livre
set "%~1=?"
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "[math]::Floor((Get-PSDrive -Name ($env:SystemDrive.TrimEnd(':'))).Free/1MB)"`) do set "%~1=%%A"
exit /b

:mostrar_resumo
echo.
echo  ========================================
echo   RESUMO DA MATRIX
echo  ========================================
for /l %%i in (1,1,%RESUMO_COUNT%) do (
    echo   %%i. !RESUMO_STATUS[%%i]!  - !RESUMO_NOME[%%i]!
)
echo  ----------------------------------------
echo   Ok: %RESUMO_OK%   Falhou: %RESUMO_FALHOU%
echo   Espaco liberado pela limpeza: %ESPACO_LIMPEZA%
if defined LIVRE_ANTES if defined LIVRE_DEPOIS (
    echo   Disco livre antes : %LIVRE_ANTES% MB
    echo   Disco livre depois: %LIVRE_DEPOIS% MB
)
echo  ========================================
exit /b

:gravar_relatorio
for /f "usebackq delims=" %%T in (`powershell -NoProfile -Command "Get-Date -Format 'yyyyMMdd-HHmmss'"`) do set "STAMP=%%T"
set "ARQUIVO_RELATORIO=%~dp0relatorio-%STAMP%.txt"
(
    echo Limpador Windows - Relatorio da Matrix
    echo Data/Hora : %DATE% %TIME:~0,8%
    echo Computador: %COMPUTERNAME%
    echo Usuario   : %USERNAME%
    echo.
    echo Resultados:
    for /l %%i in (1,1,%RESUMO_COUNT%) do echo   %%i. !RESUMO_STATUS[%%i]!  - !RESUMO_NOME[%%i]!
    echo.
    echo Ok: %RESUMO_OK%
    echo Falhou: %RESUMO_FALHOU%
    echo Espaco liberado pela limpeza de arquivos: %ESPACO_LIMPEZA%
    if defined LIVRE_ANTES echo Disco livre antes : %LIVRE_ANTES% MB
    if defined LIVRE_DEPOIS echo Disco livre depois: %LIVRE_DEPOIS% MB
    echo.
    echo Detalhes tambem em limpador.log
) > "%ARQUIVO_RELATORIO%"
exit /b

:clean_updates
echo Limpando arquivos de atualizacao...
net stop wuauserv >nul 2>&1
del /f /s /q "%systemroot%\SoftwareDistribution\Download\*-*" >nul 2>&1
net start wuauserv >nul 2>&1
if errorlevel 1 (
    echo Limpeza de atualizacao terminou com aviso.
    exit /b 1
)
echo Limpeza concluida.
exit /b 0

:flush_dns
echo Limpando cache DNS...
ipconfig /flushdns
if errorlevel 1 (
    echo Limpeza de DNS falhou.
    exit /b 1
)
echo Limpeza concluida.
exit /b 0

:clean_trash
echo Esvaziando lixeira...
rd /s /q %SystemDrive%\$Recycle.Bin >nul 2>&1
echo Lixeira limpa.
exit /b 0

:reset_spooler
echo Reiniciando spooler de impressao...
net stop spooler
if errorlevel 1 (
    echo Nao deu para parar o spooler.
    exit /b 1
)
net start spooler
if errorlevel 1 (
    echo Nao deu para iniciar o spooler.
    exit /b 1
)
echo Processo concluido.
exit /b 0

:check_disk
call :aviso_longo "Verificacao de disco (CHKDSK online)." "5 a 15 minutos"
chkdsk %SystemDrive% /scan
if errorlevel 1 (
    echo O CHKDSK encontrou um problema ou terminou com erro.
    exit /b 1
)
echo Verificacao de disco concluida.
exit /b 0

:check_image
call :aviso_longo "Verificacao da imagem do Windows (DISM ScanHealth)." "5 a 15 minutos"
Dism /Online /Cleanup-Image /ScanHealth
if errorlevel 1 (
    echo O DISM terminou com erro.
    exit /b 1
)
echo Verificacao da imagem concluida.
exit /b 0

:verify_system
call :aviso_longo "Verificacao dos arquivos protegidos (SFC verifyonly)." "10 a 20 minutos"
sfc /verifyonly
if errorlevel 1 (
    echo O SFC encontrou um problema ou terminou com erro.
    exit /b 1
)
echo Verificacao dos arquivos concluida.
exit /b 0

:optimize_disk
call :aviso_longo "Otimizacao do disco (SSD/HD)." "alguns minutos"
defrag %SystemDrive% /O
if errorlevel 1 (
    echo A otimizacao terminou com erro.
    exit /b 1
)
echo Otimizacao concluida.
exit /b 0

:repair_image
call :aviso_longo "Reparo da imagem do Windows (DISM RestoreHealth)." "10 a 30 minutos"
Dism /Online /Cleanup-Image /RestoreHealth
if errorlevel 1 (
    echo O DISM terminou com erro.
    exit /b 1
)
echo Imagem do Windows reparada.
exit /b 0

:repair_system
call :aviso_longo "Correcao dos arquivos do Windows (SFC scannow)." "10 a 20 minutos"
sfc /scannow
if errorlevel 1 (
    echo O SFC terminou com erro.
    exit /b 1
)
echo Verificacao e reparo concluidos.
exit /b 0

:executar_limpeza
setlocal DisableDelayedExpansion
set "MODO=%~1"
set "INCLUIR_PREFETCH=%~2"
set "IDADE_DOWNLOADS=2"
set "IDADE_LIXO=7"
set "IDADE_TEMP=1"
set "PASTA_LIXO=_Lixo"
set "LOG=%~dp0limpador.log"
set "PASTA_DOWNLOADS=%USERPROFILE%\Downloads"
set "PASTA_DESKTOP=%USERPROFILE%\Desktop"
for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "[Environment]::GetFolderPath('Desktop')"`) do if not "%%D"=="" set "PASTA_DESKTOP=%%D"

set "liberados=0"
set "LIMPEZA_ERRO=0"
if "%MODO%"=="simular" call :registrar "Simulacao. Nada sera movido. Use aplicar para valer."
call :organizar_pasta "%PASTA_DOWNLOADS%" "Downloads"
if errorlevel 1 set "LIMPEZA_ERRO=1"
call :organizar_pasta "%PASTA_DESKTOP%" "Area de trabalho"
if errorlevel 1 set "LIMPEZA_ERRO=1"
call :limpar_sistema
call :mostrar_total
goto fim_limpeza

:fim_limpeza
set /a mb=liberados/1048576
set /a resto=(liberados %% 1048576)*10/1048576
endlocal & set "ESPACO_LIMPEZA=%mb%.%resto% MB" & set "BYTES_LIMPEZA=%liberados%" & exit /b %LIMPEZA_ERRO%

:organizar_pasta
set "RAIZ=%~1"
set "NOME_PASTA=%~2"
set "movidos=0"
set "quarentena=0"
set "ignorados=0"
set "apagados=0"
call :varrer
if errorlevel 1 exit /b 1
call :esvaziar_lixo
call :registrar "%NOME_PASTA%. organizados=%movidos% quarentena=%quarentena% apagados=%apagados% recentes_ou_desconhecidos=%ignorados%"
exit /b 0

:varrer
if not exist "%RAIZ%\" (
    call :registrar "Pasta nao encontrada: %RAIZ%"
    exit /b 1
)
for /f "usebackq delims=" %%F in (`forfiles /P "%RAIZ%" /D -%IDADE_DOWNLOADS% /C "cmd /c if @isdir==FALSE echo @path" 2^>nul`) do call :classificar %%F
exit /b 0

:classificar
set "arquivo=%~1"
set "nome=%~nx1"
set "ext=%~x1"
if "%nome:~0,1%"=="." goto :eof
if /i "%ext%"==".lnk" goto :eof
if /i "%ext%"==".url" goto :eof
call :eh_oculto "%arquivo%"
if "%OCULTO%"=="1" goto :eof
if "%ext%"=="" (
    set /a ignorados+=1
    goto :eof
)
call :tipo "%ext%"
if "%TIPO%"=="lixo" (
    call :mover "%arquivo%" "%RAIZ%\%PASTA_LIXO%"
    if "%MOVEU%"=="1" set /a quarentena+=1
    goto :eof
)
if "%TIPO%"=="" (
    set /a ignorados+=1
    goto :eof
)
call :mover "%arquivo%" "%RAIZ%\%TIPO%"
if "%MOVEU%"=="1" set /a movidos+=1
goto :eof

:tipo
set "TIPO="
set "e=%~1"
if /i "%e%"==".tmp" set "TIPO=lixo" & goto :eof
if /i "%e%"==".crdownload" set "TIPO=lixo" & goto :eof
if /i "%e%"==".part" set "TIPO=lixo" & goto :eof
if /i "%e%"==".download" set "TIPO=lixo" & goto :eof
if /i "%e%"==".partial" set "TIPO=lixo" & goto :eof
if /i "%e%"==".lock" set "TIPO=lixo" & goto :eof
if /i "%e%"==".jpg" set "TIPO=Imagens" & goto :eof
if /i "%e%"==".jpeg" set "TIPO=Imagens" & goto :eof
if /i "%e%"==".png" set "TIPO=Imagens" & goto :eof
if /i "%e%"==".gif" set "TIPO=Imagens" & goto :eof
if /i "%e%"==".webp" set "TIPO=Imagens" & goto :eof
if /i "%e%"==".bmp" set "TIPO=Imagens" & goto :eof
if /i "%e%"==".svg" set "TIPO=Imagens" & goto :eof
if /i "%e%"==".heic" set "TIPO=Imagens" & goto :eof
if /i "%e%"==".ico" set "TIPO=Imagens" & goto :eof
if /i "%e%"==".jfif" set "TIPO=Imagens" & goto :eof
if /i "%e%"==".pdf" set "TIPO=PDFs" & goto :eof
if /i "%e%"==".doc" set "TIPO=Documentos" & goto :eof
if /i "%e%"==".docx" set "TIPO=Documentos" & goto :eof
if /i "%e%"==".txt" set "TIPO=Documentos" & goto :eof
if /i "%e%"==".rtf" set "TIPO=Documentos" & goto :eof
if /i "%e%"==".odt" set "TIPO=Documentos" & goto :eof
if /i "%e%"==".xls" set "TIPO=Documentos" & goto :eof
if /i "%e%"==".xlsx" set "TIPO=Documentos" & goto :eof
if /i "%e%"==".ppt" set "TIPO=Documentos" & goto :eof
if /i "%e%"==".pptx" set "TIPO=Documentos" & goto :eof
if /i "%e%"==".csv" set "TIPO=Documentos" & goto :eof
if /i "%e%"==".mp4" set "TIPO=Videos" & goto :eof
if /i "%e%"==".mkv" set "TIPO=Videos" & goto :eof
if /i "%e%"==".avi" set "TIPO=Videos" & goto :eof
if /i "%e%"==".mov" set "TIPO=Videos" & goto :eof
if /i "%e%"==".wmv" set "TIPO=Videos" & goto :eof
if /i "%e%"==".webm" set "TIPO=Videos" & goto :eof
if /i "%e%"==".mp3" set "TIPO=Audio" & goto :eof
if /i "%e%"==".wav" set "TIPO=Audio" & goto :eof
if /i "%e%"==".flac" set "TIPO=Audio" & goto :eof
if /i "%e%"==".aac" set "TIPO=Audio" & goto :eof
if /i "%e%"==".ogg" set "TIPO=Audio" & goto :eof
if /i "%e%"==".m4a" set "TIPO=Audio" & goto :eof
if /i "%e%"==".zip" set "TIPO=Compactados" & goto :eof
if /i "%e%"==".rar" set "TIPO=Compactados" & goto :eof
if /i "%e%"==".7z" set "TIPO=Compactados" & goto :eof
if /i "%e%"==".tar" set "TIPO=Compactados" & goto :eof
if /i "%e%"==".gz" set "TIPO=Compactados" & goto :eof
if /i "%e%"==".bz2" set "TIPO=Compactados" & goto :eof
if /i "%e%"==".zst" set "TIPO=Compactados" & goto :eof
if /i "%e%"==".xz" set "TIPO=Compactados" & goto :eof
if /i "%e%"==".tgz" set "TIPO=Compactados" & goto :eof
if /i "%e%"==".exe" set "TIPO=Instaladores" & goto :eof
if /i "%e%"==".msi" set "TIPO=Instaladores" & goto :eof
if /i "%e%"==".msix" set "TIPO=Instaladores" & goto :eof
goto :eof

:mover
set "MOVEU=0"
set "origem=%~1"
set "destino_dir=%~2"
call :livre "%destino_dir%" "%~nx1"
if "%MODO%"=="simular" (
    call :registrar "SIMULAR %~nx1 para %~nx2"
    set "MOVEU=1"
    goto :eof
)
if not exist "%destino_dir%\" mkdir "%destino_dir%"
move /y "%origem%" "%LIVRE%" >nul
if errorlevel 1 (
    call :registrar "Nao deu para mover %~nx1"
    goto :eof
)
call :registrar "MOVER %~nx1 para %~nx2"
set "MOVEU=1"
goto :eof

:livre
set "LIVRE=%~1\%~2"
if not exist "%LIVRE%" goto :eof
set "base=%~n2"
set "suf=%~x2"
set "n=1"
:livre_loop
set "LIVRE=%~1\%base% (%n%)%suf%"
if not exist "%LIVRE%" goto :eof
set /a n+=1
if %n% GTR 999 goto :eof
goto livre_loop

:esvaziar_lixo
set "lixo=%RAIZ%\%PASTA_LIXO%"
if not exist "%lixo%\" goto :eof
for /f "usebackq delims=" %%F in (`forfiles /P "%lixo%" /D -%IDADE_LIXO% /C "cmd /c if @isdir==FALSE echo @path" 2^>nul`) do call :apagar %%F
goto :eof

:limpar_sistema
if defined TEMP call :limpar_pasta "%TEMP%" %IDADE_TEMP%
if defined TMP if /i not "%TMP%"=="%TEMP%" call :limpar_pasta "%TMP%" %IDADE_TEMP%
call :limpar_pasta "%SystemRoot%\Temp" %IDADE_TEMP%
if defined LOCALAPPDATA call :limpar_pasta "%LOCALAPPDATA%\CrashDumps" %IDADE_TEMP%
if "%INCLUIR_PREFETCH%"=="1" call :limpar_prefetch
goto :eof

:limpar_prefetch
set "pref=%SystemRoot%\Prefetch"
dir /a "%pref%" >nul 2>&1
if errorlevel 1 (
    call :registrar "Prefetch sem permissao. Abra o limpador como administrador para limpar %pref%"
    goto :eof
)
call :limpar_pasta "%pref%" 0 .pf
goto :eof

:limpar_pasta
set "alvo_pasta=%~1"
set "dias_pasta=%~2"
set "filtro=%~3"
if not exist "%alvo_pasta%\" (
    call :registrar "Pasta nao encontrada: %alvo_pasta%"
    goto :eof
)
dir /a "%alvo_pasta%" >nul 2>&1
if errorlevel 1 (
    call :registrar "Sem acesso a %alvo_pasta%"
    goto :eof
)
set "apagados_pasta=0"
set "bloqueados_pasta=0"
set "liberados_pasta=0"
if "%dias_pasta%"=="0" (
    for /f "usebackq delims=" %%F in (`forfiles /P "%alvo_pasta%" /S /D -0 /C "cmd /c if @isdir==FALSE echo @path" 2^>nul`) do call :apagar_filtrado %%F
) else (
    for /f "usebackq delims=" %%F in (`forfiles /P "%alvo_pasta%" /S /D -%dias_pasta% /C "cmd /c if @isdir==FALSE echo @path" 2^>nul`) do call :apagar_filtrado %%F
)
if not "%MODO%"=="simular" (
    for /l %%N in (1,1,4) do for /f "usebackq delims=" %%D in (`dir /s /b /ad "%alvo_pasta%" 2^>nul`) do rd "%%D" 2>nul
)
if "%MODO%"=="simular" (
    call :registrar "SIMULAR apagados=%apagados_pasta% em_uso=%bloqueados_pasta% em %alvo_pasta%"
) else (
    call :registrar "LIMPAR apagados=%apagados_pasta% em_uso=%bloqueados_pasta% em %alvo_pasta%"
)
goto :eof

:apagar_filtrado
if not "%filtro%"=="" if /i not "%~x1"=="%filtro%" goto :eof
call :apagar "%~1"
goto :eof

:apagar
set "vitima=%~1"
call :eh_oculto "%vitima%"
if "%OCULTO%"=="1" goto :eof
set "peso=%~z1"
if "%peso%"=="" (
    set /a bloqueados+=1
    set /a bloqueados_pasta+=1
    goto :eof
)
if "%MODO%"=="simular" (
    set /a apagados+=1
    set /a apagados_pasta+=1
    set /a liberados+=peso
    set /a liberados_pasta+=peso
    goto :eof
)
del /f /q "%vitima%" >nul 2>&1
if exist "%vitima%" (
    set /a bloqueados+=1
    set /a bloqueados_pasta+=1
    goto :eof
)
set /a apagados+=1
set /a apagados_pasta+=1
set /a liberados+=peso
set /a liberados_pasta+=peso
goto :eof

:eh_oculto
set "OCULTO=0"
set "atr="
for %%A in ("%~1") do set "atr=%%~aA"
echo %atr% | findstr /i "h s" >nul
if not errorlevel 1 set "OCULTO=1"
goto :eof

:mostrar_total
set /a mb=liberados/1048576
set /a resto=(liberados %% 1048576)*10/1048576
if "%MODO%"=="simular" (
    call :registrar "SIMULAR Total liberado %mb%.%resto% MB"
) else (
    call :registrar "Total liberado %mb%.%resto% MB"
)
goto :eof

:registrar
echo %date% %time:~0,8% %~1
>>"%LOG%" echo %date% %time:~0,8% %~1
goto :eof
