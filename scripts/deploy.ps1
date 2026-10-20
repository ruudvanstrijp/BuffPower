# Deploys the addon into one or more local WoW clients for testing.
#
#   .\scripts\deploy.ps1                                  # anniversary (default)
#   .\scripts\deploy.ps1 -Flavor classic_beta             # WoW Forever beta
#   .\scripts\deploy.ps1 -Flavor anniversary,classic_beta # both, for side-by-side testing
#   .\scripts\deploy.ps1 -Flavor all                      # every flavor installed
#
# The WoW install is auto-detected; override with -WowRoot or the WOW_ROOT env var.

param (
    [string[]]$Flavor = @("anniversary"),
    [string]$WowRoot
)

$ErrorActionPreference = "Stop"
$source = Resolve-Path "$PSScriptRoot/.."

# powershell -File passes "-Flavor a,b" as a single string rather than an array,
# so split it back out to accept both calling conventions.
$Flavor = $Flavor |
    ForEach-Object { $_ -split "," } |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ }

$flavorFolders = @{
    anniversary  = "_anniversary_"
    classic_beta = "_classic_beta_"
    classic_era  = "_classic_era_"
    classic      = "_classic_"
    retail       = "_retail_"
}

if (-not $WowRoot) { $WowRoot = $env:WOW_ROOT }

if (-not $WowRoot) {
    $drives = (Get-PSDrive -PSProvider FileSystem).Root
    $candidates = foreach ($d in $drives) {
        Join-Path $d "Program Files (x86)\World of Warcraft"
        Join-Path $d "Program Files\World of Warcraft"
        Join-Path $d "Games\World of Warcraft"
        Join-Path $d "World of Warcraft"
    }
    $WowRoot = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}

if (-not $WowRoot -or -not (Test-Path $WowRoot)) {
    Write-Error "Could not find a World of Warcraft install. Pass -WowRoot 'D:\Games\World of Warcraft'."
    exit 1
}

Write-Host "WoW install: $WowRoot" -ForegroundColor DarkGray

if ($Flavor -contains "all") {
    $Flavor = $flavorFolders.Keys | Where-Object {
        Test-Path (Join-Path $WowRoot "$($flavorFolders[$_])\Interface\AddOns")
    }
}

$deployed = 0
foreach ($f in $Flavor) {
    if (-not $flavorFolders.ContainsKey($f)) {
        Write-Warning "Unknown flavor '$f'. Valid values: $($flavorFolders.Keys -join ', '), all"
        continue
    }

    $addOns = Join-Path $WowRoot "$($flavorFolders[$f])\Interface\AddOns"
    if (-not (Test-Path $addOns)) {
        Write-Warning "$f is not installed (no $addOns) - skipping."
        continue
    }

    $dest = Join-Path $addOns "BuffPower"
    Write-Host "Deploying to: $dest" -ForegroundColor Cyan

    # /MIR so files deleted from the repo also disappear from the client. SavedVariables
    # live in WTF, not here, so mirroring cannot destroy settings.
    robocopy $source $dest /MIR /NJH /NJS /NP /NDL /NFL `
        /XD ".git" ".vscode" "docs" "scripts" "publish" ".github" "Media" ".examples" ".tools" `
        /XF "*.md" ".gitignore" ".pkgmeta" ".luacheckrc" | Out-Null

    # Robocopy returns a bitmask; anything below 8 means success.
    if ($LASTEXITCODE -ge 8) {
        Write-Error "robocopy failed for $f (exit code $LASTEXITCODE)"
    }

    $deployed++
    Write-Host "Deployed $f" -ForegroundColor Green
}

if ($deployed -eq 0) {
    Write-Error "Nothing was deployed."
    exit 1
}

Write-Host "Deployment Complete! Use /reload in-game, or restart the client if the TOC changed." -ForegroundColor Green

# Robocopy's non-zero success codes would otherwise become this script's exit code.
exit 0
