@echo off
setlocal
set SCRIPT_DIR=%~dp0
set VENV_PYTHON=%~dp0..\.venv\Scripts\python.exe
if exist "%VENV_PYTHON%" (
  "%VENV_PYTHON%" "%SCRIPT_DIR%video_subtitle_tool.py" %*
) else (
  where py >nul 2>nul
  if %ERRORLEVEL% EQU 0 (
    py -3 "%SCRIPT_DIR%video_subtitle_tool.py" %*
  ) else (
    python "%SCRIPT_DIR%video_subtitle_tool.py" %*
  )
)
