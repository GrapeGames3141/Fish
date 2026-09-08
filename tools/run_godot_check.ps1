param(
    [Parameter(Mandatory=$true)][string]$Label,
    [Parameter(Mandatory=$true)][string[]]$Arguments,
    [int]$TimeoutSeconds = 45,
    [string]$CacheRoot = 'E:\CodexCache\haptic-fish-polish-v28',
    [string]$Engine = 'E:\CodexCache\godot-android-4.7.1\godot\Godot_v4.7.1-stable_win64.exe',
    [switch]$UseDesktopProfile
)

$project = 'E:\CodexCache\haptic-fish-project'
$evidence = 'E:\AI Projects\games\haptic fish\reports\ui-v4-polish-720\validation'
New-Item -ItemType Directory -Force -Path $evidence | Out-Null
$safeLabel = $Label -replace '[^A-Za-z0-9._-]', '_'
$stdout = Join-Path $evidence ($safeLabel + '.stdout.log')
$stderr = Join-Path $evidence ($safeLabel + '.stderr.log')
$ledger = Join-Path $evidence ($safeLabel + '.json')
if (-not $UseDesktopProfile) {
    New-Item -ItemType Directory -Force -Path $CacheRoot | Out-Null
    $env:APPDATA = $CacheRoot; $env:TEMP = $CacheRoot; $env:TMP = $CacheRoot
}

# ArgumentList as one string preserves whitespace paths and the user's -- boundary.
$argumentLine = (($Arguments | ForEach-Object {
    if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
}) -join ' ')
$started = Get-Date
$process = $null
$observed = @()
$windows = @()
$cleanup = @()
$completed = $false
$runError = $null
$exitCode = $null
function Add-TaskChildren([int]$ParentId) {
    $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$ParentId" -ErrorAction Stop)
    foreach ($child in $children) {
        if ($observed -notcontains $child.ProcessId) { $script:observed += $child.ProcessId; Add-TaskChildren $child.ProcessId }
    }
}
try {
    $process = Start-Process -FilePath $Engine -ArgumentList $argumentLine -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $observed = @($process.Id)
    # Persist root PID before discovery, so a denied CIM query remains auditable.
    [ordered]@{ label=$Label; rootPid=$process.Id; observedPids=$observed; engine=$Engine; arguments=$Arguments; started=$started.ToString('o') } | ConvertTo-Json -Depth 4 | Set-Content -Encoding utf8 (Join-Path $evidence ($safeLabel + '.initial.json'))
    Add-TaskChildren $process.Id
    $completed = $process.WaitForExit($TimeoutSeconds * 1000)
    $exitCode = if ($completed) { $process.ExitCode } else { $null }
    Add-TaskChildren $process.Id
} catch {
    $runError = $_.Exception.Message
} finally {
    foreach ($taskPid in ($observed | Sort-Object -Descending)) {
        $p = Get-Process -Id $taskPid -ErrorAction SilentlyContinue
        if ($p) { if ($p.MainWindowTitle) { $windows += @{ pid = $taskPid; title = $p.MainWindowTitle } }; Stop-Process -Id $taskPid -Force; $cleanup += $taskPid }
    }
    $remaining = @($observed | Where-Object { Get-Process -Id $_ -ErrorAction SilentlyContinue })
    $isDomainCheck = $Arguments -contains 'res://tests/test_runner.gd'
    $stderrMarkers = if (Test-Path $stderr) { Select-String -Path $stderr -Pattern 'SCRIPT ERROR:|Parse Error:|ERROR:' | Where-Object { -not ($isDomainCheck -and $_.Line -match '^ERROR: 5 resources still in use at exit') } | Select-Object -First 1 } else { $null }
    [ordered]@{ label=$Label; started=$started.ToString('o'); finished=(Get-Date).ToString('o'); engine=$Engine; arguments=$Arguments; appdata=$env:APPDATA; rootPid=if($process){$process.Id}else{$null}; observedPids=$observed; completed=$completed; exitCode=$exitCode; cleanupPids=$cleanup; remainingTaskPids=$remaining; windows=$windows; stdout=$stdout; stderr=$stderr; stderrMarker=if($stderrMarkers){$stderrMarkers.Line}else{$null}; error=$runError } | ConvertTo-Json -Depth 5 | Set-Content -Encoding utf8 $ledger
}
if ($runError) { Write-Error $runError; exit 3 }
if (-not $completed) { exit 124 }
if ($stderrMarkers) { exit 2 }
exit $exitCode
