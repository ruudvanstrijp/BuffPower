param (
    [string]$Version = "release"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot/.."
$publishDir = Join-Path $root "publish"
$addonDir = Join-Path $publishDir "BuffPower"

# Clean up previous builds
if (Test-Path $publishDir) {
    Remove-Item $publishDir -Recurse -Force
}
New-Item -ItemType Directory -Path $addonDir | Out-Null

Write-Host "Packaging BuffPower..."

# Copy files using the same exclusions as deploy.ps1
# Exclude: .git, .gitignore, .vscode, .examples, docs, *.md, scripts, .tools, .luacheckrc
Copy-Item -Path (Join-Path $root "*") -Destination $addonDir -Recurse -Force -Exclude ".git",".gitignore",".vscode",".examples","docs","*.md","scripts","publish",".github","Media",".tools",".luacheckrc"

# Remove any files that might have slipped through (Copy-Item -Exclude can be finicky with recursion on older PS versions)
Get-ChildItem -Path $addonDir -Include ".git",".gitignore",".vscode",".examples","docs","*.md","scripts","publish",".github","Media",".tools",".luacheckrc" -Recurse | Remove-Item -Recurse -Force

# Create Zip
$zipName = Join-Path $publishDir "BuffPower-$Version.zip"
Write-Host "Creating archive: $zipName"
Compress-Archive -Path $addonDir -DestinationPath $zipName

Write-Host "Package created successfully at $zipName" -ForegroundColor Green
