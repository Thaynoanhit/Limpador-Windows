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
call :task remover_atalho "Parar limpeza automatica ao ligar o PC"
call :task religar_atalho "Religar limpeza automatica ao ligar o PC"

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
ping -n 1 -w 1500 8.8.8.8 >nul 2>&1
if not errorlevel 1 set "REDE=Conectada"

set "IP=Nao identificado"
for /f "tokens=2 delims=:" %%i in ('ipconfig ^| findstr /i "IPv4"') do (
    set "IP=%%i"
)
if "!IP:~0,1!"==" " set "IP=!IP:~1!"

cls
echo ==========================================================
echo  A MATRIX  ^|  Siga o coelho branco.
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

:criar_atalho
if exist "%~dp0sem-vigia.flag" (
    echo Limpeza automatica desligada. Use a opcao do menu para religar.
    exit /b
)
set "ATALHO_BAT=%~f0"
set "ATALHO_DIR=%~dp0"
powershell -NoProfile -Command "$s = New-Object -ComObject WScript.Shell; $startup = [Environment]::GetFolderPath('Startup'); $l = $s.CreateShortcut((Join-Path $startup 'LimpadorWindows.lnk')); $l.TargetPath = $env:ATALHO_BAT; $l.Arguments = 'vigiar'; $l.WorkingDirectory = $env:ATALHO_DIR.TrimEnd('\'); $l.WindowStyle = 7; $l.Description = 'Organiza Downloads e Area de trabalho e limpa temporarios em segundo plano'; $l.Save()"
echo Atalho de inicializacao pronto. Na proxima entrada no Windows a limpeza repete sozinha.
exit /b

:remover_atalho
echo Removendo o atalho da inicializacao...
powershell -NoProfile -Command "$p = Join-Path ([Environment]::GetFolderPath('Startup')) 'LimpadorWindows.lnk'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force; exit 0 } else { exit 2 }"
if errorlevel 2 (
    echo Nao havia atalho para remover.
) else if errorlevel 1 (
    echo Nao deu para remover o atalho.
    exit /b 1
) else (
    echo Atalho removido.
)
type nul > "%~dp0sem-vigia.flag"
echo Pronto. O Windows nao vai mais abrir a limpeza sozinho.
echo O menu e o aplicar.bat continuam funcionando quando voce clicar neles.
exit /b 0

:religar_atalho
if exist "%~dp0sem-vigia.flag" del /f /q "%~dp0sem-vigia.flag" >nul 2>&1
call :criar_atalho
echo Limpeza automatica religada.
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

:vigiar
call :executar_limpeza aplicar 0 vigiar
exit /b

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
set "VIGIAR=0"
if /i "%~3"=="vigiar" set "VIGIAR=1"
set "IDADE_DOWNLOADS=2"
set "IDADE_LIXO=7"
set "IDADE_TEMP=1"
set "INTERVALO_MIN=30"
set "PASTA_LIXO=_Lixo"
set "LOG=%~dp0limpador.log"
set "PASTA_DOWNLOADS=%USERPROFILE%\Downloads"
set "PASTA_DESKTOP=%USERPROFILE%\Desktop"
for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "[Environment]::GetFolderPath('Desktop')"`) do if not "%%D"=="" set "PASTA_DESKTOP=%%D"
if "%VIGIAR%"=="1" call :registrar "Vigia ativa. Prefetch fica de fora. Proxima passagem em %INTERVALO_MIN% min."

:ciclo
set "liberados=0"
set "LIMPEZA_ERRO=0"
if "%MODO%"=="simular" call :registrar "Simulacao. Nada sera movido. Use aplicar para valer."
call :organizar_pasta "%PASTA_DOWNLOADS%" "Downloads"
if errorlevel 1 set "LIMPEZA_ERRO=1"
call :organizar_pasta "%PASTA_DESKTOP%" "Area de trabalho"
if errorlevel 1 set "LIMPEZA_ERRO=1"
call :limpar_sistema
call :mostrar_total
if "%VIGIAR%"=="0" goto fim_limpeza
set /a "ESPERA=INTERVALO_MIN*60"
timeout /t %ESPERA% /nobreak >nul
goto ciclo

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
