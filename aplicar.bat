@echo off
cd /d "%~dp0"
if not exist "%~dp0manutencao.bat" (
    echo Nao achei o manutencao.bat nesta pasta.
    pause
    exit /b 1
)
call "%~dp0manutencao.bat" tudo
