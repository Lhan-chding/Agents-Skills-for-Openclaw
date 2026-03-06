param(
    [string]$OpenClawHome = "$env:USERPROFILE\.openclaw",
    [string]$PatchPath = "$PSScriptRoot\..\config\openclaw.patch.json",
    [string]$ConfigPath = "",
    [string]$BackupRoot = "",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Convert-ToHashtable {
    param([Parameter(ValueFromPipeline = $true)]$InputObject)

    if ($null -eq $InputObject) { return $null }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $ht = @{}
        foreach ($key in $InputObject.Keys) {
            $ht[$key] = Convert-ToHashtable $InputObject[$key]
        }
        return $ht
    }

    if (($InputObject -is [System.Collections.IEnumerable]) -and -not ($InputObject -is [string])) {
        $arr = @()
        foreach ($item in $InputObject) {
            $arr += ,(Convert-ToHashtable $item)
        }
        return ,$arr
    }

    if ($InputObject -is [pscustomobject]) {
        $ht = @{}
        foreach ($prop in $InputObject.PSObject.Properties) {
            $ht[$prop.Name] = Convert-ToHashtable $prop.Value
        }
        return $ht
    }

    return $InputObject
}

function Test-IsArrayOfObjectsWithId {
    param([object[]]$ArrayValue)
    if ($null -eq $ArrayValue -or $ArrayValue.Count -eq 0) {
        return $false
    }
    foreach ($item in $ArrayValue) {
        if (-not ($item -is [hashtable])) {
            return $false
        }
        if (-not $item.ContainsKey("id")) {
            return $false
        }
    }
    return $true
}

function Merge-ArrayById {
    param(
        [object[]]$BaseArray,
        [object[]]$PatchArray,
        [string]$Path
    )

    if (-not (Test-IsArrayOfObjectsWithId $BaseArray) -or -not (Test-IsArrayOfObjectsWithId $PatchArray)) {
        return ,$PatchArray
    }

    $merged = @()
    foreach ($item in $BaseArray) {
        $merged += ,$item
    }

    foreach ($patchItem in $PatchArray) {
        $matchIndex = -1
        for ($i = 0; $i -lt $merged.Count; $i++) {
            $candidate = $merged[$i]
            if (($candidate -is [hashtable]) -and $candidate.ContainsKey("id") -and ($candidate["id"] -eq $patchItem["id"])) {
                $matchIndex = $i
                break
            }
        }

        if ($matchIndex -ge 0) {
            $merged[$matchIndex] = Merge-Value -BaseValue $merged[$matchIndex] -PatchValue $patchItem -Path "$Path[$matchIndex]"
        }
        else {
            $merged += ,$patchItem
        }
    }

    return ,$merged
}

function Merge-Value {
    param(
        [object]$BaseValue,
        [object]$PatchValue,
        [string]$Path = ""
    )

    if (($BaseValue -is [hashtable]) -and ($PatchValue -is [hashtable])) {
        foreach ($key in $PatchValue.Keys) {
            if ($BaseValue.ContainsKey($key)) {
                $childPath = if ([string]::IsNullOrWhiteSpace($Path)) { $key } else { "$Path.$key" }
                $BaseValue[$key] = Merge-Value -BaseValue $BaseValue[$key] -PatchValue $PatchValue[$key] -Path $childPath
            }
            else {
                $BaseValue[$key] = $PatchValue[$key]
            }
        }
        return $BaseValue
    }

    if (($BaseValue -is [object[]]) -and ($PatchValue -is [object[]])) {
        if ($Path -eq "agents.list") {
            return Merge-ArrayById -BaseArray $BaseValue -PatchArray $PatchValue -Path $Path
        }
        return ,$PatchValue
    }

    return $PatchValue
}

function Write-BackupFile {
    param(
        [string]$SourcePath,
        [string]$DestinationRoot,
        [string]$Prefix
    )

    New-Item -ItemType Directory -Path $DestinationRoot -Force | Out-Null
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $backup = Join-Path $DestinationRoot "$Prefix.$timestamp.bak"
    Copy-Item -Path $SourcePath -Destination $backup -Force
    return $backup
}

if (-not (Test-Path $PatchPath)) {
    throw "Patch file not found: $PatchPath"
}

if (-not (Test-Path $OpenClawHome)) {
    if ($DryRun) {
        Write-Host "[DryRun] Would create OpenClaw home: $OpenClawHome"
    }
    else {
        New-Item -ItemType Directory -Path $OpenClawHome -Force | Out-Null
    }
}

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $OpenClawHome "openclaw.json"
}

if ([string]::IsNullOrWhiteSpace($BackupRoot)) {
    $BackupRoot = Join-Path $OpenClawHome "backups\capability-pack"
}

if (-not (Test-Path $ConfigPath)) {
    if ($DryRun) {
        Write-Host "[DryRun] Would create config: $ConfigPath"
    }
    else {
        "{}" | Set-Content -Path $ConfigPath -Encoding UTF8
    }
}

$baseRaw = if (Test-Path $ConfigPath) { Get-Content -Raw -Encoding UTF8 $ConfigPath } else { "{}" }
$patchRaw = Get-Content -Raw -Encoding UTF8 $PatchPath

$baseObj = Convert-ToHashtable ($baseRaw | ConvertFrom-Json)
$patchObj = Convert-ToHashtable ($patchRaw | ConvertFrom-Json)

if ($null -eq $baseObj) { $baseObj = @{} }
if ($null -eq $patchObj) { throw "Patch file is empty: $PatchPath" }

$merged = Merge-Value -BaseValue $baseObj -PatchValue $patchObj -Path ""

if ($DryRun) {
    Write-Host "[DryRun] Would merge patch into: $ConfigPath"
    Write-Host "[DryRun] Patch keys:" ($patchObj.Keys -join ", ")
    exit 0
}

$backupPath = Write-BackupFile -SourcePath $ConfigPath -DestinationRoot $BackupRoot -Prefix "openclaw.json"
$manifestPath = Join-Path $BackupRoot "last-openclaw-backup.json"
$manifest = @{
    createdAt = (Get-Date).ToString("s")
    source = $ConfigPath
    backup = $backupPath
    patchPath = (Resolve-Path $PatchPath).Path
}
$manifest | ConvertTo-Json -Depth 10 | Set-Content -Path $manifestPath -Encoding UTF8

$merged | ConvertTo-Json -Depth 100 | Set-Content -Path $ConfigPath -Encoding UTF8

Write-Host "Patched: $ConfigPath"
Write-Host "Backup:  $backupPath"
Write-Host "Record:  $manifestPath"
