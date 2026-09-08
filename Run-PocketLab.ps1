param([string]$GodotPath = "", [switch]$Editor, [switch]$Test)
$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
if (-not $GodotPath) {
    $localEngine = Join-Path $projectRoot '.tools\godot\Godot_v4.6-stable_win64.exe'
    if (Test-Path -LiteralPath $localEngine) { $GodotPath = $localEngine }
    else {
        $found = Get-Command godot -ErrorAction SilentlyContinue
        if ($found) { $GodotPath = $found.Source }
    }
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath)) {
    throw 'Install Godot 4.6 Standard, then run: .\Run-PocketLab.ps1 -GodotPath <GODOT_EXECUTABLE>'
}
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot '.godot'))) {
    & $GodotPath --headless --editor --path $projectRoot --import --quit
}
if ($Test) {
    & $GodotPath --headless --path $projectRoot --fixed-fps 60 --script res://tests/test_suite.gd -- --test-mode
} elseif ($Editor) {
    & $GodotPath --editor --path $projectRoot
} else {
    & $GodotPath --path $projectRoot
}
