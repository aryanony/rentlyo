<#
.SYNOPSIS
  Rentlyo Suite -- 1-Click Client Setup & Deployment (PowerShell Edition)
#>

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# 1. Locate setup_client.dart
$ScriptFile = ""
if (Test-Path "scripts\setup_client.dart") {
    $ScriptFile = "scripts\setup_client.dart"
} elseif (Test-Path "scripts\scripts\setup_client.dart") {
    $ScriptFile = "scripts\scripts\setup_client.dart"
} elseif (Test-Path "setup_client.dart") {
    $ScriptFile = "setup_client.dart"
} else {
    Clear-Host
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host "  [ERROR] setup_client.dart NOT FOUND!" -ForegroundColor Red
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host "`nThe automated setup tool could not find 'setup_client.dart'."
    Write-Host "Please ensure the 'scripts' folder is present in this directory.`n"
    Pause
    exit 1
}

# 2. Check Dart runtime
$Runner = "dart"
if (-not (Get-Command dart -ErrorAction SilentlyContinue)) {
    if (Get-Command flutter -ErrorAction SilentlyContinue) {
        $Runner = "flutter dart"
    } else {
        Clear-Host
        Write-Host "============================================================" -ForegroundColor Red
        Write-Host "  [ERROR] Dart / Flutter SDK NOT FOUND IN SYSTEM PATH!" -ForegroundColor Red
        Write-Host "============================================================" -ForegroundColor Red
        Write-Host "`nPlease ensure Flutter or Dart is installed and added to PATH.`n"
        Pause
        exit 1
    }
}

function Show-Menu {
    Clear-Host
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  Rentlyo Suite -- 1-Click Client Setup & Deployment   " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [1] 1-Click Complete Client Setup (Recommended)" -ForegroundColor Green
    Write-Host "      - Syncs client_config.json & distributes assets"
    Write-Host "      - Compiles launcher icons & native splash screens"
    Write-Host "      - Bootstraps Firebase Owner login & Firestore database"
    Write-Host ""
    Write-Host "  [2] 1-Click Complete Setup & Build Release APKs" -ForegroundColor Yellow
    Write-Host "      - Runs Complete Setup + Compiles release APKs for both apps"
    Write-Host ""
    Write-Host "  [3] Pre-Flight Diagnostics & Health Check"
    Write-Host "      - Verifies keys, assets, packages, and database connection"
    Write-Host ""
    Write-Host "  [4] Interactive Terminal Questionnaire"
    Write-Host "      - Answer questions step-by-step to customize client_config.json"
    Write-Host ""
    Write-Host "  [5] Clean / Reset Database"
    Write-Host "      - Purge test data while keeping the owner account safe"
    Write-Host ""
    Write-Host "  [6] Exit"
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
}

if ($args.Count -gt 0) {
    & $Runner $ScriptFile $args
    Pause
    exit 0
}

Show-Menu
$Choice = Read-Host "Enter your choice (1-6) [Default is 1]"
if ([string]::IsNullOrWhiteSpace($Choice)) { $Choice = "1" }

switch ($Choice) {
    "1" {
        Write-Host "`nRunning 1-Click Complete Client Setup..." -ForegroundColor Green
        & $Runner $ScriptFile
    }
    "2" {
        Write-Host "`nRunning Complete Setup & Building Release APKs..." -ForegroundColor Yellow
        & $Runner $ScriptFile --all
    }
    "3" {
        Write-Host "`nRunning Pre-Flight Diagnostics..." -ForegroundColor Cyan
        & $Runner $ScriptFile --verify
    }
    "4" {
        Write-Host "`nStarting Interactive Variables Form..." -ForegroundColor Cyan
        & $Runner $ScriptFile --interactive
    }
    "5" {
        if (Test-Path "scripts\clean_database.dart") {
            & $Runner scripts\clean_database.dart
        } else {
            Write-Host "[ERROR] scripts\clean_database.dart not found." -ForegroundColor Red
        }
    }
    "6" {
        exit 0
    }
    default {
        Write-Host "`nInvalid choice. Please enter 1-6." -ForegroundColor Red
    }
}

Write-Host ""
Pause
