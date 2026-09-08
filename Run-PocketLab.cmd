@echo off
setlocal
set "ENGINE=%~dp0.tools\godot\Godot_v4.6-stable_win64.exe"
if not exist "%ENGINE%" (
    echo Godot 4.6 is required. Import project.godot in the Godot editor, or use Run-PocketLab.ps1 -GodotPath.
    pause
    exit /b 1
)
if not exist "%~dp0.godot" "%ENGINE%" --headless --editor --path "%~dp0." --import --quit
start "Pocket Lab" "%ENGINE%" --path "%~dp0."
