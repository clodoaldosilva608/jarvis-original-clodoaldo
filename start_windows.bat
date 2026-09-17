@echo off
REM ============================================================
REM  DEVFACTORY - launcher de um clique (Windows)
REM  Delega tudo ao bootstrap.ps1: instala Python/dependencias
REM  se faltar e executa o assistente.
REM ============================================================
title DEVFACTORY
cd /d "%~dp0"
echo.
echo  [DEVFACTORY] Preparando o ambiente (instalacao automatica na primeira vez)...
echo.
"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0bootstrap.ps1"
