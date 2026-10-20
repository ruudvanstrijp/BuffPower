# Runs luacheck over the addon using the repository's .luacheckrc.
#
#   .\scripts\lint.ps1
#
# luacheck.exe is downloaded into .tools/ (gitignored) on first run and checked
# against a pinned SHA-256. To upgrade, change $version and $sha256 together.

$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot/.."

$version = "v1.2.0"
$sha256 = "0F1C69C4D09F1EBB4D8DF14C215E4553E2E639BD4CB7BF3C639B0DAA6198317B"
$exe = Join-Path $root ".tools\luacheck-$version.exe"

if (-not (Test-Path $exe)) {
    New-Item -ItemType Directory -Force (Split-Path $exe) | Out-Null
    $url = "https://github.com/lunarmodules/luacheck/releases/download/$version/luacheck.exe"
    Write-Host "Downloading luacheck $version..." -ForegroundColor DarkGray
    $tmp = "$exe.download"
    Invoke-WebRequest $url -OutFile $tmp -UseBasicParsing
    if ((Get-FileHash $tmp -Algorithm SHA256).Hash -ne $sha256) {
        Remove-Item $tmp
        Write-Error "luacheck.exe checksum mismatch; refusing to run it."
        exit 1
    }
    Move-Item $tmp $exe
}

Push-Location $root
try {
    & $exe . --codes --no-color
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
