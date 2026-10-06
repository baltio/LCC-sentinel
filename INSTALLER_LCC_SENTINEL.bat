@echo off
:: Installation UNIQUE du PC serveur : Python + modules, pare-feu, raccourci Bureau,
:: demarrage automatique du serveur a l'ouverture de session Windows.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0lanceur\lcc.ps1" -Action Installer
echo.
pause
