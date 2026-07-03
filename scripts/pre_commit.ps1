# pre_commit.ps1
# Run this before every commit. Must be green (exit code 0) before pushing.

$ErrorActionPreference = "Stop"

Write-Host "==> Getting dependencies..." -ForegroundColor Cyan
flutter pub get
if ($LASTEXITCODE -ne 0) { Write-Host "pub get failed" -ForegroundColor Red; exit 1 }

Write-Host "==> Checking formatting..." -ForegroundColor Cyan
dart format --output=none --set-exit-if-changed .
if ($LASTEXITCODE -ne 0) {
    Write-Host "Formatting issues found. Run 'dart format .' to fix." -ForegroundColor Red
    exit 1
}

Write-Host "==> Running static analysis..." -ForegroundColor Cyan
flutter analyze --fatal-infos
if ($LASTEXITCODE -ne 0) { Write-Host "Analysis failed" -ForegroundColor Red; exit 1 }

Write-Host "==> Running tests with coverage..." -ForegroundColor Cyan
flutter test --coverage
if ($LASTEXITCODE -ne 0) { Write-Host "Tests failed" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "All checks passed. Safe to commit." -ForegroundColor Green
