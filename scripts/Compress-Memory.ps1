param(
    [string]$Workspace = "$env:USERPROFILE\.openclaw\workspace",
    [int]$OlderThanDays = 7,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-SectionBullets {
    param(
        [string]$Content,
        [string]$Heading
    )

    $pattern = "(?ms)^##\s+$([regex]::Escape($Heading))\s*\r?\n(.*?)(?=^##\s+|\z)"
    $m = [regex]::Match($Content, $pattern)
    if (-not $m.Success) { return @() }

    $lines = $m.Groups[1].Value -split "\r?\n"
    $bullets = @()
    foreach ($line in $lines) {
        $trim = $line.Trim()
        if ($trim.StartsWith("- ")) {
            $bullets += $trim.Substring(2).Trim()
        }
    }
    return $bullets
}

$memoryDir = Join-Path $Workspace "memory"
$archiveDir = Join-Path $memoryDir "archive"

if (-not (Test-Path $memoryDir)) {
    throw "Memory directory not found: $memoryDir"
}

New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null

$cutoff = (Get-Date).Date.AddDays(-$OlderThanDays)
$files = @(Get-ChildItem -Path $memoryDir -File | Where-Object {
    $_.Name -match "^\d{4}-\d{2}-\d{2}\.md$" -and $_.LastWriteTime -lt $cutoff
})

if ($files.Count -eq 0) {
    Write-Host "No eligible memory files to compress."
    exit 0
}

$bucket = @{}

foreach ($file in $files) {
    $date = [datetime]::ParseExact($file.BaseName, "yyyy-MM-dd", $null)
    $monthKey = $date.ToString("yyyy-MM")
    if (-not $bucket.ContainsKey($monthKey)) {
        $bucket[$monthKey] = @{
            DurableFacts = @()
            Preferences = @()
            Decisions = @()
            OpenLoops = @()
            Risks = @()
        }
    }

    $content = Get-Content -Raw $file.FullName

    foreach ($item in (Get-SectionBullets -Content $content -Heading "Durable Facts Candidate")) {
        $bucket[$monthKey]["DurableFacts"] += "- [$($file.BaseName)] $item"
    }
    foreach ($item in (Get-SectionBullets -Content $content -Heading "Preferences Observed Today")) {
        $bucket[$monthKey]["Preferences"] += "- [$($file.BaseName)] $item"
    }
    foreach ($item in (Get-SectionBullets -Content $content -Heading "Decisions Taken Today")) {
        $bucket[$monthKey]["Decisions"] += "- [$($file.BaseName)] $item"
    }
    foreach ($item in (Get-SectionBullets -Content $content -Heading "Open Loops")) {
        $bucket[$monthKey]["OpenLoops"] += "- [$($file.BaseName)] $item"
    }
    foreach ($item in (Get-SectionBullets -Content $content -Heading "Risks / Blockers")) {
        $bucket[$monthKey]["Risks"] += "- [$($file.BaseName)] $item"
    }
}

foreach ($monthKey in $bucket.Keys | Sort-Object) {
    $entry = $bucket[$monthKey]
    $outPath = Join-Path $archiveDir "$monthKey.md"

    $lines = @()
    $lines += "# Memory Archive $monthKey"
    $lines += ""
    $lines += "Generated at: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")"
    $lines += "Source retention: raw daily files are kept; this archive is additive."
    $lines += ""
    $lines += "## Durable Facts Candidate"
    $lines += if ($entry["DurableFacts"].Count -gt 0) { $entry["DurableFacts"] } else { "- (none)" }
    $lines += ""
    $lines += "## Preferences Observed"
    $lines += if ($entry["Preferences"].Count -gt 0) { $entry["Preferences"] } else { "- (none)" }
    $lines += ""
    $lines += "## Decisions"
    $lines += if ($entry["Decisions"].Count -gt 0) { $entry["Decisions"] } else { "- (none)" }
    $lines += ""
    $lines += "## Open Loops"
    $lines += if ($entry["OpenLoops"].Count -gt 0) { $entry["OpenLoops"] } else { "- (none)" }
    $lines += ""
    $lines += "## Risks / Blockers"
    $lines += if ($entry["Risks"].Count -gt 0) { $entry["Risks"] } else { "- (none)" }
    $lines += ""

    if ($DryRun) {
        Write-Host "[DryRun] Would write archive: $outPath"
    }
    else {
        $lines -join "`r`n" | Set-Content -Path $outPath -Encoding UTF8
        Write-Host "Wrote archive: $outPath"
    }
}
