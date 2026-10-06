@echo off
:: Ouvre CHARCOT SENTINEL sur ce PC : demarre le serveur s'il ne tourne pas, puis ouvre l'appli connectee.
:: (Meme chose que le raccourci "LCC SENTINEL 4" du Bureau cree par INSTALLER_LCC_SENTINEL.bat)
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0lanceur\lcc.ps1" -Action Lancer
