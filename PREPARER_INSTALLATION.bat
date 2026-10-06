@echo off
:: A lancer sur un PC AVEC internet (ce PC de developpement) : cree sur le Bureau le dossier
:: LCC_SENTINEL_4, pret a copier sur cle USB puis sur le PC serveur du bord (installation sans internet).
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0lanceur\lcc.ps1" -Action Preparer
echo.
pause
