param([string]$GodotPath = "")
$ErrorActionPreference = 'Stop'
if (-not $GodotPath) { $GodotPath = Join-Path $PSScriptRoot '.tools\godot\Godot_v4.6-stable_win64_console.exe' }
& $GodotPath --headless --path $PSScriptRoot --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
& $GodotPath --headless --path $PSScriptRoot --fixed-fps 60 --script res://tests/test_suite.gd -- --test-mode
if ($LASTEXITCODE -ne 0) { throw 'Pocket Lab tests failed' }
& $GodotPath --headless --path $PSScriptRoot --fixed-fps 60 --script res://tests/revision_suite.gd -- --test-mode
if ($LASTEXITCODE -ne 0) { throw 'Revision tests failed' }
& $GodotPath --headless --path $PSScriptRoot --script res://tests/restart.gd -- --write
if ($LASTEXITCODE -ne 0) { throw 'Restart write failed' }
& $GodotPath --headless --path $PSScriptRoot --script res://tests/restart.gd -- --read
if ($LASTEXITCODE -ne 0) { throw 'Restart read failed' }

& $GodotPath --headless --path $PSScriptRoot --fixed-fps 60 --script res://tests/interaction_physics_suite.gd -- --test-mode
if ($LASTEXITCODE -ne 0) { throw 'Interaction and dissipation tests failed' }
