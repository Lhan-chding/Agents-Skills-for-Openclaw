param(
    [string]$OpenClawHome = "$env:USERPROFILE\.openclaw",
    [string]$SourcePath = "$PSScriptRoot\..\config\exec-approvals.recommended.json",
    [switch]$UseCli,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$targetPath = Join-Path $OpenClawHome "exec-approvals.json"
$backupRoot = Join-Path $OpenClawHome "backups\capability-pack"

if (-not (Test-Path $SourcePath)) {
    throw "Source file not found: $SourcePath"
}

$sourceRaw = Get-Content -Raw -Encoding UTF8 $SourcePath
$null = $sourceRaw | ConvertFrom-Json

if (-not (Test-Path $OpenClawHome)) {
    if ($DryRun) {
        Write-Host "[DryRun] Would create OpenClaw home: $OpenClawHome"
    }
    else {
        New-Item -ItemType Directory -Path $OpenClawHome -Force | Out-Null
    }
}

if ($DryRun) {
    Write-Host "[DryRun] Would update exec approvals: $targetPath"
    Write-Host "[DryRun] Source: $SourcePath"
    if ($UseCli) {
        Write-Host "[DryRun] Would call: openclaw.cmd approvals set --file `"$targetPath`""
    }
    exit 0
}

if (Test-Path $targetPath) {
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    $backup = Join-Path $backupRoot ("exec-approvals.json.{0}.bak" -f (Get-Date -Format "yyyyMMddHHmmss"))
    Copy-Item -Path $targetPath -Destination $backup -Force
    Write-Host "Backup:  $backup"
}

$sourceRaw | Set-Content -Path $targetPath -Encoding UTF8
Write-Host "Updated: $targetPath"

if ($UseCli) {
    $cliCmd = Get-Command openclaw.cmd -ErrorAction SilentlyContinue
    if ($null -eq $cliCmd) {
        Write-Warning "openclaw.cmd not found. Skipped CLI sync."
        exit 0
    }

    & openclaw.cmd approvals set --file $targetPath | Out-Host
}
