@echo off
:: ============================================================
::  CHARCOT SENTINEL — Sauvegarde rapide (patch +1)
::  Double-cliquez pour sauvegarder et incrémenter la version
:: ============================================================
chcp 65001 >nul

echo.
echo  ╔══════════════════════════════════════════════╗
echo  ║   CHARCOT SENTINEL — Sauvegarde de version   ║
echo  ╚══════════════════════════════════════════════╝
echo.

:: Demande d'une note optionnelle
set /P NOTE="  Description de la modification (Entrée pour ignorer) : "

echo.

:: Lance le script PowerShell
if "%NOTE%"=="" (
    powershell -ExecutionPolicy Bypass -File "%~dp0SAVE_VERSION.ps1" -Bump patch
) else (
    powershell -ExecutionPolicy Bypass -File "%~dp0SAVE_VERSION.ps1" -Bump patch -Message "%NOTE%"
)

echo.
pause
