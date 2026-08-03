# ============================================================
#  CHARCOT SENTINEL - Sauvegarde et gestion de version
#  Usage : .\SAVE_VERSION.ps1 [-Bump patch|minor|major] [-Message "description"]
#  Exemples :
#    .\SAVE_VERSION.ps1                            -> patch  v2.0.0 -> v2.0.1
#    .\SAVE_VERSION.ps1 -Bump minor               -> minor  v2.0.0 -> v2.1.0
#    .\SAVE_VERSION.ps1 -Bump major -Message "OSC" -> v3.0.0
# ============================================================

param(
    [ValidateSet("patch", "minor", "major")]
    [string]$Bump = "patch",
    [string]$Message = ""
)

$ErrorActionPreference = "Stop"

$MainFile    = Join-Path $PSScriptRoot "LCC sentinel 3.html"
$SourceFile  = Join-Path $PSScriptRoot "Source\index.html"
$VersionsDir = Join-Path $PSScriptRoot "versions"

# Modules annexes archives a chaque sauvegarde (pas de version a incrementer
# dedans, juste un instantane horodate aligne sur la version du module principal)
$CompanionFiles = @(
    @{ Path = "manifest.json";               Prefix = "manifest" },
    @{ Path = "sw.js";                       Prefix = "sw" },
    @{ Path = "sentinel_server.py";          Prefix = "sentinel_server" },
    @{ Path = "LCC Sentinel Mustering.html"; Prefix = "LCC_Sentinel_Mustering" },
    @{ Path = "manifest-mustering.json";     Prefix = "manifest-mustering" },
    @{ Path = "sw-mustering.js";             Prefix = "sw-mustering" }
)

function OK   { param($t) Write-Host "  [OK] $t" -ForegroundColor Green  }
function WARN { param($t) Write-Host "  [!]  $t" -ForegroundColor Yellow }
function ERR  { param($t) Write-Host "  [X]  $t" -ForegroundColor Red    }
function HDR  { param($t) Write-Host "" ; Write-Host $t -ForegroundColor Cyan }

HDR "=================================================="
HDR " CHARCOT SENTINEL - Sauvegarde de version"
HDR "=================================================="

if (-not (Test-Path $MainFile)) {
    ERR "Fichier introuvable : $MainFile"
    exit 1
}

$rawContent = Get-Content $MainFile -Raw -Encoding UTF8

if ($rawContent -notmatch 'CHARCOT SENTINEL v(\d+)\.(\d+)\.(\d+)-charcot') {
    ERR "Impossible de detecter la version dans $MainFile"
    ERR "Format attendu : CHARCOT SENTINEL vX.Y.Z-charcot"
    exit 1
}

$major = [int]$Matches[1]
$minor = [int]$Matches[2]
$patch_ = [int]$Matches[3]
$oldVer = "$major.$minor.$patch_"

Write-Host "  Version actuelle : v$oldVer-charcot" -ForegroundColor Yellow

switch ($Bump) {
    "major" { $major++; $minor = 0; $patch_ = 0 }
    "minor" { $minor++;             $patch_ = 0 }
    "patch" { $patch_++ }
}
$newVer = "$major.$minor.$patch_"

Write-Host "  Nouveau numero   : v$newVer-charcot" -ForegroundColor Green

if (-not (Test-Path $VersionsDir)) {
    New-Item -ItemType Directory -Path $VersionsDir | Out-Null
    OK "Dossier 'versions/' cree"
}

HDR "  Archivage..."

$timestamp   = Get-Date -Format "yyyy-MM-dd_HHmm"
$noteSuffix  = if ($Message) { "_" + ($Message -replace '[^\w]','-').Substring(0, [Math]::Min($Message.Length,30)) } else { "" }
$archiveName = "LCC_sentinel_v${oldVer}_${timestamp}${noteSuffix}.html"
$archivePath = Join-Path $VersionsDir $archiveName

Copy-Item $MainFile $archivePath
OK "Archive : versions\$archiveName"

if (Test-Path $SourceFile) {
    $srcArchive = Join-Path $VersionsDir "source_index_v${oldVer}_${timestamp}.html"
    Copy-Item $SourceFile $srcArchive
    OK "Archive source : versions\source_index_v${oldVer}_${timestamp}.html"
}

$archivedCompanions = @()
foreach ($companion in $CompanionFiles) {
    $companionPath = Join-Path $PSScriptRoot $companion.Path
    if (Test-Path $companionPath) {
        $ext = [System.IO.Path]::GetExtension($companion.Path)
        $companionArchiveName = "$($companion.Prefix)_v${oldVer}_${timestamp}${ext}"
        Copy-Item $companionPath (Join-Path $VersionsDir $companionArchiveName)
        OK "Archive : versions\$companionArchiveName"
        $archivedCompanions += $companion.Path
    } else {
        WARN "Module absent, non archive : $($companion.Path)"
    }
}

HDR "  Mise a jour de la version..."

$filesToUpdate = @($MainFile)
if (Test-Path $SourceFile) { $filesToUpdate += $SourceFile }

foreach ($file in $filesToUpdate) {
    $c = Get-Content $file -Raw -Encoding UTF8
    $e = [regex]::Escape($oldVer)
    $c = $c -replace "CHARCOT SENTINEL v${e}-charcot", "CHARCOT SENTINEL v${newVer}-charcot"
    $c = $c -replace """version"": ""${e}-charcot""", """version"": ""${newVer}-charcot"""
    $c = $c -replace "v${e}-charcot", "v${newVer}-charcot"
    Set-Content $file $c -Encoding UTF8 -NoNewline
    OK "$(Split-Path $file -Leaf) : v$oldVer -> v$newVer"
}

$logFile  = Join-Path $VersionsDir "CHANGELOG.txt"
$logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm')] v$oldVer -> v$newVer  ($Bump)"
if ($Message) { $logEntry += "  -- $Message" }
if ($archivedCompanions.Count -gt 0) { $logEntry += "  [modules: $($archivedCompanions -join ', ')]" }
Add-Content $logFile $logEntry -Encoding UTF8
OK "CHANGELOG.txt mis a jour"

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  v$oldVer -> v$newVer  ($Bump)" -ForegroundColor White
if ($Message) { Write-Host "  Note : $Message" -ForegroundColor White }
Write-Host "  Archive : versions\$archiveName" -ForegroundColor Gray
if ($archivedCompanions.Count -gt 0) {
    Write-Host "  Modules archives :" -ForegroundColor Gray
    foreach ($c in $archivedCompanions) { Write-Host "    - $c" -ForegroundColor Gray }
}
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""