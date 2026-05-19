@echo off
:: ============================================================
::  CHARCOT SENTINEL — Restaurer une version archivée
::  Lance un menu pour choisir quelle version restaurer
:: ============================================================
chcp 65001 >nul

echo.
echo  ╔══════════════════════════════════════════════╗
echo  ║  CHARCOT SENTINEL — Restauration de version  ║
echo  ╚══════════════════════════════════════════════╝
echo.

set VERSIONS_DIR=%~dp0versions

if not exist "%VERSIONS_DIR%" (
    echo  ⚠  Aucun dossier 'versions' trouvé. Commencez par faire une sauvegarde.
    echo.
    pause
    exit /b
)

echo  Archives disponibles :
echo  ─────────────────────────────────────────────
dir /b /o-d "%VERSIONS_DIR%\LCC_sentinel_v*.html" 2>nul
echo  ─────────────────────────────────────────────
echo.
echo  Consultez le fichier versions\CHANGELOG.txt pour l'historique.
echo.
echo  Pour restaurer manuellement :
echo    1. Ouvrez le dossier  versions\
echo    2. Copiez le fichier souhaité dans le dossier racine
echo    3. Renommez-le "LCC sentinel 3.html"
echo.
echo  ATTENTION : la version actuelle sera écrasée.
echo  Faites une sauvegarde avant si nécessaire (SAVE_VERSION.bat).
echo.

set /P CHOICE="  Nom exact du fichier à restaurer (ou Entrée pour annuler) : "
if "%CHOICE%"=="" (
    echo  Annulé.
    pause
    exit /b
)

if not exist "%VERSIONS_DIR%\%CHOICE%" (
    echo  ❌ Fichier introuvable : %CHOICE%
    pause
    exit /b
)

:: Sauvegarder la version actuelle avant d'écraser
echo.
echo  Sauvegarde de la version actuelle avant restauration...
powershell -ExecutionPolicy Bypass -File "%~dp0SAVE_VERSION.ps1" -Bump patch -Message "auto-backup-before-restore"

echo.
echo  Restauration en cours...
copy /Y "%VERSIONS_DIR%\%CHOICE%" "%~dp0LCC sentinel 3.html" >nul
echo  ✅ Restauré : %CHOICE%
echo     → LCC sentinel 3.html
echo.
pause
