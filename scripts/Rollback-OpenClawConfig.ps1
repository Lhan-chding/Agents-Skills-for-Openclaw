param(
    [string]$OpenClawHome = "$env:USERPROFILE\.openclaw",
    [string]$BackupRoot = "",
    [string]$OpenClawConfigBackup = "",
    [string]$ExecApprovalsBackup = "",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($BackupRoot)) {
    $BackupRoot = Join-Path $OpenClawHome "backups\capability-pack"
}

if (-not (Test-Path $BackupRoot)) {
    throw "Backup root not found: $BackupRoot"
}

$openclawTarget = Join-Path $OpenClawHome "openclaw.json"
$approvalsTarget = Join-Path $OpenClawHome "exec-approvals.json"

function Get-LatestBackupFile {
    param(
        [string]$Root,
        [string]$Pattern
    )
    $candidate = Get-ChildItem $Root -Filter $Pattern -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($null -eq $candidate) { return "" }
    return $candidate.FullName
}

if ([string]::IsNullOrWhiteSpace($OpenClawConfigBackup)) {
    $OpenClawConfigBackup = Get-LatestBackupFile -Root $BackupRoot -Pattern "openclaw.json.*.bak"
}

if ([string]::IsNullOrWhiteSpace($ExecApprovalsBackup)) {
    $ExecApprovalsBackup = Get-LatestBackupFile -Root $BackupRoot -Pattern "exec-approvals.json.*.bak"
}

if ([string]::IsNullOrWhiteSpace($OpenClawConfigBackup) -or -not (Test-Path $OpenClawConfigBackup)) {
    throw "No openclaw.json backup found. Use -OpenClawConfigBackup to specify one."
}

if ($DryRun) {
    Write-Host "[DryRun] Would restore openclaw.json from: $OpenClawConfigBackup"
    if (-not [string]::IsNullOrWhiteSpace($ExecApprovalsBackup)) {
        Write-Host "[DryRun] Would restore exec-approvals.json from: $ExecApprovalsBackup"
    }
    exit 0
}

Copy-Item -Path $OpenClawConfigBackup -Destination $openclawTarget -Force
Write-Host "Restored: $openclawTarget"

if (-not [string]::IsNullOrWhiteSpace($ExecApprovalsBackup) -and (Test-Path $ExecApprovalsBackup)) {
    Copy-Item -Path $ExecApprovalsBackup -Destination $approvalsTarget -Force
    Write-Host "Restored: $approvalsTarget"
}
else {
    Write-Warning "No exec-approvals backup restored."
}

Write-Host "Rollback complete. Restart OpenClaw gateway."
