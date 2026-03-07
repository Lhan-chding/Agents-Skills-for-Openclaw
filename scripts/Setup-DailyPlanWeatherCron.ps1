param(
    [Parameter(Mandatory = $true)]
    [string]$To,

    [string]$Channel = "feishu",
    [string]$Agent = "dev",
    [string]$Timezone = "Asia/Shanghai",

    [string]$Location = "Chengdu",
    [string]$EveningCron = "0 22 * * *",
    [string]$MorningCron = "30 7 * * *",

    [string]$EveningJobName = "daily-plan-reminder-2200",
    [string]$MorningJobName = "daily-plan-weather-summary-0730",
    [string]$SessionKey = "",

    [switch]$Force,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-OpenClaw {
    param([string[]]$CliArgs)
    $cmd = @("openclaw.cmd") + $CliArgs
    if ($DryRun) {
        Write-Host ("[DryRun] " + ($cmd -join " "))
        return $null
    }
    & $cmd[0] $cmd[1..($cmd.Count - 1)]
}

function Get-CronJobs {
    if ($DryRun) { return @() }
    $raw = & openclaw.cmd cron list --json
    if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
    $obj = $raw | ConvertFrom-Json
    if ($null -eq $obj -or $null -eq $obj.jobs) { return @() }
    return @($obj.jobs)
}

function Remove-JobByName {
    param(
        [string]$Name,
        [object[]]$Jobs
    )
    $hit = @($Jobs | Where-Object { $_.name -eq $Name })
    foreach ($j in $hit) {
        $id = [string]$j.id
        if ([string]::IsNullOrWhiteSpace($id)) { continue }
        Write-Host "Removing existing cron job: $Name ($id)"
        Invoke-OpenClaw -CliArgs @("cron", "rm", $id) | Out-Null
    }
}

$encodedLocation = [System.Uri]::EscapeDataString($Location)
$weatherUrl = "https://wttr.in/${encodedLocation}?format=j1"

if ([string]::IsNullOrWhiteSpace($SessionKey) -and $Channel -eq "feishu" -and $To -like "ou_*") {
    $SessionKey = "agent:${Agent}:feishu:direct:${To}"
}

$eveningMessage = "Night reminder: please send your tomorrow plan now. Format: (1) top 3 priorities, (2) time blocks morning/afternoon/evening, (3) risks/blockers. I will send a 07:30 summary with weather and umbrella advice."
$morningMessage = "Morning coach task: read latest user plan from last 24h; if found, output today's top 3 priorities + time-block schedule + risks/mitigation; if not found, state missing plan and provide a fill-in template; then fetch weather via web_fetch from $weatherUrl, extract today's condition + min/max temp + rain probability/timing, and conclude clearly whether to bring an umbrella. Output sections: Today's Focus / Today's Schedule / Weather and Umbrella Advice."

Write-Host "Target: channel=$Channel to=$To agent=$Agent tz=$Timezone location=$Location"
if (-not [string]::IsNullOrWhiteSpace($SessionKey)) {
    Write-Host "Pinned session key: $SessionKey"
}
Write-Host "Evening cron: $EveningCron ($EveningJobName)"
Write-Host "Morning cron: $MorningCron ($MorningJobName)"

$jobs = @(Get-CronJobs)

if ($jobs.Count -gt 0) {
    $hasEvening = @($jobs | Where-Object { $_.name -eq $EveningJobName }).Count -gt 0
    $hasMorning = @($jobs | Where-Object { $_.name -eq $MorningJobName }).Count -gt 0
    if (($hasEvening -or $hasMorning) -and (-not $Force.IsPresent)) {
        throw "Cron jobs already exist. Use -Force to replace."
    }
    if ($Force.IsPresent) {
        Remove-JobByName -Name $EveningJobName -Jobs $jobs
        Remove-JobByName -Name $MorningJobName -Jobs $jobs
    }
}

Write-Host "Adding evening reminder job..."
if ([string]::IsNullOrWhiteSpace($SessionKey)) {
    $eveningArgs = @(
        "cron", "add",
        "--name", $EveningJobName,
        "--cron", $EveningCron,
        "--tz", $Timezone,
        "--agent", $Agent,
        "--message", $eveningMessage,
        "--announce",
        "--channel", $Channel,
        "--to", $To
    )
}
else {
    $eveningArgs = @(
        "cron", "add",
        "--name", $EveningJobName,
        "--cron", $EveningCron,
        "--tz", $Timezone,
        "--agent", $Agent,
        "--session-key", $SessionKey,
        "--message", $eveningMessage,
        "--announce"
    )
}
Invoke-OpenClaw -CliArgs $eveningArgs | Out-Null

Write-Host "Adding morning summary + weather job..."
if ([string]::IsNullOrWhiteSpace($SessionKey)) {
    $morningArgs = @(
        "cron", "add",
        "--name", $MorningJobName,
        "--cron", $MorningCron,
        "--tz", $Timezone,
        "--agent", $Agent,
        "--message", $morningMessage,
        "--announce",
        "--channel", $Channel,
        "--to", $To
    )
}
else {
    $morningArgs = @(
        "cron", "add",
        "--name", $MorningJobName,
        "--cron", $MorningCron,
        "--tz", $Timezone,
        "--agent", $Agent,
        "--session-key", $SessionKey,
        "--message", $morningMessage,
        "--announce"
    )
}
Invoke-OpenClaw -CliArgs $morningArgs | Out-Null

Write-Host ""
if ($DryRun) {
    Write-Host "Dry-run complete. No cron jobs were changed."
}
else {
    Write-Host "Done. Current cron jobs:"
    & openclaw.cmd cron list
    $jobsAfter = Get-CronJobs
    $evening = $jobsAfter | Where-Object { $_.name -eq $EveningJobName } | Select-Object -First 1
    $morning = $jobsAfter | Where-Object { $_.name -eq $MorningJobName } | Select-Object -First 1
    Write-Host ""
    Write-Host "Optional test now (run by job id):"
    if ($null -ne $evening -and -not [string]::IsNullOrWhiteSpace([string]$evening.id)) {
        Write-Host "  openclaw.cmd cron run $($evening.id)"
    }
    if ($null -ne $morning -and -not [string]::IsNullOrWhiteSpace([string]$morning.id)) {
        Write-Host "  openclaw.cmd cron run $($morning.id)"
    }
}
