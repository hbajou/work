@echo off
setlocal enabledelayedexpansion

if "%~1"=="" (
  echo Usage: %~nx0 "INPUT_FOLDER" "OUTPUT_FOLDER" [--model small --language ja]
  exit /b 1
)

set "TARGET_DIR=%~1"
if not exist "%TARGET_DIR%" (
  echo Folder not found: "%TARGET_DIR%"
  exit /b 1
)

set "OUTPUT_DIR=%~2"
if "%OUTPUT_DIR%"=="" (
  echo Output folder is required. Example: %~nx0 "F:\編集動画\20260701" "F:\編集動画\20260701_out"
  exit /b 1
)

if not exist "%OUTPUT_DIR%" (
  echo Output folder not found: "%OUTPUT_DIR%"
  exit /b 1
)

set "SCRIPT_DIR=%~dp0"
set "VENV_PYTHON=%~dp0..\.venv\Scripts\python.exe"
if exist "%VENV_PYTHON%" (
  set "PY_CMD=%VENV_PYTHON%"
) else (
  where py >nul 2>nul
  if %ERRORLEVEL% EQU 0 (
    set "PY_CMD=py -3"
  ) else (
    set "PY_CMD=python"
  )
)

set "REST_ARGS="
:collect_args
if "%~3"=="" goto args_done
set "REST_ARGS=%REST_ARGS% %3"
shift
goto collect_args
:args_done

for %%F in ("%TARGET_DIR%\*.mp4") do (
  set "INPUT_PATH=%%~fF"
  set "OUTPUT_PATH=%OUTPUT_DIR%\%%~nF_speech_only.mp4"
  echo.
  echo Processing: !INPUT_PATH!
  echo Output: !OUTPUT_PATH!
  %PY_CMD% "%SCRIPT_DIR%video_subtitle_tool.py" "!INPUT_PATH!" -o "!OUTPUT_PATH!" %REST_ARGS%
  if errorlevel 1 (
    echo Failed on: !INPUT_PATH!
    exit /b 1
  )
)

echo.
echo Finished processing all MP4 files in "%TARGET_DIR%"
echo Output folder: "%OUTPUT_DIR%"
exit /b 0
