@echo off
setlocal
set SCRIPT_DIR=%~dp0
where py >nul 2>nul
if %ERRORLEVEL% EQU 0 (
  py -3 "%SCRIPT_DIR%video_subtitle_gui.py" %*
) else (
  python "%SCRIPT_DIR%video_subtitle_gui.py" %*
)
