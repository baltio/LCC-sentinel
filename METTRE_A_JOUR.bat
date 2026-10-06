@echo off
:: MISE A JOUR du PC serveur deja installe. A lancer DEPUIS le nouveau dossier LCC_SENTINEL_4
:: (cle USB, prepare avec PREPARER_INSTALLATION.bat) : arrete le serveur, sauvegarde l'ancienne
:: version, copie la nouvelle sans toucher aux donnees en cours ni aux listes, puis relance.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0lanceur\lcc.ps1" -Action MettreAJour %*
echo.
pause
