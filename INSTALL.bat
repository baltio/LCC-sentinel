@echo off
cd /d "%~dp0"
echo.
echo  ============================================================
echo  CHARCOT SENTINEL - Installation Python + dependances
echo  LE COMMANDANT CHARCOT - PONANT
echo  ============================================================
echo.

:: ── Cherche un vrai Python (pas le stub Microsoft Store) ──
set PYTHON_EXE=
call :find_python
if defined PYTHON_EXE goto :install_deps

:: ── Python absent : installation via winget ──
echo  Python n'est pas installe. Installation automatique...
echo.
winget install Python.Python.3.12 --silent --accept-source-agreements --accept-package-agreements
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo  ERREUR : Installation automatique echouee.
    echo  Installer manuellement depuis : https://www.python.org/downloads/
    echo  Cocher l'option "Add Python to PATH" lors de l'installation.
    pause
    exit /b 1
)
echo.
echo  Python installe avec succes.

:: Rafraichit le PATH utilisateur depuis le registre
for /f "tokens=2*" %%A in ('reg query "HKCU\Environment" /v PATH 2^>nul') do set "PATH=%PATH%;%%B"
call :find_python

:install_deps
echo.
echo  Python trouve : %PYTHON_EXE%
echo.
echo  Installation de websockets + cryptography (HTTPS)...
%PYTHON_EXE% -m pip install --upgrade pip websockets cryptography
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo  ERREUR lors de l'installation de websockets.
    pause
    exit /b 1
)
echo.
echo  ============================================================
echo  Installation terminee !
echo  Vous pouvez maintenant lancer START_SERVER.bat
echo  ============================================================
echo.
pause
exit /b 0

:: ── Sous-routine : recherche du vrai Python ──
:find_python
set PYTHON_EXE=
:: 1. Essaie le launcher py.exe (plus fiable)
py --version >nul 2>&1
if %ERRORLEVEL%==0 ( set PYTHON_EXE=py & exit /b 0 )
:: 2. Parcourt tous les chemins 'python' en evitant le stub WindowsApps
for /f "delims=" %%i in ('where python 2^>nul') do (
    echo %%i | findstr /C:"WindowsApps" >nul
    if !ERRORLEVEL! NEQ 0 ( set PYTHON_EXE=%%i & exit /b 0 )
)
:: 3. Chemins d'installation connus
for %%v in (312 311 310 39 313) do (
    if exist "%LOCALAPPDATA%\Programs\Python\Python%%v\python.exe" (
        set PYTHON_EXE=%LOCALAPPDATA%\Programs\Python\Python%%v\python.exe & exit /b 0
    )
    if exist "C:\Python%%v\python.exe" (
        set PYTHON_EXE=C:\Python%%v\python.exe & exit /b 0
    )
)
exit /b 0
