@echo off
cd /d "%~dp0"
color 0A
title A Matrix - Aplicar tudo
if not exist "%~dp0manutencao.bat" (
    echo Nao achei o manutencao.bat nesta pasta.
    pause
    exit /b 1
)
echo.
echo  ========================================
echo   A Matrix abre o caminho completo.
echo   Sem menu. Sem perguntas.
echo  ========================================
echo.
timeout /t 2 >nul
call "%~dp0manutencao.bat" tudo
