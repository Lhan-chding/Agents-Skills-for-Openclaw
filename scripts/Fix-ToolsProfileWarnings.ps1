param(
    [string]$OpenClawHome = "$env:USERPROFILE\.openclaw",
    [string]$Workspace = "$env:USERPROFILE\.openclaw\workspace",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot "Apply-OpenClawPatch.ps1") -OpenClawHome $OpenClawHome -DryRun:$DryRun
& (Join-Path $PSScriptRoot "Set-ExecApprovals.ps1") -OpenClawHome $OpenClawHome -DryRun:$DryRun

if (-not $DryRun) {
    Write-Host "Patch applied. Restart OpenClaw gateway, then run verification:"
    Write-Host "  .\Verify-OpenClawCapabilityPack.ps1 -OpenClawHome `"$OpenClawHome`" -Workspace `"$Workspace`""
}
