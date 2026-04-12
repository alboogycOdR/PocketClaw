@echo off
REM Build the release APK, upload to Gofile.io, and notify via Telegram.
REM Use this when you are NOT on the same network as your phone.
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
echo   Building Pocket Claw release APK (arm64-v8a)
echo ============================================================
echo.

call flutter build apk --release --target-platform android-arm64
if errorlevel 1 (
    echo Build failed.
    exit /b 1
)

echo.
echo Build complete. Uploading + notifying...
echo.

dart scripts\release_remote.dart
