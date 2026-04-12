@echo off
REM Capture a crash log from a connected phone.
REM Run this FIRST, then open Pocket Claw on the phone to reproduce the crash,
REM then press Ctrl+C here to stop. The log is saved to crash.log.
REM
REM Usage: scripts\capture_crash.bat

setlocal
set ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe

echo ============================================================
echo   Pocket Claw crash log capture
echo ============================================================
echo.
"%ADB%" devices
echo.
echo Clearing old log buffer...
"%ADB%" logcat -c
echo.
echo Capturing. Now open Pocket Claw on the phone to trigger the crash.
echo When the crash happens, press Ctrl+C here to stop.
echo Output: crash.log
echo.

"%ADB%" logcat ^
    AndroidRuntime:E ^
    libc:E ^
    DEBUG:I ^
    fllama:V ^
    flutter:V ^
    pocket_claw:V ^
    *:F > crash.log

endlocal
