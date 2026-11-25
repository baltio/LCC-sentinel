@echo off
:: Ouvre la CONSOLE du serveur (etat, IP a donner aux tablettes, postes connectes, journal).
:: Le serveur tourne en fenetre cachee : c'est ici qu'on le "voit". Le demarre si besoin.
:: (Meme chose que le raccourci Bureau "LCC SERVEUR - Console".)
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0lanceur\lcc.ps1" -Action Console
