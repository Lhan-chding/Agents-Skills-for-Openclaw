param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,

    [string]$Workspace = "$env:USERPROFILE\.openclaw\workspace",
    [string]$DestinationSubdir = "imports",

    [switch]$Force,
    [switch]$DryRun,
    [string]$ApprovalText = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$requiredApproval = "APPROVE_WORKSPACE_IMPORT"

if (-not $DryRun.IsPresent -and $ApprovalText -ne $requiredApproval) {
    throw "Real execution requires -ApprovalText $requiredApproval"
}

$resolvedSource = (Resolve-Path -Path $SourcePath -ErrorAction Stop).Path
$sourceItem = Get-Item -LiteralPath $resolvedSource -ErrorAction Stop
$importsRoot = Join-Path $Workspace $DestinationSubdir
$manifestPath = Join-Path $importsRoot ".sync-manifest.jsonl"

function Ensure-Directory {
    param([string]$Path)
    if ($DryRun) {
        if (-not (Test-Path $Path)) {
            Write-Host "[DryRun] Would create directory: $Path"
        }
        return
    }
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Get-DestinationPath {
    param(
        [string]$Root,
        [string]$SourceResolvedPath,
        [bool]$IsDirectory
    )

    $safeRel = ($SourceResolvedPath.TrimStart('\') -replace '[:\\/]+', '_')
    if ([string]::IsNullOrWhiteSpace($safeRel)) {
        $safeRel = "imported_item"
    }

    if ($IsDirectory) {
        return (Join-Path $Root $safeRel)
    }

    return (Join-Path $Root $safeRel)
}

Ensure-Directory -Path $Workspace
Ensure-Directory -Path $importsRoot

$destinationPath = Get-DestinationPath -Root $importsRoot -SourceResolvedPath $resolvedSource -IsDirectory $sourceItem.PSIsContainer

if (Test-Path $destinationPath) {
    if (-not $Force.IsPresent) {
        throw "Destination already exists: $destinationPath (use -Force to overwrite)"
    }

    if ($DryRun) {
        Write-Host "[DryRun] Would remove existing destination: $destinationPath"
    }
    else {
        Remove-Item -LiteralPath $destinationPath -Recurse -Force
    }
}

if ($DryRun) {
    Write-Host "[DryRun] Would copy from: $resolvedSource"
    Write-Host "[DryRun] Would copy to:   $destinationPath"
    exit 0
}

if ($sourceItem.PSIsContainer) {
    Copy-Item -Path $resolvedSource -Destination $destinationPath -Recurse -Force
}
else {
    Copy-Item -Path $resolvedSource -Destination $destinationPath -Force
}

$record = [ordered]@{
    at = (Get-Date).ToString("s")
    source = $resolvedSource
    destination = $destinationPath
    mode = if ($sourceItem.PSIsContainer) { "directory" } else { "file" }
}

$recordLine = $record | ConvertTo-Json -Depth 5 -Compress
Add-Content -Path $manifestPath -Value $recordLine -Encoding UTF8

Write-Host "Imported to workspace sandbox path:" -ForegroundColor Green
Write-Host "  $destinationPath"
Write-Host "Manifest updated:" -ForegroundColor Green
Write-Host "  $manifestPath"
