# Build the Flutter Web bundle for deployment under /app/.
#
# Usage:
#   .\scripts\build-web-app.ps1
#   .\scripts\build-web-app.ps1 -ApiBaseUrl https://api.wasit.app -PublicBaseUrl https://wasit.app
#
# Output: mobile/build/web/  — served by Flask's webapp blueprint at /app/*.
param(
    [string]$ApiBaseUrl = "http://localhost:5150",
    [string]$PublicBaseUrl = "http://localhost:5150",
    [string]$BaseHref = "/app/"
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$mobile = Resolve-Path (Join-Path $here "..\mobile")

Write-Output "Building Flutter Web…"
Write-Output "  API_BASE_URL    = $ApiBaseUrl"
Write-Output "  PUBLIC_BASE_URL = $PublicBaseUrl"
Write-Output "  base-href       = $BaseHref"

Push-Location $mobile
try {
    flutter build web --release `
        --base-href $BaseHref `
        --dart-define=API_BASE_URL=$ApiBaseUrl `
        --dart-define=PUBLIC_BASE_URL=$PublicBaseUrl
    if ($LASTEXITCODE -ne 0) {
        Write-Error "flutter build web failed (exit $LASTEXITCODE)"
        exit $LASTEXITCODE
    }
} finally {
    Pop-Location
}

$out = Join-Path $mobile "build\web\index.html"
if (Test-Path $out) {
    $size = (Get-Item $out).Length
    Write-Output ""
    Write-Output "OK — built to $($mobile)\build\web\ (index.html $size bytes)"
    Write-Output "Boot the backend, then open http://localhost:5150/app/"
} else {
    Write-Error "Build finished but $out does not exist."
    exit 1
}
