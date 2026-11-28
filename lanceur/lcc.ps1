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
    -Action MettreAJour  A lancer DEPUIS le nouveau dossier prepare (cle USB) sur le PC serveur deja
                       installe : arrete le serveur, sauvegarde l'ancienne version, copie la nouvelle
                       (sans toucher a l'etat en cours, au certificat ni aux listes), relance.
                       -> METTRE_A_JOUR.bat
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
    [ValidateSet('Lancer', 'Serveur', 'Arreter', 'Installer', 'Preparer', 'MettreAJour', 'PreparerMAJ', 'Console', 'ApresMAJ')]
    [string]$Action = 'Lancer',
    [string]$Cible = '',
    [switch]$SansRelance,  # MettreAJour : ne pas redemarrer le serveur / ouvrir l'appli a la fin   # MettreAJour : dossier installe (par defaut : celui du raccourci Bureau, sinon C:\LCC_SENTINEL_4)
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
# Fichiers de l'appli (racine) copies par Preparer (dossier complet) et PreparerMAJ (petit paquet ZIP).
$FichiersAppli = @('index.html', 'LCC sentinel 4.html', 'LCC sentinel 3.html', 'LCC OSC.html', 'LCC Sentinel Mustering.html',
                   'console_serveur.html',
                   'manifest.json', 'manifest-osc.json', 'manifest-mustering.json',
                   'sw.js', 'sw-osc.js', 'sw-mustering.js', 'sentinel_server.py',
                   'INSTALLER_LCC_SENTINEL.bat', 'LANCER_LCC_SENTINEL.bat', 'ARRETER_SERVEUR.bat', 'METTRE_A_JOUR.bat',
                   'CONSOLE_SERVEUR.bat', 'DIAGNOSTIC_SERVEUR.bat',
                   'LISEZ-MOI_INSTALLATION.txt')

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

# Console du serveur (console_serveur.html) : le serveur tourne en fenetre cachee — cette page montre
# s'il tourne, l'IP a donner aux tablettes, les postes connectes et le journal. Demarre le serveur si besoin.
function Invoke-Console {
    if (-not (Test-ServeurPret)) {
        Start-Surveillance
        $limite = (Get-Date).AddSeconds(30)
        while (-not (Test-ServeurPret) -and (Get-Date) -lt $limite) { Start-Sleep -Milliseconds 500 }
    }
    $nav = Find-Navigateur
    if (-not $nav) { Show-Message 'Ni Google Chrome ni Microsoft Edge ne sont installes.' 'Error'; return }
    # La page affiche d'elle-meme « HORS SERVICE » + la marche a suivre si le serveur n'a pas demarre.
    Start-Process -FilePath $nav -ArgumentList @("--app=http://localhost:$LocalHttpPort/console_serveur.html", '--window-size=1200,800')
    Write-Journal 'Console serveur ouverte'
}

function New-RaccourciConsole([string]$script, [string]$dossier) {
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'LCC SERVEUR - Console.lnk'))
    $lnk.TargetPath = 'powershell.exe'
    $lnk.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`" -Action Console"
    $lnk.WorkingDirectory = $dossier
    $lnk.WindowStyle = 7
    $ico = Join-Path $dossier 'assets\img\general\LOGO_CC_RGBv2.ico'
    if (Test-Path $ico) { $lnk.IconLocation = $ico }
    $lnk.Description = 'Etat du serveur LCC SENTINEL : IP, postes connectes, journal'
    $lnk.Save()
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
    # DriveInfo refuse les chemins reseau (\\serveur\partage) : les traiter comme "pas un disque local".
    $racine = [System.IO.Path]::GetPathRoot($Root)
    try { $typeLecteur = [System.IO.DriveInfo]::new($racine).DriveType } catch { $typeLecteur = 'Network' }
    if ($typeLecteur -ne 'Fixed') {
        Write-Host "  Ce dossier est sur un lecteur amovible ou reseau ($racine)." -ForegroundColor Red
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
    New-RaccourciConsole $PSCommandPath $Root
    Write-Host "  [4/5] Raccourcis Bureau crees : LCC SENTINEL 4 + LCC SERVEUR - Console" -ForegroundColor Green

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

function Get-VersionLogiciel([string]$dossier) {
    $html = Join-Path $dossier 'LCC sentinel 4.html'
    if (-not (Test-Path -LiteralPath $html)) { return '?' }
    $m = Select-String -LiteralPath $html -Pattern 'CHARCOT SENTINEL v(\d+\.\d+\.\d+)-charcot' | Select-Object -First 1
    if ($m) { return $m.Matches[0].Groups[1].Value } else { return '?' }
}

function Invoke-MettreAJour {
    Write-Host ''
    Write-Host '  ============================================================'
    Write-Host '  LCC SENTINEL 4 - Mise a jour du PC serveur'
    Write-Host '  ============================================================'
    Write-Host ''
    # 1. Ou est installe le logiciel ? Le raccourci Bureau cree par l'installateur pointe dessus.
    $cible = $Cible
    if (-not $cible) {
        $lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'LCC SENTINEL 4.lnk'
        if (Test-Path -LiteralPath $lnk) { $cible = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk).WorkingDirectory }
    }
    if (-not $cible) { $cible = 'C:\LCC_SENTINEL_4' }
    if (-not (Test-Path -LiteralPath (Join-Path $cible 'sentinel_server.py'))) {
        Write-Host "  Aucune installation trouvee ($cible)." -ForegroundColor Red
        Write-Host '  Pour une premiere installation : copier ce dossier sur C:\ puis lancer INSTALLER_LCC_SENTINEL.bat.'
        return
    }
    $source = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')
    $cible = (Resolve-Path -LiteralPath $cible).Path.TrimEnd('\')
    if ($source -eq $cible) {
        Write-Host '  Lancez METTRE_A_JOUR.bat depuis le NOUVEAU dossier (cle USB), pas depuis le logiciel installe.' -ForegroundColor Red
        return
    }
    $vAvant = Get-VersionLogiciel $cible
    $vApres = Get-VersionLogiciel $source
    Write-Host "  Logiciel installe : $cible  (version $vAvant)"
    Write-Host "  Nouvelle version  : $source  (version $vApres)"
    Write-Host ''
    # Paquet plus ANCIEN que l'installation (ancien ZIP reste sur la cle USB...) : demander confirmation.
    try { $plusAncien = ([version]$vApres) -lt ([version]$vAvant) } catch { $plusAncien = $false }
    if ($plusAncien) {
        Write-Host "  ATTENTION : ce dossier contient une version PLUS ANCIENNE ($vApres) que celle installee ($vAvant)." -ForegroundColor Red
        $rep = Read-Host '  Revenir quand meme a cette ancienne version ? (O/N)'
        if ($rep -notmatch '^[oOyY]') { Write-Host '  Mise a jour annulee.' -ForegroundColor Yellow; return }
    }

    # 2. Arret du serveur (et de sa relance automatique)
    Write-Host '  [1/5] Arret du serveur...'
    Invoke-Arreter
    Start-Sleep -Seconds 3

    # 3. Sauvegarde des fichiers du logiciel actuel (pas assets/ : volumineux et non modifies par
    #    l'utilisateur) -> retour arriere possible en recopiant ce dossier sur l'installation.
    $sauvegarde = Join-Path $DataDir ('sauvegardes\v{0}_{1:yyyy-MM-dd_HHmm}' -f $vAvant, (Get-Date))
    & robocopy $cible $sauvegarde *.html *.json *.js *.py *.bat *.txt /NFL /NDL /NJH /NJS /NP | Out-Null
    & robocopy (Join-Path $cible 'lanceur') (Join-Path $sauvegarde 'lanceur') /E /NFL /NDL /NJH /NJS /NP | Out-Null
    Write-Host "  [2/5] Ancienne version sauvegardee : $sauvegarde" -ForegroundColor Green

    # 4. Copie. Le dossier prepare ne contient NI sentinel_state.json (etat / croisiere en cours), NI
    #    ssl_*.pem (certificat deja accepte par les tablettes), NI lists_data/ : ils restent intacts.
    #    Pas de /MIR : rien n'est supprime dans l'installation.
    & robocopy $source $cible /E /XF sentinel_state*.json ssl_*.pem CODES_PIN_POSTES_LCC_SENTINEL.json pins.json /XD lists_data /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) {
        Write-Host "  [3/5] ERREUR de copie (code robocopy $LASTEXITCODE). Ancienne version dans : $sauvegarde" -ForegroundColor Red
        return
    }
    # Un ZIP recu par mail marque chaque fichier « provient d'internet » : retirer cette marque des
    # fichiers installes, sinon Windows avertit (ou bloque) a chaque lancement des .bat / .ps1.
    Get-ChildItem -LiteralPath $cible -Recurse -File -Include *.bat, *.ps1, *.html, *.js, *.py -ErrorAction SilentlyContinue |
        Unblock-File -ErrorAction SilentlyContinue
    Write-Host '  [3/5] Nouvelle version copiee' -ForegroundColor Green
    # Raccourci de la console serveur (ajoute en v2.0.40) : aussi sur les PC deja installes.
    try { New-RaccourciConsole (Join-Path $cible 'lanceur\lcc.ps1') $cible } catch {}

    # 5. Modules Python (sans internet, depuis le dossier prepare) — sans effet s'ils sont deja a jour.
    $py = Find-Python
    $wheels = Join-Path $source 'installation\wheels'
    if ($py -and (Test-Path -LiteralPath $wheels)) {
        & $py -m pip install --quiet --no-index --find-links $wheels websockets cryptography 2>$null
    }
    Write-Host '  [4/5] Modules Python verifies' -ForegroundColor Green

    # 6. Relance via le lanceur INSTALLE (serveur + application)
    if ($SansRelance) {
        Write-Host '  [5/5] Serveur laisse arrete (-SansRelance) : relancer avec l''icone LCC SENTINEL 4.' -ForegroundColor Yellow
    } else {
    Write-Host '  [5/5] Redemarrage du serveur et ouverture de l''application...'
    Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden',
        '-File', "`"$(Join-Path $cible 'lanceur\lcc.ps1')`"", '-Action', 'Lancer')
    }
    Write-Journal "Mise a jour $vAvant -> $vApres depuis $source"
    Write-Host ''
    Write-Host "  Mise a jour terminee : version $vAvant -> $vApres" -ForegroundColor Green
    Write-Host '  Les tablettes recoivent la nouvelle version en rechargeant la page (ou au prochain lancement).'
}

function Invoke-PreparerMAJ {
    # Petit paquet de mise a jour envoyable par mail : uniquement les fichiers de l'appli et du
    # lanceur (~1 Mo zippe). PAS assets/ (images, plans ~190 Mo), PAS installation/ (Python ~40 Mo),
    # PAS Source/ : ils restent tels quels sur le PC serveur (METTRE_A_JOUR ne copie que ce que le
    # paquet contient, sans rien supprimer). Si des images / plans ont change : dossier complet (Preparer).
    $version = Get-VersionLogiciel $Root
    Write-Host ''
    Write-Host "  Paquet de mise a jour LCC SENTINEL 4 - version $version"
    Write-Host ''
    # Version deja empaquetee ? Sans SAVE_VERSION, sw.js ne change pas et les navigateurs (PC serveur,
    # tablettes) garderaient l'ancienne appli en cache malgre la mise a jour.
    $memo = Join-Path $DataDir 'derniere_maj.txt'
    $derniere = if (Test-Path $memo) { (Get-Content $memo -Raw).Trim() } else { '' }
    if ($derniere -eq $version) {
        Write-Host "  ATTENTION : un paquet v$version a deja ete prepare." -ForegroundColor Yellow
        Write-Host '  Si le logiciel a ete modifie depuis, lancez d''abord SAVE_VERSION.ps1 (nouvelle version),' -ForegroundColor Yellow
        Write-Host '  sinon le PC serveur et les tablettes garderont l''ancienne version en memoire.' -ForegroundColor Yellow
        Write-Host ''
    }
    $nom = "LCC_SENTINEL_4_MAJ_v$version"
    $staging = Join-Path $env:TEMP $nom
    $zip = Join-Path ([Environment]::GetFolderPath('Desktop')) "$nom.zip"
    if (Test-Path $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $staging | Out-Null
    foreach ($f in $FichiersAppli) { Copy-Item -LiteralPath (Join-Path $Root $f) -Destination $staging }
    & robocopy (Join-Path $Root 'lanceur') (Join-Path $staging 'lanceur') /E /NFL /NDL /NJH /NJS /NP | Out-Null
    # Polices embarquees : petites, et necessaires si une ancienne installation ne les a pas encore.
    & robocopy (Join-Path $Root 'assets\fonts') (Join-Path $staging 'assets\fonts') /E /NFL /NDL /NJH /NJS /NP | Out-Null
    if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
    Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $zip
    Remove-Item -LiteralPath $staging -Recurse -Force
    Set-Content -Path $memo -Value $version -Encoding ASCII
    $taille = (Get-Item -LiteralPath $zip).Length / 1MB
    Write-Host ("  Paquet cree ({0:N1} Mo) : {1}" -f $taille, $zip) -ForegroundColor Green
    Write-Host ''
    Write-Host '  Sur le PC serveur : LCC SENTINEL 4 > CONFIG > onglet MISE A JOUR,'
    Write-Host '  puis choisir ce fichier ZIP (sans l''extraire).'
    Write-Host '  (Ou : clic droit sur le ZIP > Extraire tout, puis METTRE_A_JOUR.bat dans le dossier extrait.)'
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
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    foreach ($f in $FichiersAppli) { Copy-Item -LiteralPath (Join-Path $Root $f) -Destination $Destination }
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
        'MettreAJour' { Invoke-MettreAJour }
        'PreparerMAJ' { Invoke-PreparerMAJ }
        'Console'   { Invoke-Console }
        # Lance par sentinel_server.py apres une mise a jour faite depuis l'appli (Settings > Mise a jour) :
        # etapes propres a ce PC que la copie de fichiers ne fait pas (raccourcis...).
        'ApresMAJ'  { New-RaccourciConsole $PSCommandPath $Root; Write-Journal 'Mise a jour depuis l''appli : etapes du lanceur faites' }
    }
} catch {
    Write-Journal "ERREUR ($Action): $_"
    if ($Action -ne 'Serveur') { Show-Message "Erreur inattendue :`n$_`n`nJournal : $LogDir" 'Error' }
}
