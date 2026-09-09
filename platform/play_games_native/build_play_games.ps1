[CmdletBinding()]
param(
    [string]$EvidenceRoot = "",
    [string]$SdkRoot = "E:\CodexCache\godot-android-4.7.1\android-sdk",
    [string]$JavaHome = "E:\CodexCache\godot-android-4.7.1\jdk\jdk-17.0.20+8",
    [string]$GradleHome = "E:\CodexCache\godot-android-4.7.1\gradle",
    [string]$GodotTemplateAar = "",
    [string]$GameId = "",
    [ValidateRange(10, 600)][int]$TimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"
$builderId = "platform/play_games_native/build_play_games.ps1"
$nativeRoot = Split-Path -Parent $PSCommandPath
$projectRoot = Split-Path -Parent (Split-Path -Parent $nativeRoot)
if ([string]::IsNullOrWhiteSpace($EvidenceRoot)) { $EvidenceRoot = Join-Path $projectRoot "reports\river-records-v31\validation" }
if ([string]::IsNullOrWhiteSpace($GodotTemplateAar)) { $GodotTemplateAar = Join-Path $projectRoot "android\build\libs\debug\godot-lib.template_debug.aar" }
New-Item -ItemType Directory -Force -Path $EvidenceRoot | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$stdout = Join-Path $EvidenceRoot "play-games-native-$stamp.stdout.log"
$stderr = Join-Path $EvidenceRoot "play-games-native-$stamp.stderr.log"
$receiptPath = Join-Path $EvidenceRoot "play-games-native-$stamp.json"
$env:ANDROID_HOME = $SdkRoot; $env:ANDROID_SDK_ROOT = $SdkRoot; $env:JAVA_HOME = $JavaHome; $env:GRADLE_USER_HOME = $GradleHome; $env:GODOT_TEMPLATE_AAR = $GodotTemplateAar

$gradleExecutable = Get-ChildItem -LiteralPath (Join-Path $GradleHome "wrapper\dists") -Filter "gradle.bat" -Recurse | Where-Object { $_.FullName -match "\\gradle-8\.11\.1\\bin\\gradle\.bat$" } | Select-Object -First 1 -ExpandProperty FullName
if ([string]::IsNullOrWhiteSpace($gradleExecutable) -or -not (Test-Path -LiteralPath $gradleExecutable)) { throw "Pinned Gradle 8.11.1 launcher is unavailable under the E: Gradle cache." }

function Add-TaskChildren([int]$ParentPid, [System.Collections.Generic.List[int]]$Observed, [hashtable]$Details) {
    foreach ($child in @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$ParentPid" -ErrorAction SilentlyContinue)) {
        if (-not $Observed.Contains([int]$child.ProcessId)) {
            [void]$Observed.Add([int]$child.ProcessId)
            $Details[[string]$child.ProcessId] = [ordered]@{ pid=[int]$child.ProcessId; parentPid=[int]$child.ParentProcessId; name=$child.Name; commandLine=$child.CommandLine }
        }
		# Recurse even when this child was observed in an earlier poll: Gradle can
		# spawn a new worker beneath an already-known Java parent later in the run.
		Add-TaskChildren -ParentPid ([int]$child.ProcessId) -Observed $Observed -Details $Details
    }
}
function Get-ObservedDetails([System.Collections.Generic.List[int]]$Observed) {
    $details = @()
    foreach ($taskPid in $Observed) {
        $item = Get-CimInstance Win32_Process -Filter "ProcessId=$taskPid" -ErrorAction SilentlyContinue
        if ($item) { $details += [ordered]@{ pid=[int]$item.ProcessId; parentPid=[int]$item.ParentProcessId; name=$item.Name; commandLine=$item.CommandLine } }
    }
    return $details
}

$arguments = @("assembleRelease", "--no-daemon")
if (-not [string]::IsNullOrWhiteSpace($GameId)) {
    if ($GameId -notmatch "^[1-9][0-9]*$") { throw "GameId must be the owner-supplied numeric Play Games ID." }
    $arguments += "-PplayGamesAppId=$GameId"
}
$started = Get-Date; $process = $null; $observed = [System.Collections.Generic.List[int]]::new(); $details = @{}; $cleanup = @(); $timedOut = $false; $exitCode = $null; $runError = $null
try {
    $process = Start-Process -FilePath $gradleExecutable -ArgumentList $arguments -WorkingDirectory $nativeRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    [void]$observed.Add([int]$process.Id)
	$rootInfo = Get-CimInstance Win32_Process -Filter "ProcessId=$($process.Id)" -ErrorAction SilentlyContinue
	if ($rootInfo) { $details[[string]$process.Id] = [ordered]@{ pid=[int]$rootInfo.ProcessId; parentPid=[int]$rootInfo.ParentProcessId; name=$rootInfo.Name; commandLine=$rootInfo.CommandLine } }
    $deadline = $started.AddSeconds($TimeoutSeconds)
    while (-not $process.HasExited -and (Get-Date) -lt $deadline) {
        Add-TaskChildren -ParentPid ([int]$process.Id) -Observed $observed -Details $details
        Start-Sleep -Milliseconds 300
    }
    Add-TaskChildren -ParentPid ([int]$process.Id) -Observed $observed -Details $details
    $timedOut = -not $process.HasExited
    if (-not $timedOut) { $exitCode = $process.ExitCode }
} catch { $runError = $_.Exception.Message }
finally {
    if ($timedOut -or $runError) {
        foreach ($taskPid in @($observed | Sort-Object -Descending)) {
            if (Get-Process -Id $taskPid -ErrorAction SilentlyContinue) { Stop-Process -Id $taskPid -Force; $cleanup += $taskPid }
        }
    }
    $remaining = @($observed | Where-Object { Get-Process -Id $_ -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id })
    $finished = Get-Date
    [ordered]@{ builder=$builderId; command=(Split-Path -Leaf $gradleExecutable) + " " + ($arguments -join " "); rootPid=if($process){$process.Id}else{$null}; observedPids=@($observed); processDetails=@($details.Values); cleanupPids=$cleanup; remainingTaskPids=$remaining; startedUtc=$started.ToUniversalTime().ToString("o"); finishedUtc=$finished.ToUniversalTime().ToString("o"); timeoutSeconds=$TimeoutSeconds; timedOut=$timedOut; exitCode=$exitCode; error=$runError; androidHome=$SdkRoot; javaHome=$JavaHome; gradleUserHome=$GradleHome; templateAar=$GodotTemplateAar; configuredGameId=(-not [string]::IsNullOrWhiteSpace($GameId)); stdout=$stdout; stderr=$stderr } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $receiptPath -Encoding UTF8
}
if ($runError) { Write-Error $runError; exit 3 }
if ($timedOut) { exit 124 }
if ($exitCode -ne 0) { exit $exitCode }

$binRoot = Join-Path $projectRoot "addons\play_games\bin"
$destination = Join-Path $binRoot "cast-and-crank-play-games-release.aar"
$binReceipt = Join-Path $binRoot "build_receipt.json"
if ([string]::IsNullOrWhiteSpace($GameId)) {
    # Only delete an artifact we can prove this helper produced; never touch an
    # unrelated owner AAR without its matching helper receipt.
    if ((Test-Path -LiteralPath $destination) -and (Test-Path -LiteralPath $binReceipt)) {
        $prior = Get-Content -LiteralPath $binReceipt -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        $priorHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
        if ($prior -and $prior.builder -eq $builderId -and $prior.sha256 -eq $priorHash) {
            Remove-Item -LiteralPath $destination,$binReceipt -Force
        }
    }
    exit 0
}
New-Item -ItemType Directory -Force -Path $binRoot | Out-Null
Copy-Item -LiteralPath (Join-Path $nativeRoot "build\outputs\aar\cast-and-crank-play-games-release.aar") -Destination $destination -Force
[ordered]@{ builder=$builderId; game_id=$GameId; configured=$true; sha256=(Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash; createdUtc=(Get-Date).ToUniversalTime().ToString("o") } | ConvertTo-Json | Set-Content -LiteralPath $binReceipt -Encoding UTF8
