param(
    [string]$OpenClawHome = "$env:USERPROFILE\.openclaw",
    [string]$Workspace = "$env:USERPROFILE\.openclaw\workspace",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot "Install-OpenClawCapabilityPack.ps1") `
    -OpenClawHome $OpenClawHome `
    -Workspace $Workspace `
    -Force `
    -DryRun:$DryRun
