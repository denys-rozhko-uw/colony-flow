param([string]$GodotBin = $env:GODOT_BIN)
$ErrorActionPreference = 'Stop'
if (-not $GodotBin) { $GodotBin = 'C:\Godot\Godot_v4.5.1-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $GodotBin)) { throw "Godot не найден: $GodotBin" }
$taskRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
function Invoke-GameCheck {
    param([string[]]$Arguments, [string]$Stage)
    $taskOutput = & $GodotBin @Arguments 2>&1 | Out-String
    $taskExitCode = $LASTEXITCODE
    Write-Output $taskOutput
    if ($taskExitCode -ne 0 -or $taskOutput -match 'SCRIPT ERROR:|ERROR: Failed to load script') {
        throw "$Stage завершился ошибкой (код $taskExitCode)"
    }
}
Invoke-GameCheck -Arguments @('--headless', '--path', $taskRoot, '--import') -Stage 'Импорт Godot'
if (Test-Path -LiteralPath (Join-Path $taskRoot 'tests/run_tests.gd')) {
    Invoke-GameCheck -Arguments @('--headless', '--path', $taskRoot, '--script', 'res://tests/run_tests.gd') -Stage 'Тесты'
} else { Write-Output 'Тестовая стадия пока недоступна' }
if (Test-Path -LiteralPath (Join-Path $taskRoot 'tools/validate_levels.gd')) {
    Invoke-GameCheck -Arguments @('--headless', '--path', $taskRoot, '--script', 'res://tools/validate_levels.gd') -Stage 'Проверка уровней'
}
if (Test-Path -LiteralPath (Join-Path $taskRoot 'tools/verify_solutions.gd')) {
    Invoke-GameCheck -Arguments @('--headless', '--path', $taskRoot, '--script', 'res://tools/verify_solutions.gd') -Stage 'Проверка решений'
}
if (Test-Path -LiteralPath (Join-Path $taskRoot 'tests/ui_walkthrough.gd')) {
    Invoke-GameCheck -Arguments @('--headless', '--path', $taskRoot, '--script', 'res://tests/ui_walkthrough.gd') -Stage 'Прохождение двадцати уровней через UI'
}
Invoke-GameCheck -Arguments @('--headless', '--path', $taskRoot, '--quit-after', '5') -Stage 'Старт главной сцены'
Write-Output 'Проверки завершены'
