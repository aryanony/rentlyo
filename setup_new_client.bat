@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

:: 1. Locate setup_client.dart
set "SCRIPT_FILE="
if exist "scripts\setup_client.dart" (
  set "SCRIPT_FILE=scripts\setup_client.dart"
) else if exist "scripts\scripts\setup_client.dart" (
  set "SCRIPT_FILE=scripts\scripts\setup_client.dart"
) else if exist "setup_client.dart" (
  set "SCRIPT_FILE=setup_client.dart"
) else (
  cls
  echo ============================================================
  echo   [ERROR] setup_client.dart NOT FOUND!
  echo ============================================================
  echo.
  echo   The automated setup tool could not find 'setup_client.dart'.
  echo   Please ensure the 'scripts' folder is present in this
  echo   directory alongside 'setup_new_client.bat'.
  echo.
  echo ============================================================
  pause
  exit /b 1
)

:: 2. Check for Dart / Flutter runtime
where dart >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
  where flutter >nul 2>&1
  if %ERRORLEVEL% NEQ 0 (
    cls
    echo ============================================================
    echo   [ERROR] Dart / Flutter SDK NOT FOUND IN SYSTEM PATH!
    echo ============================================================
    echo.
    echo   Please ensure Flutter or Dart is installed and added to PATH.
    echo.
    echo ============================================================
    pause
    exit /b 1
  ) else (
    set "RUNNER=flutter dart"
  )
) else (
  set "RUNNER=dart"
)

:: Direct CLI argument passthrough
if not "%~1"=="" (
  %RUNNER% %SCRIPT_FILE% %*
  goto done
)

:menu
cls
echo ============================================================
echo   Rentlyo Suite -- 1-Click Client Setup ^& Deployment
echo ============================================================
echo.
echo   [1] 1-Click Complete Client Setup (Recommended)
echo       - Syncs client_config.json ^& distributes assets
echo       - Compiles launcher icons ^& native splash screens
echo       - Bootstraps Firebase Owner login ^& Firestore database
echo.
echo   [2] 1-Click Complete Setup ^& Build Release APKs
echo       - Runs Complete Setup + Compiles release APKs for both apps
echo.
echo   [3] Pre-Flight Diagnostics ^& Health Check
echo       - Verifies keys, assets, packages, and database connection
echo.
echo   [4] Interactive Terminal Questionnaire
echo       - Answer questions step-by-step to customize client_config.json
echo.
echo   [5] Clean / Reset Database
echo       - Purge test data while keeping the owner account safe
echo.
echo   [6] Exit
echo.
echo ============================================================
set /p choice="Enter your choice (1-6) [Default is 1]: "
if "%choice%"=="" set choice=1

if "%choice%"=="1" (
  echo.
  echo Running 1-Click Complete Client Setup...
  %RUNNER% %SCRIPT_FILE%
  goto done
)
if "%choice%"=="2" (
  echo.
  echo Running Complete Setup ^& Building Release APKs...
  %RUNNER% %SCRIPT_FILE% --all
  goto done
)
if "%choice%"=="3" (
  echo.
  echo Running Pre-Flight Diagnostics...
  %RUNNER% %SCRIPT_FILE% --verify
  goto done
)
if "%choice%"=="4" (
  echo.
  echo Starting Interactive Variables Form...
  %RUNNER% %SCRIPT_FILE% --interactive
  goto done
)
if "%choice%"=="5" (
  echo.
  if exist "scripts\clean_database.dart" (
    %RUNNER% scripts\clean_database.dart
  ) else (
    echo [ERROR] scripts\clean_database.dart not found.
  )
  goto done
)
if "%choice%"=="6" (
  exit /b 0
)

echo.
echo Invalid choice. Please enter 1, 2, 3, 4, 5, or 6.
pause
goto menu

:done
echo.
pause
