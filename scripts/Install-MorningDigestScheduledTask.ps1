param(
    [string]$Workspace = "$env:USERPROFILE\.openclaw\workspace",
    [string]$TaskName = "OpenClaw-MorningDigestCache-0705",
    [string]$RunAt = "07:05",
    [string]$Location = "中国·成都市双流区",
    [switch]$Force,
    [switch]$Remove,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $Workspace 'scripts\Build-MorningDigestCache.ps1'
$powerShellExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

if ($Remove.IsPresent) {
    if ($DryRun) {
        Write-Host "[DryRun] Would remove scheduled task: $TaskName"
        exit 0
    }

    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($null -eq $existing) {
        Write-Host "Task not found: $TaskName"
        exit 0
    }

    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Removed scheduled task: $TaskName"
    exit 0
}

if (-not (Test-Path $scriptPath)) {
    throw "Script not found: $scriptPath. Run Install-OpenClawCapabilityPack.ps1 first."
}

$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($null -ne $existingTask -and -not $Force.IsPresent) {
    throw 'Scheduled task already exists. Use -Force to replace.'
}

$triggerTime = [datetime]::ParseExact($RunAt, 'HH:mm', $null)
$actionArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -Workspace `"$Workspace`" -Location `"$Location`""
$description = "OpenClaw morning digest cache prefetch at $RunAt for $Location. This task fetches local weather/news cache only; 07:30 delivery is handled by OpenClaw cron."

if ($DryRun) {
    Write-Host "[DryRun] TaskName: $TaskName"
    Write-Host "[DryRun] RunAt:    $RunAt"
    Write-Host "[DryRun] Action:   $powerShellExe $actionArgs"
    exit 0
}

$action = New-ScheduledTaskAction -Execute $powerShellExe -Argument $actionArgs
$trigger = New-ScheduledTaskTrigger -Daily -At $triggerTime
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew

if ($null -ne $existingTask) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Description $description | Out-Null

$task = Get-ScheduledTask -TaskName $TaskName
Write-Host 'Scheduled task installed:'
Write-Host "  Name: $($task.TaskName)"
Write-Host "  RunAt: $RunAt"
Write-Host "  Script: $scriptPath"
