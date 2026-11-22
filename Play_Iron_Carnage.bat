@echo off
rem Launches Iron Carnage straight into the game, without opening the Godot editor.
rem Keep this file in the game folder (next to project.godot).
rem It looks for Godot 4.7 in the folder above this one; if yours is elsewhere, set GODOT below.
set "GAME_DIR=%~dp0"
if "%GAME_DIR:~-1%"=="\" set "GAME_DIR=%GAME_DIR:~0,-1%"
set "GODOT=%~dp0..\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
set "GODOT_CONSOLE=%~dp0..\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%GODOT%" (
  set "GODOT=%~dp0..\Godot_v4.7.2-stable_win64.exe"
  set "GODOT_CONSOLE=%~dp0..\Godot_v4.7.2-stable_win64_console.exe"
)

if not exist "%GODOT%" (
  echo Could not find Godot 4.7 at "%GODOT%"
  echo Open this file in Notepad and put your Godot path on the "set GODOT=" lines.
  pause
  exit /b 1
)
if not exist "%GAME_DIR%\project.godot" (
  echo Could not find the game at "%GAME_DIR%"
  pause
  exit /b 1
)
rem Refresh Godot's script and asset cache so new or updated game files are picked up.
if exist "%GODOT_CONSOLE%" "%GODOT_CONSOLE%" --headless --path "%GAME_DIR%" --import >nul 2>&1
start "" "%GODOT%" --path "%GAME_DIR%"
