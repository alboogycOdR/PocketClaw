@echo off
REM Build the release APK and serve it to your phone over the local network.
REM Usage: scripts\release.bat

cd /d "%~dp0.."

echo ============================================================
echo   Building Pocket Claw release APK (arm64-v8a)
echo ============================================================
echo.

call flutter build apk --release --target-platform android-arm64
if errorlevel 1 (
    echo Build failed.
    exit /b 1
)

echo.
echo Build complete. Starting local download server...
echo.

dart scripts\serve_apk.dart
