@echo off
setlocal enabledelayedexpansion

set "TARGET_DIR=%~1"
if "%TARGET_DIR%"=="" (
  echo Usage: %~nx0 "F:\編集動画\20260701"
  echo Optional: add extra args such as --model small --language ja
  exit /b 1
)

if not exist "%TARGET_DIR%" (
  echo Folder not found: %TARGET_DIR%
  exit /b 1
)

set "SCRIPT_DIR=%~dp0"
where py >nul 2>nul
if %ERRORLEVEL% EQU 0 (
  set "PY_CMD=py -3"
) else (
  set "PY_CMD=python"
)

shift

for %%F in ("%TARGET_DIR%\*.mp4") do (
  set "INPUT_PATH=%%~fF"
  set "OUTPUT_PATH=%TARGET_DIR%\%%~nF_speech_only.mp4"
  echo.
  echo Processing: !INPUT_PATH!
  %PY_CMD% "%SCRIPT_DIR%video_subtitle_tool.py" "!INPUT_PATH!" -o "!OUTPUT_PATH!" %*
  if ERRORLEVEL 1 (
    echo Failed on: !INPUT_PATH!
    exit /b 1
  )
)

echo.
echo Finished processing all MP4 files in %TARGET_DIR%
exit /b 0
