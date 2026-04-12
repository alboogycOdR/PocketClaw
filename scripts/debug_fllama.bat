@echo off
REM Debug the fllama crash with a connected phone.
REM Usage: scripts\debug_fllama.bat
REM
REM Prerequisites:
REM   1. Enable Developer Options on phone (tap Build Number 7 times)
REM   2. Enable USB Debugging in Developer Options
REM   3. Connect phone via USB
REM   4. On phone, tap "Allow" on the USB debugging prompt

setlocal
set ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe

echo ============================================================
echo   Pocket Claw fllama crash debug
echo ============================================================
echo.
echo 1. Checking for connected device...
"%ADB%" devices

echo.
echo 2. Uninstalling previous Pocket Claw (clean slate)...
"%ADB%" uninstall com.carmen.pocket_claw 2>nul

echo.
echo 3. Clearing old logcat buffer...
"%ADB%" logcat -c

echo.
echo 4. Building + installing debug APK...
call flutter run --release --verbose ^
    --target-platform=android-arm64
REM Note: We use --release here because the crash was in a release build.
REM The --verbose flag streams native-level errors to the terminal.

endlocal
