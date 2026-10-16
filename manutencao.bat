@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0"
color 0A
title A Matrix

if /i "%~1"=="simular" (
    call :simular_limpeza
    exit /b
)
if /i "%~1"=="vigiar" (
    call :vigiar
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
call :criar_atalho

if /i "%~1"=="organizar" (
    call :organizar_downloads
    exit /b
)
if /i "%~1"=="tudo" (
    call :aplicar_tudo
    exit /b
)


set "task_count=0"
call :task simular_limpeza "Simular organizacao de Downloads e limpeza"
call :task organizar_downloads "Organizar Downloads e limpar temporarios"
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
powershell -NoProfile -Command "try { Invoke-WebRequest -Uri 'https://www.google.com' -UseBasicParsing -TimeoutSec 5 | Out-Null; exit 0 } catch { exit 1 }" >nul 2>&1
if !errorlevel!==0 set "REDE=Conectada"

set "IP=Nao identificado"
for /f "tokens=2 delims=:" %%i in ('ipconfig ^| findstr /i "IPv4"') do (
    set "IP=%%i"
)

cls
echo ==========================================================
echo Administrador : %ADMIN%
echo Computador    : %COMPUTERNAME%
echo Usuario       : %USERNAME%
echo Rede          : %REDE%
echo IP            :%IP%
echo Disco %DRIVE% : !LIVREGB! GB livres de !TOTALGB! GB ^(!LIVREPCT!%%^) - !STATUSDISCO!
echo Data/Hora     : %DATE% %TIME:~0,5%
echo ==========================================================
echo.
echo                         ** MENU **                        
echo.
echo ==========================================================
call :list_task
echo 0 - Sair
echo ==========================================================
echo.
set "opcao="
set /p opcao=Escolha: 
if "%opcao%"=="0" exit /b
call :run_task "%opcao%"
echo.
pause
goto header

:abertura
set "ABERTURA=1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0chuva.ps1"
color 0A
cls
echo Acorde, %USERNAME%.
timeout /t 1 >nul
echo A Matrix te pegou.
timeout /t 1 >nul
echo Siga o coelho branco.
timeout /t 1 >nul
exit /b

:criar_atalho
set "ATALHO_BAT=%~f0"
set "ATALHO_DIR=%~dp0"
powershell -NoProfile -Command "$s = New-Object -ComObject WScript.Shell; $startup = [Environment]::GetFolderPath('Startup'); $l = $s.CreateShortcut((Join-Path $startup 'LimpadorWindows.lnk')); $l.TargetPath = $env:ATALHO_BAT; $l.Arguments = 'vigiar'; $l.WorkingDirectory = $env:ATALHO_DIR.TrimEnd('\'); $l.WindowStyle = 7; $l.Description = 'Organiza Downloads e limpa temporarios em segundo plano'; $l.Save()"
echo Atalho de inicializacao pronto. Na proxima entrada no Windows a limpeza repete sozinha.
exit /b

:simular_limpeza
echo Simulacao. Nada sera movido nem apagado.
call :executar_limpeza simular 1
exit /b

:organizar_downloads
echo Organizando Downloads e limpando temporarios, dumps e Prefetch.
echo Instalador antigo so e movido. Nenhum programa e desinstalado.
call :executar_limpeza aplicar 1
exit /b

:vigiar
call :executar_limpeza aplicar 0 vigiar
exit /b

:aplicar_tudo
echo.
echo Aplicando a manutencao completa. Pode demorar. Nao feche esta janela.
echo.
call :organizar_downloads
echo.
call :clean_updates
echo.
call :flush_dns
echo.
call :clean_trash
echo.
call :reset_spooler
echo.
call :repair_image
echo.
call :repair_system
echo.
call :check_disk
echo.
call :optimize_disk
echo.
echo Manutencao completa.
pause
exit /b

:clean_updates
echo Limpando arquivos de atualizacao...
net stop wuauserv >nul 2>&1
del /f /s /q "%systemroot%\SoftwareDistribution\Download\*-*" >nul 2>&1
net start wuauserv >nul 2>&1
echo Limpeza concluida.
exit /b

:flush_dns
echo Limpando cache DNS...
ipconfig /flushdns
echo Limpeza concluida.
exit /b

:clean_trash
echo Esvaziando lixeira...
rd /s /q %SystemDrive%\$Recycle.Bin >nul 2>&1
echo Lixeira limpa.
exit /b

:reset_spooler
echo Reiniciando spooler de impressao...
net stop spooler
net start spooler
echo Processo concluido.
exit /b

:check_disk
echo Verificando o disco online. Esse processo pode demorar...
chkdsk %SystemDrive% /scan
if errorlevel 1 echo O CHKDSK encontrou um problema ou terminou com erro.
exit /b

:check_image
echo Verificando a imagem do Windows sem reparar...
Dism /Online /Cleanup-Image /ScanHealth
if errorlevel 1 echo O DISM terminou com erro.
exit /b

:verify_system
echo Verificando arquivos protegidos sem reparar...
sfc /verifyonly
if errorlevel 1 echo O SFC encontrou um problema ou terminou com erro.
exit /b

:optimize_disk
echo Iniciando a otimizacao...
defrag %SystemDrive% /O
echo Otimizacao concluida.
exit /b

:repair_image
echo Reparando a imagem do Windows. Esse processo pode demorar...
Dism /Online /Cleanup-Image /RestoreHealth
if errorlevel 1 (
    echo O DISM terminou com erro.
    exit /b
)
echo Imagem do Windows reparada.
exit /b

:repair_system
echo Verificando e reparando arquivos protegidos...
sfc /scannow
echo Verificacao concluida.
exit /b

:executar_limpeza
setlocal DisableDelayedExpansion
set "MODO=%~1"
set "INCLUIR_PREFETCH=%~2"
set "VIGIAR=0"
if /i "%~3"=="vigiar" set "VIGIAR=1"
set "IDADE_DOWNLOADS=2"
set "IDADE_LIXO=7"
set "IDADE_TEMP=1"
set "INTERVALO_MIN=30"
set "PASTA_LIXO=_Lixo"
set "LOG=%~dp0limpador.log"
set "RAIZ=%USERPROFILE%\Downloads"
if "%VIGIAR%"=="1" call :registrar "Vigia ativa. Prefetch fica de fora. Proxima passagem em %INTERVALO_MIN% min."

:ciclo
set "movidos=0"
set "quarentena=0"
set "ignorados=0"
set "apagados=0"
set "liberados=0"
if "%MODO%"=="simular" call :registrar "Simulacao. Nada sera movido. Use aplicar para valer."
call :varrer
call :esvaziar_lixo
call :registrar "Downloads. organizados=%movidos% quarentena=%quarentena% apagados=%apagados% recentes_ou_desconhecidos=%ignorados%"
call :limpar_sistema
call :mostrar_total
if "%VIGIAR%"=="0" goto fim_limpeza
set /a "ESPERA=INTERVALO_MIN*60"
timeout /t %ESPERA% /nobreak >nul
goto ciclo

:fim_limpeza
endlocal
goto :eof

:varrer
if not exist "%RAIZ%\" (
    call :registrar "Pasta de Downloads nao encontrada: %RAIZ%"
    goto :eof
)
for /f "usebackq delims=" %%F in (`forfiles /P "%RAIZ%" /D -%IDADE_DOWNLOADS% /C "cmd /c if @isdir==FALSE echo @path" 2^>nul`) do call :classificar %%F
goto :eof

:classificar
set "arquivo=%~1"
set "nome=%~nx1"
set "ext=%~x1"
if "%nome:~0,1%"=="." goto :eof
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
    call :registrar "SIMULAR %~nx1 -> %~nx2"
    set "MOVEU=1"
    goto :eof
)
if not exist "%destino_dir%\" mkdir "%destino_dir%"
move /y "%origem%" "%LIVRE%" >nul
if errorlevel 1 (
    call :registrar "Nao deu para mover %~nx1"
    goto :eof
)
call :registrar "MOVER %~nx1 -> %~nx2"
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
