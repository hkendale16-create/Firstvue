param(
  [string]$WebUrl = "",
  [switch]$SkipTest
)

$ErrorActionPreference = "Stop"
$Flutter = "C:\Users\User1\develop\flutter\bin\flutter.bat"
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

Set-Location $ProjectRoot

Write-Host "Stopping stale Dart processes..."
Get-Process dart, dartvm, dartaotruntime -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Host "Running pub get..."
& $Flutter pub get

if (-not $SkipTest) {
  Write-Host "Analyzing..."
  & $Flutter analyze lib test
  Write-Host "Testing..."
  & $Flutter test
}

$defineArgs = @()
if ($WebUrl -ne "") {
  $defineArgs += "--dart-define=FIRSTVUE_WEB_URL=$WebUrl"
}

Write-Host "Building web..."
& $Flutter build web --no-wasm-dry-run --no-web-resources-cdn @defineArgs

Write-Host ""
Write-Host "Build complete: $ProjectRoot\build\web"
Write-Host "Deploy that folder to Netlify, Firebase Hosting, Cloudflare Pages, or your FirstVue host."
if ($WebUrl -ne "") {
  Write-Host "Share links will use: $WebUrl"
}
