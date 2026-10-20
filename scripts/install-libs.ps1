# Installs/updates the embedded libraries in Libs/ to match .pkgmeta.
#
# The CurseForge library repositories are Subversion, so an svn client is used when one
# is available. Those repositories are also browsable over plain HTTP, so the script
# falls back to mirroring them with Invoke-WebRequest on machines without svn rather
# than failing outright.

$ErrorActionPreference = "Stop"
# Invoke-WebRequest spends most of its time drawing the progress bar when output is
# redirected, which makes the HTTP fallback crawl.
$ProgressPreference = "SilentlyContinue"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "Git is required to install some libraries. Please install Git."
    exit 1
}

$root = Resolve-Path "$PSScriptRoot/.."
$libsDir = Join-Path $root "Libs"

if (-not (Test-Path $libsDir)) {
    New-Item -ItemType Directory -Path $libsDir | Out-Null
}

# A freshly installed client is often not on the PATH of an already-open shell yet,
# so check the usual install locations too.
$svnExe = (Get-Command svn -ErrorAction SilentlyContinue).Source
if (-not $svnExe) {
    $svnExe = @(
        "$env:ProgramFiles\SlikSvn\bin\svn.exe",
        "$env:ProgramFiles\TortoiseSVN\bin\svn.exe",
        "${env:ProgramFiles(x86)}\Subversion\bin\svn.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
}

if ($svnExe) {
    Write-Host "Using svn client: $svnExe" -ForegroundColor DarkGray
} else {
    Write-Host "No svn client found - falling back to HTTP mirroring." -ForegroundColor Yellow
    Write-Host "Install one with: winget install Slik.Subversion" -ForegroundColor DarkGray
}

# Fallback for machines without svn: mirrors one directory of an SVN repository over
# HTTP, recursing into subdirectories.
function Copy-SvnDirectoryOverHttp {
    param (
        [string]$Url,
        [string]$Destination
    )

    if (-not $Url.EndsWith("/")) { $Url += "/" }

    $listing = Invoke-WebRequest -Uri $Url -UseBasicParsing

    # Only relative single-segment entries are repository contents; this skips both the
    # parent-directory link and the absolute links in the page footer.
    $entries = [regex]::Matches($listing.Content, 'href="([^"]+)"') |
        ForEach-Object { $_.Groups[1].Value } |
        Where-Object { $_ -match '^[^/:]+/?$' }

    if (-not (Test-Path $Destination)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }

    foreach ($entry in $entries) {
        $name = [System.Uri]::UnescapeDataString($entry.TrimEnd("/"))
        $target = Join-Path $Destination $name

        if ($entry.EndsWith("/")) {
            Copy-SvnDirectoryOverHttp -Url ($Url + $entry) -Destination $target
        } else {
            Invoke-WebRequest -Uri ($Url + $entry) -UseBasicParsing -OutFile $target
        }
    }
}

function Install-Lib-Svn {
    param (
        [string]$Name,
        [string]$Url
    )

    Write-Host "Installing $Name..." -ForegroundColor Cyan
    $destPath = Join-Path $libsDir $Name

    if ($svnExe) {
        # Remove existing to ensure clean export
        if (Test-Path $destPath) {
            Remove-Item $destPath -Recurse -Force
        }

        # Use svn export to avoid .svn folders
        & $svnExe export $Url $destPath --no-auth-cache --non-interactive --force | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "svn export failed for $Name"
        }
    } else {
        # Download to a staging folder first so a failure cannot leave a half-updated
        # library behind.
        $staging = Join-Path $libsDir (".staging-" + $Name)
        try {
            Copy-SvnDirectoryOverHttp -Url $Url -Destination $staging

            if (Test-Path $destPath) {
                Remove-Item $destPath -Recurse -Force
            }
            Move-Item $staging $destPath
        } finally {
            if (Test-Path $staging) {
                Remove-Item $staging -Recurse -Force
            }
        }
    }

    if (Test-Path $destPath) {
        Write-Host "Installed $Name" -ForegroundColor Green
    } else {
        Write-Error "Failed to install $Name"
    }
}

function Install-Lib-Git {
    param (
        [string]$Name,
        [string]$Url
    )

    Write-Host "Installing $Name from Git..." -ForegroundColor Cyan
    $destPath = Join-Path $libsDir $Name

    if (Test-Path $destPath) {
        Remove-Item $destPath -Recurse -Force
    }

    git clone --depth 1 $Url $destPath | Out-Null
    if (Test-Path "$destPath/.git") {
        Remove-Item "$destPath/.git" -Recurse -Force
    }

    Write-Host "Installed $Name" -ForegroundColor Green
}

# --- Library Definitions (Matching .pkgmeta) ---

# Ace3
Install-Lib-Svn -Name "AceAddon-3.0" -Url "https://repos.curseforge.com/wow/ace3/trunk/AceAddon-3.0"
Install-Lib-Svn -Name "AceEvent-3.0" -Url "https://repos.curseforge.com/wow/ace3/trunk/AceEvent-3.0"
Install-Lib-Svn -Name "AceBucket-3.0" -Url "https://repos.curseforge.com/wow/ace3/trunk/AceBucket-3.0"
Install-Lib-Svn -Name "AceTimer-3.0" -Url "https://repos.curseforge.com/wow/ace3/trunk/AceTimer-3.0"
Install-Lib-Svn -Name "AceDB-3.0" -Url "https://repos.curseforge.com/wow/ace3/trunk/AceDB-3.0"
Install-Lib-Svn -Name "AceConsole-3.0" -Url "https://repos.curseforge.com/wow/ace3/trunk/AceConsole-3.0"
Install-Lib-Svn -Name "AceGUI-3.0" -Url "https://repos.curseforge.com/wow/ace3/trunk/AceGUI-3.0"
Install-Lib-Svn -Name "AceConfig-3.0" -Url "https://repos.curseforge.com/wow/ace3/trunk/AceConfig-3.0"

# Other Libs
Install-Lib-Svn -Name "LibStub" -Url "https://repos.curseforge.com/wow/libstub/trunk"
Install-Lib-Svn -Name "CallbackHandler-1.0" -Url "https://repos.curseforge.com/wow/callbackhandler/trunk/CallbackHandler-1.0"
Install-Lib-Svn -Name "LibDBIcon-1.0" -Url "https://repos.curseforge.com/wow/libdbicon-1-0/trunk"

# LibDataBroker-1.1 (Git) - required by LibDBIcon-1.0 for the minimap button
Install-Lib-Git -Name "LibDataBroker-1.1" -Url "https://github.com/tekkub/libdatabroker-1-1.git"

Write-Host "All libraries installed locally." -ForegroundColor Cyan
