@echo off
:: Cree sur le Bureau un PETIT paquet de mise a jour (ZIP d'environ 1 Mo, envoyable par mail) :
:: uniquement les fichiers de l'appli, sans les images/plans ni l'installateur Python.
:: Lancer SAVE_VERSION.ps1 AVANT, pour que les navigateurs prennent bien la nouvelle version.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0lanceur\lcc.ps1" -Action PreparerMAJ
echo.
pause
