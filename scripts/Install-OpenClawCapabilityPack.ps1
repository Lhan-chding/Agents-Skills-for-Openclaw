param(
    [string]$OpenClawHome = "$env:USERPROFILE\.openclaw",
    [string]$Workspace = "$env:USERPROFILE\.openclaw\workspace",
    [switch]$Force,
    [switch]$DryRun,
    [switch]$SkipPatch,
    [switch]$SkipApprovals
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$packRoot = Split-Path -Parent $PSScriptRoot
$skillsSrc = Join-Path $packRoot "skills"
$scriptsSrc = Join-Path $packRoot "scripts"
$workspaceTpl = Join-Path $packRoot "workspace-templates"
$managedSkillsDst = Join-Path $OpenClawHome "skills"
$workspaceSkillsDst = Join-Path $Workspace "skills"
$workspaceScriptsDst = Join-Path $Workspace "scripts"
$memoryDir = Join-Path $Workspace "memory"
$backupRoot = Join-Path $OpenClawHome "backups\capability-pack"

function Ensure-Dir {
    param([string]$Path)
    if ($DryRun) {
        if (-not (Test-Path $Path)) { Write-Host "[DryRun] Would create directory: $Path" }
        return
    }
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Backup-IfExists {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return }
    if ($DryRun) {
        Write-Host "[DryRun] Would backup existing path: $Path"
        return
    }
    Ensure-Dir -Path $backupRoot
    $stamp = Get-Date -Format "yyyyMMddHHmmss"
    $name = [IO.Path]::GetFileName($Path)
    $backup = Join-Path $backupRoot ("{0}.{1}.bak" -f $name, $stamp)
    if ((Get-Item $Path).PSIsContainer) {
        Copy-Item -Recurse -Force $Path $backup
    }
    else {
        Copy-Item -Force $Path $backup
    }
    Write-Host "Backup: $backup"
}

function Copy-Path {
    param(
        [string]$Source,
        [string]$Destination
    )

    if (-not (Test-Path $Source)) {
        throw "Source not found: $Source"
    }

    if (Test-Path $Destination) {
        if (-not $Force.IsPresent) {
            Write-Host "Skip existing (use -Force to overwrite): $Destination"
            return
        }
        Backup-IfExists -Path $Destination
        if (-not $DryRun) {
            Remove-Item -Recurse -Force $Destination
        }
    }

    if ($DryRun) {
        Write-Host "[DryRun] Would copy: $Source -> $Destination"
        return
    }

    Copy-Item -Recurse -Force $Source $Destination
    Write-Host "Installed: $Destination"
}

Ensure-Dir -Path $OpenClawHome
Ensure-Dir -Path $Workspace
Ensure-Dir -Path $managedSkillsDst
Ensure-Dir -Path $workspaceSkillsDst
Ensure-Dir -Path $workspaceScriptsDst
Ensure-Dir -Path $memoryDir

$skillNames = @(
    "research-first-secure-coding",
    "paper-reading-formula-tutor",
    "writing-feishu-copilot",
    "feishu-chat-admin-bridge",
    "memory-curator"
)

foreach ($name in $skillNames) {
    $src = Join-Path $skillsSrc $name
    $managedDst = Join-Path $managedSkillsDst $name
    $workspaceDst = Join-Path $workspaceSkillsDst $name

    # Keep managed copy for compatibility and workspace copy for sandbox-readable routing.
    Copy-Path -Source $src -Destination $managedDst
    Copy-Path -Source $src -Destination $workspaceDst
}

$bridgeScripts = @(
    "Invoke-FeishuChatAdmin.ps1",
    "Run-FeishuGroupFlow.ps1",
    "Invoke-FeishuChatAdmin.sh",
    "Run-FeishuGroupFlow.sh",
    "Sync-WorkspacePath.ps1",
    "Setup-DailyPlanWeatherCron.ps1",
    "Build-MorningDigestCache.ps1",
    "Install-MorningDigestScheduledTask.ps1",
    "Verify-MorningDigestPipeline.ps1"
)

foreach ($scriptName in $bridgeScripts) {
    $src = Join-Path $scriptsSrc $scriptName
    $dst = Join-Path $workspaceScriptsDst $scriptName
    Copy-Path -Source $src -Destination $dst
}

$workspaceFiles = @("AGENTS.md", "TOOLS.md", "MEMORY.md", "BOOT.md")
foreach ($file in $workspaceFiles) {
    $src = Join-Path $workspaceTpl $file
    $dst = Join-Path $Workspace $file
    Copy-Path -Source $src -Destination $dst
}

$memoryTemplateSrc = Join-Path $workspaceTpl "memory\YYYY-MM-DD.template.md"
$memoryRulesSrc = Join-Path $workspaceTpl "memory\COMPRESSION-RULES.md"
$memoryTemplateDst = Join-Path $memoryDir "YYYY-MM-DD.template.md"
$memoryRulesDst = Join-Path $memoryDir "COMPRESSION-RULES.md"

Copy-Path -Source $memoryTemplateSrc -Destination $memoryTemplateDst
Copy-Path -Source $memoryRulesSrc -Destination $memoryRulesDst

$today = Get-Date -Format "yyyy-MM-dd"
$todayPath = Join-Path $memoryDir "$today.md"
if (-not (Test-Path $todayPath)) {
    if ($DryRun) {
        Write-Host "[DryRun] Would create daily memory file: $todayPath"
    }
    else {
        Copy-Item -Force $memoryTemplateSrc $todayPath
        (Get-Content -Raw -Encoding UTF8 $todayPath).Replace("YYYY-MM-DD", $today) | Set-Content -Path $todayPath -Encoding UTF8
        Write-Host "Created daily memory file: $todayPath"
    }
}

if (-not $SkipPatch.IsPresent) {
    & (Join-Path $PSScriptRoot "Apply-OpenClawPatch.ps1") -OpenClawHome $OpenClawHome -DryRun:$DryRun
}
else {
    Write-Host "Skipped openclaw patch."
}

if (-not $SkipApprovals.IsPresent) {
    & (Join-Path $PSScriptRoot "Set-ExecApprovals.ps1") -OpenClawHome $OpenClawHome -DryRun:$DryRun
}
else {
    Write-Host "Skipped exec approvals update."
}

Write-Host ""
if ($DryRun) {
    Write-Host "Dry-run complete. No files were changed."
}
else {
    Write-Host "Installation complete."
    Write-Host "Next: restart OpenClaw gateway, then run Verify-OpenClawCapabilityPack.ps1."
}
