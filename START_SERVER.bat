@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0"

:: ── Vérifie les droits Administrateur (nécessaires pour le pare-feu) ──
net session >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo  Relancement en Administrateur pour configurer le pare-feu...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo.
echo  ============================================================
echo  CHARCOT SENTINEL - Serveur WebSocket
echo  LE COMMANDANT CHARCOT - PONANT
echo  ============================================================
echo.

:: ── Ouverture des ports dans le pare-feu Windows ──
echo  Configuration du pare-feu Windows...
netsh advfirewall firewall delete rule name="Charcot Sentinel WebSocket" >nul 2>&1
netsh advfirewall firewall add rule name="Charcot Sentinel WebSocket" dir=in action=allow protocol=TCP localport=8765 >nul 2>&1
netsh advfirewall firewall delete rule name="Charcot Sentinel HTTP" >nul 2>&1
netsh advfirewall firewall add rule name="Charcot Sentinel HTTP" dir=in action=allow protocol=TCP localport=8080 >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo  Pare-feu OK : ports 8765 ^(WebSocket^) et 8080 ^(HTTP^) ouverts
) else (
    echo  ATTENTION : Echec configuration pare-feu. Connexions reseau peut-etre bloquees.
)
echo.

:: ── Localise le vrai Python (evite le stub Microsoft Store) ──
set PYTHON_EXE=
call :find_python

if not defined PYTHON_EXE (
    echo  ERREUR : Python n'est pas installe.
    echo.
    echo  Lancez d'abord INSTALL.bat pour installer Python.
    echo.
    pause
    exit /b 1
)

echo  Python : %PYTHON_EXE%
echo.
echo  Demarrage du serveur...
echo  Appuyez sur CTRL+C pour arreter.
echo.
%PYTHON_EXE% sentinel_server.py
echo.
echo  Serveur arrete.
pause
exit /b 0

:: ── Sous-routine : recherche du vrai Python ──
:find_python
set PYTHON_EXE=
:: 1. Launcher py.exe
py --version >nul 2>&1
if %ERRORLEVEL%==0 ( set PYTHON_EXE=py & exit /b 0 )
:: 2. where python, en filtrant le stub WindowsApps
for /f "delims=" %%i in ('where python 2^>nul') do (
    echo %%i | findstr /C:"WindowsApps" >nul
    if !ERRORLEVEL! NEQ 0 ( set PYTHON_EXE=%%i & exit /b 0 )
)
:: 3. Emplacements standards
for %%v in (312 311 313 310 39) do (
    if exist "%LOCALAPPDATA%\Programs\Python\Python%%v\python.exe" (
        set PYTHON_EXE=%LOCALAPPDATA%\Programs\Python\Python%%v\python.exe & exit /b 0
    )
    if exist "C:\Python%%v\python.exe" (
        set PYTHON_EXE=C:\Python%%v\python.exe & exit /b 0
    )
)
exit /b 0
