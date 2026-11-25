@echo off
:: MISE A JOUR du PC serveur deja installe. A lancer DEPUIS le nouveau dossier (cle USB, ou ZIP de
:: mise a jour recu par mail PUIS EXTRAIT) : arrete le serveur, sauvegarde l'ancienne version, copie
:: la nouvelle sans toucher aux donnees en cours ni aux listes, puis relance.
if not exist "%~dp0lanceur\lcc.ps1" (
    echo.
    echo  Le ZIP n'a pas ete extrait.
    echo  Fermez cette fenetre, faites clic droit sur le fichier ZIP ^> "Extraire tout...",
    echo  puis double-cliquez sur METTRE_A_JOUR.bat dans le dossier extrait.
    echo.
    pause
    exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0lanceur\lcc.ps1" -Action MettreAJour %*
echo.
pause
