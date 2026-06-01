@echo off
REM Build the HermesCommander release APK, upload it to Gofile.io,
REM and notify via Telegram.
REM
REM Usage: scripts\release-remote.bat

cd /d "%~dp0.."

if not exist .env (
    echo Error: .env file missing.
    echo.
    echo Create .env in the project root with:
    echo   TELEGRAM_BOT_TOKEN=your-bot-token
    echo   TELEGRAM_CHAT_ID=your-chat-id
    echo.
    echo See scripts\release_remote.dart for full setup instructions.
    exit /b 1
)

echo ============================================================
echo   Building HermesCommander release APK (arm64-v8a)
echo ============================================================
echo.

call flutter build apk --release --target-platform android-arm64 --dart-define=APP_FLAVOR=hermesCommander
if errorlevel 1 (
    echo Build failed.
    exit /b 1
)

echo.
echo Build complete. Uploading + notifying...
echo.

dart scripts\release_remote.dart build\app\outputs\flutter-apk\app-release.apk
