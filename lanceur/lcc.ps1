<#
=================================================================
  CHARCOT SENTINEL — Lanceur du PC serveur
  LE COMMANDANT CHARCOT — PONANT

  Actions (appelees par les .bat a la racine et les raccourcis) :
    -Action Lancer     Demarre le serveur s'il ne tourne pas, attend qu'il reponde,
                       puis ouvre l'application (fenetre d'appli Chrome/Edge) connectee.
                       -> raccourci "LCC SENTINEL 4" du Bureau
    -Action Serveur    Surveillance : lance sentinel_server.py et le RELANCE tout seul
                       s'il s'arrete (crash). Une seule instance a la fois.
                       -> raccourci du dossier Demarrage de Windows
    -Action Arreter    Arrete le serveur et sa surveillance.
    -Action Installer  Installation unique : Python + modules, pare-feu,
                       raccourci Bureau, demarrage automatique du serveur.
                       Fonctionne SANS internet si le dossier "installation" (cree par
                       -Action Preparer) est present.
    -Action Preparer   A lancer sur un PC AVEC internet : cree un dossier propre, pret a
                       copier sur le PC serveur (seulement les fichiers utiles + installateur
                       Python + modules telecharges a l'avance). -> PREPARER_INSTALLATION.bat

  L'appli est ouverte via http://localhost:8081 (acces local en clair du serveur,
  voir --local-http-port dans sentinel_server.py) : sur localhost, Chrome accepte le
  mode hors-ligne et l'installation, sans aucun avertissement de certificat.

  Journaux et fichiers propres a CE PC : %LOCALAPPDATA%\LCC_Sentinel\
  (hors OneDrive, pour que deux PC ne se marchent pas dessus).
=================================================================
#>
param(
    [ValidateSet('Lancer', 'Serveur', 'Arreter', 'Installer', 'Preparer')]
    [string]$Action = 'Lancer',
    [string]$Destination = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'LCC_SENTINEL_4')
)

# 'Continue' : sous PowerShell 5.1, 'Stop' transforme le moindre message de python/pip/winget sur
# stderr (simple avertissement) en erreur fatale. Les echecs sont testes explicitement ($LASTEXITCODE).
$ErrorActionPreference = 'Continue'
$Root      = Split-Path -Parent $PSScriptRoot
$Server    = Join-Path $Root 'sentinel_server.py'
$DataDir   = Join-Path $env:LOCALAPPDATA 'LCC_Sentinel'
$LogDir    = Join-Path $DataDir 'logs'
$StopFlag  = Join-Path $DataDir 'ARRET_DEMANDE'
$Icon      = Join-Path $Root 'assets\img\general\LOGO_CC_RGBv2.ico'
$Title     = 'LCC SENTINEL 4'
$InstDir   = Join-Path $Root 'installation'   # installateur Python + modules hors-ligne (-Action Preparer)
$PythonVersion = '3.12.10'                    # derniere 3.12 avec installateur Windows officiel

$WsPort         = 8765
$HttpPort       = 8080
$LocalHttpPort  = 8081
$LocalWsPort    = 8764
$AppUrl = "http://localhost:$LocalHttpPort/LCC%20sentinel%204.html?network=1&serverHost=localhost&serverPort=$LocalWsPort"

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Write-Journal([string]$msg) {
    $line = '{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $msg
    Add-Content -Path (Join-Path $LogDir 'lanceur.log') -Value $line -Encoding UTF8
}

function Show-Message([string]$msg, [string]$kind = 'Information') {
    Add-Type -AssemblyName System.Windows.Forms
    [void][System.Windows.Forms.MessageBox]::Show($msg, $Title, 'OK', $kind)
}

# Meme logique que INSTALL.bat / START_SERVER.bat : evite le faux python.exe du Microsoft Store.
function Find-Python {
    if ($env:LCC_PYTHON -and (Test-Path $env:LCC_PYTHON)) { return $env:LCC_PYTHON }
    try {
        $p = & py -3 -c "import sys; print(sys.executable)" 2>$null
        if ($LASTEXITCODE -eq 0 -and $p -and (Test-Path $p.Trim())) { return $p.Trim() }
    } catch {}
    foreach ($cmd in @(Get-Command python -All -ErrorAction SilentlyContinue)) {
        if ($cmd.Source -and $cmd.Source -notmatch 'WindowsApps') { return $cmd.Source }
    }
    foreach ($v in '313', '312', '311', '310', '314') {
        foreach ($p in "$env:LOCALAPPDATA\Programs\Python\Python$v\python.exe", "C:\Python$v\python.exe", "C:\Program Files\Python$v\python.exe") {
            if (Test-Path $p) { return $p }
        }
    }
    return $null
}

function Test-PythonModules([string]$py) {
    & $py -c "import websockets" 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Test-ServeurPret {
    try {
        $r = Invoke-WebRequest -Uri "http://127.0.0.1:$LocalHttpPort/api/server-info" -UseBasicParsing -TimeoutSec 2
        return ($r.StatusCode -eq 200)
    } catch { return $false }
}

function Test-PortOccupe([int]$port) {
    return [bool](Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue)
}

function Find-Navigateur {
    foreach ($p in "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
                   "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
                   "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
                   "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
                   "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") {
        if (Test-Path $p) { return $p }
    }
    return $null
}

# Lecture seule, sans droits administrateur.
function Test-ReglesParefeu {
    foreach ($nom in 'Charcot Sentinel WebSocket', 'Charcot Sentinel HTTP') {
        $r = Get-NetFirewallRule -DisplayName $nom -ErrorAction SilentlyContinue | Where-Object { $_.Enabled -eq 'True' -and $_.Action -eq 'Allow' }
        if (-not $r) { return $false }
    }
    return $true
}

# Ouvre les ports reseau aux tablettes (Wi-Fi) : demande les droits administrateur (UAC).
function Set-ReglesParefeu {
    $cmds = @(
        "netsh advfirewall firewall delete rule name=`"Charcot Sentinel WebSocket`"",
        "netsh advfirewall firewall add rule name=`"Charcot Sentinel WebSocket`" dir=in action=allow protocol=TCP localport=$WsPort profile=any",
        "netsh advfirewall firewall delete rule name=`"Charcot Sentinel HTTP`"",
        "netsh advfirewall firewall add rule name=`"Charcot Sentinel HTTP`" dir=in action=allow protocol=TCP localport=$HttpPort profile=any"
    ) -join '; '
    try {
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -Wait -WindowStyle Hidden -ArgumentList @('-NoProfile', '-Command', $cmds)
    } catch { return $false }
    return (Test-ReglesParefeu)
}

function Start-Surveillance {
    Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden',
        '-File', "`"$PSCommandPath`"", '-Action', 'Serveur')
}

# ─────────────────────────────────────────────────────────────────────────────
function Invoke-Serveur {
    # Une seule surveillance par session Windows (double-clic repete, demarrage auto + lanceur...).
    $mutex = New-Object System.Threading.Mutex($false, 'Local\LCC_Sentinel_Surveillance')
    try { $acquis = $mutex.WaitOne(0) }
    catch [System.Threading.AbandonedMutexException] { $acquis = $true }  # surveillance precedente tuee (crash)
    if (-not $acquis) { return }
    try {
        Remove-Item $StopFlag -ErrorAction SilentlyContinue
        $py = Find-Python
        if (-not $py) { Write-Journal 'ERREUR: Python introuvable — lancer INSTALLER_LCC_SENTINEL.bat'; return }
        Write-Journal "Surveillance demarree (Python: $py)"
        $echecsRapides = 0
        while (-not (Test-Path $StopFlag)) {
            if (Test-PortOccupe $WsPort) {
                # Un serveur tourne deja (ex: lance a la main par START_SERVER.bat) : ne pas en
                # demarrer un 2e, juste prendre le relais s'il s'arrete.
                Start-Sleep -Seconds 10
                continue
            }
            $log = Join-Path $LogDir ('serveur_{0:yyyy-MM-dd}.log' -f (Get-Date))
            Write-Journal 'Demarrage de sentinel_server.py'
            $debut = Get-Date
            $proc = Start-Process -FilePath 'cmd.exe' -WorkingDirectory $Root -WindowStyle Hidden -PassThru -ArgumentList `
                "/c `"`"$py`" -u sentinel_server.py --no-pause >> `"$log`" 2>&1`""
            $null = $proc.Handle   # sans cela, ExitCode reste vide une fois le processus termine
            $proc.WaitForExit()
            if (Test-Path $StopFlag) { break }
            $duree = ((Get-Date) - $debut).TotalSeconds
            Write-Journal ("Serveur arrete (code {0}, apres {1:N0}s) — relance automatique" -f $proc.ExitCode, $duree)
            # Crash en boucle (ex: port pris par un autre logiciel) : ralentir au lieu de marteler.
            if ($duree -lt 15) { $echecsRapides++ } else { $echecsRapides = 0 }
            Start-Sleep -Seconds ($(if ($echecsRapides -ge 5) { 60 } else { 3 }))
        }
        Write-Journal 'Surveillance arretee (arret demande)'
    } finally {
        $mutex.ReleaseMutex()
        # Menage : ne garder que les 30 derniers journaux journaliers.
        Get-ChildItem $LogDir -Filter 'serveur_*.log' | Sort-Object Name -Descending | Select-Object -Skip 30 |
            Remove-Item -ErrorAction SilentlyContinue
    }
}

function Invoke-Lancer {
    if (-not (Test-ServeurPret)) {
        $py = Find-Python
        if (-not $py -or -not (Test-PythonModules $py)) {
            Show-Message ("Le serveur LCC SENTINEL n'est pas encore installe sur ce PC.`n`n" +
                "Double-cliquez une fois sur INSTALLER_LCC_SENTINEL.bat dans le dossier :`n$Root") 'Warning'
            return
        }
        Start-Surveillance
        $limite = (Get-Date).AddSeconds(45)
        while (-not (Test-ServeurPret) -and (Get-Date) -lt $limite) { Start-Sleep -Milliseconds 500 }
        if (-not (Test-ServeurPret)) {
            Write-Journal 'ERREUR: serveur non pret apres 45s'
            Show-Message ("Le serveur ne repond pas.`n`nL'application va quand meme s'ouvrir : elle fonctionne " +
                "hors-ligne et se connectera automatiquement des que le serveur sera pret.`n`n" +
                "Journal : $LogDir") 'Warning'
        }
    }
    # Sans ces regles, le serveur marche sur ce PC mais les tablettes en Wi-Fi sont bloquees par
    # le pare-feu Windows, sans aucun message clair cote tablette. Une seule fois par PC.
    if (-not (Test-ReglesParefeu)) {
        Add-Type -AssemblyName System.Windows.Forms
        $rep = [System.Windows.Forms.MessageBox]::Show(
            ("Le pare-feu Windows bloque encore les tablettes (Wi-Fi) : elles ne peuvent pas joindre ce serveur.`n`n" +
             "Autoriser maintenant ? (une confirmation administrateur va s'afficher, a faire une seule fois)"),
            $Title, 'YesNo', 'Warning')
        if ($rep -eq 'Yes') {
            if (Set-ReglesParefeu) { Write-Journal 'Regles pare-feu creees' }
            else { Show-Message "Pare-feu non configure (droits administrateur refuses)." 'Warning' }
        }
    }
    $nav = Find-Navigateur
    if (-not $nav) { Show-Message 'Ni Google Chrome ni Microsoft Edge ne sont installes.' 'Error'; return }
    Start-Process -FilePath $nav -ArgumentList @("--app=$AppUrl", '--start-maximized')
    Write-Journal "Application ouverte ($nav)"
}

function Invoke-Arreter {
    New-Item -ItemType File -Force -Path $StopFlag | Out-Null
    foreach ($port in $WsPort, $LocalHttpPort) {
        Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue |
            ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
    }
    Write-Journal 'Arret du serveur demande'
}

function Invoke-Installer {
    Write-Host ''
    Write-Host '  ============================================================'
    Write-Host '  CHARCOT SENTINEL - Installation du PC serveur'
    Write-Host '  ============================================================'
    Write-Host ''

    # 1. Python
    # Depuis une cle USB, les raccourcis pointeraient vers la cle : copier d'abord le dossier sur le disque.
    $lecteur = [System.IO.DriveInfo]::new([System.IO.Path]::GetPathRoot($Root))
    if ($lecteur.DriveType -ne 'Fixed') {
        Write-Host "  Ce dossier est sur un lecteur amovible ou reseau ($($lecteur.Name))." -ForegroundColor Red
        Write-Host '  Copiez d''abord le dossier LCC_SENTINEL_4 sur le disque du PC (ex: C:\LCC_SENTINEL_4),'
        Write-Host '  puis relancez INSTALLER_LCC_SENTINEL.bat depuis la copie.'
        return
    }

    $py = Find-Python
    if (-not $py) {
        $setup = Get-ChildItem $InstDir -Filter 'python-*-amd64.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($setup) {
            Write-Host "  [1/5] Python absent : installation hors-ligne ($($setup.Name))... (1 a 3 minutes)"
            Start-Process -FilePath $setup.FullName -Wait -ArgumentList @(
                '/quiet', 'InstallAllUsers=0', 'PrependPath=1', 'Include_launcher=1', 'Include_test=0')
        } else {
            Write-Host '  [1/5] Python absent : installation par internet (winget)...'
            & winget install Python.Python.3.12 --silent --accept-source-agreements --accept-package-agreements
        }
        $py = Find-Python
        if (-not $py) {
            Write-Host '  ERREUR : installation de Python impossible.' -ForegroundColor Red
            Write-Host '  Installer Python depuis https://www.python.org/downloads/ ("Add Python to PATH"),'
            Write-Host '  puis relancer ce programme.'
            return
        }
    }
    Write-Host "  [1/5] Python : $py" -ForegroundColor Green

    # 2. Modules
    Write-Host '  [2/5] Installation des modules (websockets, cryptography)...'
    $wheels = Join-Path $InstDir 'wheels'
    if (Test-Path $wheels) {
        & $py -m pip install --quiet --no-index --find-links $wheels websockets cryptography
    } else {
        & $py -m pip install --upgrade --quiet websockets cryptography
    }
    if (-not (Test-PythonModules $py)) { Write-Host '  ERREUR : installation des modules impossible.' -ForegroundColor Red; return }
    Write-Host '  [2/5] Modules OK' -ForegroundColor Green

    # 3. Pare-feu (une seule fois, demande les droits administrateur)
    Write-Host '  [3/5] Pare-feu Windows (une fenetre de confirmation administrateur va s''afficher)...'
    if (Set-ReglesParefeu) {
        Write-Host '  [3/5] Pare-feu OK (ports 8765 et 8080 ouverts aux tablettes)' -ForegroundColor Green
    } else {
        Write-Host '  [3/5] Pare-feu NON configure (droits refuses) : les tablettes risquent d''etre bloquees.' -ForegroundColor Yellow
    }

    # 4. Raccourci Bureau
    $shell = New-Object -ComObject WScript.Shell
    $psArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    $desktop = [Environment]::GetFolderPath('Desktop')
    $lnk = $shell.CreateShortcut((Join-Path $desktop 'LCC SENTINEL 4.lnk'))
    $lnk.TargetPath = 'powershell.exe'
    $lnk.Arguments = "$psArgs -Action Lancer"
    $lnk.WorkingDirectory = $Root
    $lnk.WindowStyle = 7
    if (Test-Path $Icon) { $lnk.IconLocation = $Icon }
    $lnk.Description = 'Ouvre CHARCOT SENTINEL (demarre le serveur si besoin)'
    $lnk.Save()
    Write-Host "  [4/5] Raccourci Bureau cree : $desktop\LCC SENTINEL 4.lnk" -ForegroundColor Green

    # 5. Demarrage automatique du serveur a l'ouverture de session Windows
    $startup = [Environment]::GetFolderPath('Startup')
    $lnk = $shell.CreateShortcut((Join-Path $startup 'LCC SENTINEL - Serveur.lnk'))
    $lnk.TargetPath = 'powershell.exe'
    $lnk.Arguments = "$psArgs -Action Serveur"
    $lnk.WorkingDirectory = $Root
    $lnk.WindowStyle = 7
    if (Test-Path $Icon) { $lnk.IconLocation = $Icon }
    $lnk.Description = 'Demarre automatiquement le serveur CHARCOT SENTINEL'
    $lnk.Save()
    Write-Host '  [5/5] Serveur demarre automatiquement a chaque ouverture de session Windows' -ForegroundColor Green

    Write-Host ''
    Write-Host '  Installation terminee. Demarrage du serveur et ouverture de l''application...'
    Invoke-Lancer
}

function Invoke-Preparer {
    Write-Host ''
    Write-Host "  Preparation du dossier d'installation : $Destination"
    Write-Host ''
    if (Test-Path $Destination) {
        Write-Host "  Le dossier existe deja : supprimez-le ou choisissez un autre emplacement." -ForegroundColor Red
        return
    }
    # 1. Uniquement ce dont le logiciel a besoin pour tourner (pas l'historique versions/, les
    #    sources, .git, .venv, documents de travail...). Pas de ssl_*.pem : le serveur genere sur
    #    place un certificat avec la bonne IP. Pas de sentinel_state.json : etat vierge.
    $fichiers = @('index.html', 'LCC sentinel 4.html', 'LCC sentinel 3.html', 'LCC OSC.html', 'LCC Sentinel Mustering.html',
                  'manifest.json', 'manifest-osc.json', 'manifest-mustering.json',
                  'sw.js', 'sw-osc.js', 'sw-mustering.js', 'sentinel_server.py',
                  'INSTALLER_LCC_SENTINEL.bat', 'LANCER_LCC_SENTINEL.bat', 'ARRETER_SERVEUR.bat',
                  'LISEZ-MOI_INSTALLATION.txt')
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    foreach ($f in $fichiers) { Copy-Item -LiteralPath (Join-Path $Root $f) -Destination $Destination }
    & robocopy (Join-Path $Root 'assets') (Join-Path $Destination 'assets') /E /XF *.pdf /NFL /NDL /NJH /NJS /NP | Out-Null
    & robocopy (Join-Path $Root 'lanceur') (Join-Path $Destination 'lanceur') /E /NFL /NDL /NJH /NJS /NP | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $Destination 'Source') | Out-Null
    foreach ($f in 'crewbynumber.xls', 'paxbycabindetail.xls') {
        $src = Join-Path (Join-Path $Root 'Source') $f
        if (Test-Path $src) { Copy-Item -LiteralPath $src -Destination (Join-Path $Destination 'Source') }
    }
    Write-Host '  [1/3] Fichiers du logiciel copies' -ForegroundColor Green

    # 2. Installateur Python (pour un PC sans Python et sans internet)
    $inst = Join-Path $Destination 'installation'
    New-Item -ItemType Directory -Force -Path (Join-Path $inst 'wheels') | Out-Null
    $setupName = "python-$PythonVersion-amd64.exe"
    Write-Host "  [2/3] Telechargement de $setupName..."
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        (New-Object Net.WebClient).DownloadFile("https://www.python.org/ftp/python/$PythonVersion/$setupName", (Join-Path $inst $setupName))
        Write-Host '  [2/3] Installateur Python OK' -ForegroundColor Green
    } catch { Write-Host "  [2/3] ECHEC du telechargement de Python : $_" -ForegroundColor Red }

    # 3. Modules Python pour toutes les versions de Python que le PC serveur pourrait deja avoir
    $py = Find-Python
    if (-not $py) { Write-Host '  [3/3] Python introuvable sur CE PC : modules non telecharges.' -ForegroundColor Red; return }
    Write-Host '  [3/3] Telechargement des modules (websockets, cryptography)...'
    foreach ($v in '3.10', '3.11', '3.12', '3.13', '3.14') {
        & $py -m pip download --quiet --only-binary=:all: --platform win_amd64 --python-version $v `
            -d (Join-Path $inst 'wheels') websockets cryptography 2>$null
    }
    $n = @(Get-ChildItem (Join-Path $inst 'wheels') -Filter *.whl).Count
    Write-Host "  [3/3] $n modules telecharges" -ForegroundColor Green
    $taille = (Get-ChildItem $Destination -Recurse -File | Measure-Object Length -Sum).Sum / 1MB
    Write-Host ''
    Write-Host ("  Termine ({0:N0} Mo). Copiez le dossier entier sur une cle USB :" -f $taille) -ForegroundColor Green
    Write-Host "    $Destination"
}

# ─────────────────────────────────────────────────────────────────────────────
try {
    switch ($Action) {
        'Lancer'    { Invoke-Lancer }
        'Serveur'   { Invoke-Serveur }
        'Arreter'   { Invoke-Arreter }
        'Installer' { Invoke-Installer }
        'Preparer'  { Invoke-Preparer }
    }
} catch {
    Write-Journal "ERREUR ($Action): $_"
    if ($Action -ne 'Serveur') { Show-Message "Erreur inattendue :`n$_`n`nJournal : $LogDir" 'Error' }
}
