@echo off
:: Diagnostic du serveur LCC SENTINEL 4 : cree DIAGNOSTIC_LCC_SENTINEL.txt sur le Bureau (Python,
:: modules, ports, journaux, essai de demarrage). Ne modifie rien. A lancer sur le PC serveur, depuis
:: le dossier du logiciel ou depuis une cle USB.
if exist "%~dp0lanceur\diagnostic.ps1" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0lanceur\diagnostic.ps1" %*
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0diagnostic.ps1" %*
)
echo.
pause
