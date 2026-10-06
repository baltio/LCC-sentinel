@echo off
:: Arrete le serveur CHARCOT SENTINEL et sa relance automatique (jusqu'au prochain lancement).
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0lanceur\lcc.ps1" -Action Arreter
echo  Serveur CHARCOT SENTINEL arrete.
timeout /t 3 >nul
