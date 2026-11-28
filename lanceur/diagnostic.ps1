<#
=================================================================
  LCC SENTINEL 4 - Diagnostic du serveur
  Rassemble dans DIAGNOSTIC_LCC_SENTINEL.txt (Bureau) tout ce qu'il faut pour comprendre
  pourquoi le serveur ne demarre pas : dossier installe, Python et modules, ports occupes,
  processus, journaux, puis un ESSAI de demarrage du serveur sur des ports de test (18765 /
  18080) qui capture le message d'erreur exact. Ne modifie rien dans l'installation ; les
  codes PIN ne sont PAS recopies dans le rapport.
  Usage : DIAGNOSTIC_SERVEUR.bat (ou -Cible <dossier installe>)
=================================================================
#>
param([string]$Cible = '')
$ErrorActionPreference = 'Continue'
$rapport = Join-Path ([Environment]::GetFolderPath('Desktop')) 'DIAGNOSTIC_LCC_SENTINEL.txt'
$L = New-Object System.Collections.Generic.List[string]
function W([string]$t) { $L.Add($t) }
function Titre([string]$t) { W ''; W ('=' * 72); W "  $t"; W ('=' * 72) }
function Essai([scriptblock]$b) { try { & $b } catch { W "  (erreur : $($_.Exception.Message))" } }

Write-Host ''
Write-Host '  Diagnostic LCC SENTINEL 4 en cours (environ 30 secondes)...'

Titre 'PC'
W "Date        : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
W "Utilisateur : $env:USERNAME   PC : $env:COMPUTERNAME"
Essai { W "Windows     : $((Get-CimInstance Win32_OperatingSystem).Caption) $((Get-CimInstance Win32_OperatingSystem).Version)" }

# -- Dossier installe -----------------------------------------------------------
$candidats = New-Object System.Collections.Generic.List[string]
if ($Cible) { $candidats.Add($Cible) }
foreach ($bureau in @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('CommonDesktopDirectory'))) {
    $lnk = Join-Path $bureau 'LCC SENTINEL 4.lnk'
    if (Test-Path -LiteralPath $lnk) {
        Essai { $candidats.Add((New-Object -ComObject WScript.Shell).CreateShortcut($lnk).WorkingDirectory) }
    }
}
$candidats.Add('C:\LCC_SENTINEL_4')
$candidats.Add((Split-Path -Parent $PSScriptRoot))
$dossier = $null
foreach ($c in $candidats) { if ($c -and (Test-Path -LiteralPath (Join-Path $c 'sentinel_server.py'))) { $dossier = $c; break } }

Titre 'LOGICIEL INSTALLE'
W "Dossiers essayes : $($candidats -join ' | ')"
if (-not $dossier) {
    W 'AUCUN dossier contenant sentinel_server.py trouve.'
} else {
    W "Dossier : $dossier"
    $html = Join-Path $dossier 'LCC sentinel 4.html'
    if (Test-Path -LiteralPath $html) {
        $m = Select-String -LiteralPath $html -Pattern 'SENTINEL v(\d+\.\d+\.\d+)' -List
        if ($m) { W "Version (page) : $($m.Matches[0].Groups[1].Value)" }
    }
    foreach ($f in 'sentinel_server.py', 'LCC sentinel 4.html', 'LCC OSC.html', 'sw.js', 'lanceur\lcc.ps1', 'ssl_cert.pem', 'sentinel_state.json', 'CODES_PIN_POSTES_LCC_SENTINEL.json') {
        $p = Join-Path $dossier $f
        if (Test-Path -LiteralPath $p) { $i = Get-Item -LiteralPath $p; W ("  {0,-38} {1,10} octets  {2:yyyy-MM-dd HH:mm}" -f $f, $i.Length, $i.LastWriteTime) }
        else { W ("  {0,-38} ABSENT" -f $f) }
    }
    Essai {
        $test = Join-Path $dossier '_test_ecriture_diag.tmp'
        Set-Content -LiteralPath $test -Value 'x' -ErrorAction Stop; Remove-Item -LiteralPath $test
        W 'Ecriture dans le dossier : OK'
    }
}
$data = Join-Path $env:LOCALAPPDATA 'LCC_Sentinel'
W "Ancien fichier PIN (%LOCALAPPDATA%) : $(if (Test-Path (Join-Path $data 'pins.json')) {'present'} else {'absent'})"
W "Drapeau ARRET_DEMANDE : $(if (Test-Path (Join-Path $data 'ARRET_DEMANDE')) {'PRESENT'} else {'absent'})"

# -- Python (meme recherche que le lanceur) -------------------------------------
Titre 'PYTHON'
Essai { W 'py -0p :'; (& py -0p 2>&1) | ForEach-Object { W "  $_" } }
Essai { foreach ($cmd in @(Get-Command python -All -ErrorAction SilentlyContinue)) { W "python dans le PATH : $($cmd.Source)" } }
$py = $null
if ($env:LCC_PYTHON -and (Test-Path $env:LCC_PYTHON)) { $py = $env:LCC_PYTHON }
if (-not $py) { try { $p = & py -3 -c "import sys; print(sys.executable)" 2>$null; if ($LASTEXITCODE -eq 0 -and $p) { $py = $p.Trim() } } catch {} }
if (-not $py) { foreach ($cmd in @(Get-Command python -All -ErrorAction SilentlyContinue)) { if ($cmd.Source -notmatch 'WindowsApps') { $py = $cmd.Source; break } } }
if (-not $py) { foreach ($v in '313', '312', '311', '310', '314') { foreach ($p in "$env:LOCALAPPDATA\Programs\Python\Python$v\python.exe", "C:\Python$v\python.exe", "C:\Program Files\Python$v\python.exe") { if (-not $py -and (Test-Path $p)) { $py = $p } } } }
W "Python choisi par le lanceur : $py"
if ($py) {
    Essai { W "Version : $((& $py --version 2>&1) -join ' ')" }
    foreach ($mod in 'websockets', 'cryptography') {
        $r = & $py -c "import $mod; print($mod.__version__)" 2>&1
        W ("Module {0,-13}: {1}" -f $mod, $(if ($LASTEXITCODE -eq 0) { $r -join ' ' } else { 'ABSENT -> ' + (($r | Select-Object -Last 1) -join ' ') }))
    }
}

# -- Ports ----------------------------------------------------------------------
Titre 'PORTS (8765 WebSocket, 8080 HTTP, 8081 / 8764 locaux)'
foreach ($port in 8765, 8080, 8081, 8764) {
    $c = @(Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue)
    if (-not $c.Count) { W "  $port : libre"; continue }
    foreach ($x in $c) {
        $pr = Get-CimInstance Win32_Process -Filter "ProcessId=$($x.OwningProcess)" -ErrorAction SilentlyContinue
        W "  $port : OCCUPE par PID $($x.OwningProcess) $($pr.Name) - $($pr.CommandLine)"
    }
}

Titre 'PROCESSUS LCC EN COURS'
$procs = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match 'sentinel_server|lcc\.ps1' -and $_.CommandLine -notmatch 'diagnostic\.ps1' })
if (-not $procs.Count) { W '  aucun' }
foreach ($p in $procs) { W "  PID $($p.ProcessId) $($p.Name) : $($p.CommandLine)" }

# -- Journaux -------------------------------------------------------------------
$logs = Join-Path $data 'logs'
Titre 'JOURNAL DU LANCEUR (60 dernieres lignes)'
$lj = Join-Path $logs 'lanceur.log'
if (Test-Path $lj) { Get-Content $lj -Tail 60 | ForEach-Object { W "  $_" } } else { W "  absent ($lj)" }
Titre 'JOURNAL DU SERVEUR (dernier fichier, 150 dernieres lignes)'
$ls = Get-ChildItem $logs -Filter 'serveur_*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($ls) { W "  Fichier : $($ls.FullName)"; Get-Content $ls.FullName -Tail 150 | ForEach-Object { W "  $_" } } else { W "  aucun serveur_*.log dans $logs" }

# -- Essai de demarrage (ports de test, PIN et etat temporaires) -----------------
Titre 'ESSAI DE DEMARRAGE DU SERVEUR (ports de test 18765 / 18080, 12 secondes)'
if ($dossier -and $py) {
    $tmp = Join-Path $env:TEMP 'lcc_diag'
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    $o = Join-Path $tmp 'sortie.txt'; $e = Join-Path $tmp 'erreurs.txt'
    Remove-Item $o, $e -ErrorAction SilentlyContinue
    $arg = "-u sentinel_server.py --no-pause --port 18765 --http-port 18080 --local-http-port 18081 --local-port 18764 " +
           "--state-file `"$tmp\etat.json`""
    # --pins-file n'existe qu'a partir de v2.0.42 : sur une version plus ancienne, l'ajouter faisait
    # echouer l'essai (« unrecognized arguments ») alors que le serveur demarre normalement.
    if (Select-String -LiteralPath (Join-Path $dossier 'sentinel_server.py') -Pattern '--pins-file' -SimpleMatch -Quiet) {
        $arg += " --pins-file `"$tmp\pins.json`""
    } else {
        W '  (version sans --pins-file : PIN de test non isoles, aucun fichier PIN n''est ecrit par cette version)'
    }
    try {
        $proc = Start-Process -FilePath $py -ArgumentList $arg -WorkingDirectory $dossier -WindowStyle Hidden `
            -RedirectStandardOutput $o -RedirectStandardError $e -PassThru
        $ok = $false
        for ($i = 0; $i -lt 24 -and -not $proc.HasExited; $i++) {
            Start-Sleep -Milliseconds 500
            try { if ((Invoke-WebRequest -Uri 'http://127.0.0.1:18081/api/server-info' -UseBasicParsing -TimeoutSec 1).StatusCode -eq 200) { $ok = $true; break } } catch {}
        }
        if ($ok) { W '  RESULTAT : le serveur DEMARRE correctement sur les ports de test.' }
        elseif ($proc.HasExited) { W "  RESULTAT : le serveur s'est ARRETE tout seul (code $($proc.ExitCode))." }
        else { W '  RESULTAT : le serveur tourne mais ne repond pas.' }
        if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
    } catch { W "  Impossible de lancer Python : $($_.Exception.Message)" }
    Start-Sleep -Milliseconds 500
    W '  --- sortie ---'; if (Test-Path $o) { Get-Content $o | ForEach-Object { W "  $_" } }
    W '  --- erreurs ---'; if (Test-Path $e) { Get-Content $e | ForEach-Object { W "  $_" } }
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
} else {
    W '  Essai impossible : dossier du logiciel ou Python introuvable (voir plus haut).'
}

$L | Set-Content -LiteralPath $rapport -Encoding UTF8
Write-Host ''
Write-Host "  Rapport cree : $rapport" -ForegroundColor Green
Write-Host '  Envoyez ce fichier (ou copiez son contenu).'
Start-Process notepad.exe -ArgumentList "`"$rapport`""
