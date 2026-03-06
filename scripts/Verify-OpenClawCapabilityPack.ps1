param(
    [string]$OpenClawHome = "$env:USERPROFILE\.openclaw",
    [string]$Workspace = "$env:USERPROFILE\.openclaw\workspace"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$checks = @()

function Add-Check {
    param(
        [string]$Name,
        [bool]$Ok,
        [string]$Detail,
        [bool]$Required = $true
    )
    $script:checks += [pscustomobject]@{
        Name = $Name
        Ok = $Ok
        Required = $Required
        Detail = $Detail
    }
}

function Get-Value {
    param(
        [object]$Obj,
        [string[]]$PathSegments
    )
    $cur = $Obj
    foreach ($seg in $PathSegments) {
        if ($null -eq $cur) { return $null }
        if ($cur -is [System.Collections.IDictionary]) {
            if (-not $cur.Contains($seg)) { return $null }
            $cur = $cur[$seg]
            continue
        }
        if ($cur.PSObject.Properties.Name -contains $seg) {
            $cur = $cur.$seg
            continue
        }
        return $null
    }
    return $cur
}

$skillsPath = Join-Path $OpenClawHome "skills"
$expectedSkills = @(
    "research-first-secure-coding",
    "paper-reading-formula-tutor",
    "writing-feishu-copilot",
    "memory-curator"
)
foreach ($skill in $expectedSkills) {
    $path = Join-Path $skillsPath $skill
    Add-Check -Name "skill:$skill" -Ok (Test-Path $path) -Detail $path
}

$workspaceFiles = @("AGENTS.md", "TOOLS.md", "MEMORY.md", "BOOT.md")
foreach ($file in $workspaceFiles) {
    $path = Join-Path $Workspace $file
    Add-Check -Name "workspace:$file" -Ok (Test-Path $path) -Detail $path
}

$today = Get-Date -Format "yyyy-MM-dd"
$todayMemory = Join-Path $Workspace "memory\$today.md"
Add-Check -Name "memory:daily-file" -Ok (Test-Path $todayMemory) -Detail $todayMemory

$configPath = Join-Path $OpenClawHome "openclaw.json"
Add-Check -Name "config:openclaw.json" -Ok (Test-Path $configPath) -Detail $configPath

if (Test-Path $configPath) {
    $cfg = Get-Content -Raw -Encoding UTF8 $configPath | ConvertFrom-Json

    Add-Check -Name "config:tools.profile=minimal" -Ok ((Get-Value -Obj $cfg -PathSegments @("tools", "profile")) -eq "minimal") -Detail "tools.profile"
    Add-Check -Name "config:memory.provider=local" -Ok ((Get-Value -Obj $cfg -PathSegments @("agents", "defaults", "memorySearch", "provider")) -eq "local") -Detail "agents.defaults.memorySearch.provider"
    Add-Check -Name "config:memory.fallback=none" -Ok ((Get-Value -Obj $cfg -PathSegments @("agents", "defaults", "memorySearch", "fallback")) -eq "none") -Detail "agents.defaults.memorySearch.fallback"
    Add-Check -Name "config:default.workspace=ro" -Ok ((Get-Value -Obj $cfg -PathSegments @("agents", "defaults", "sandbox", "workspaceAccess")) -eq "ro") -Detail "agents.defaults.sandbox.workspaceAccess"

    $agents = Get-Value -Obj $cfg -PathSegments @("agents", "list")
    $devAgent = $null
    $agentItems = @()
    if ($null -ne $agents) {
        $agentItems = @($agents)
    }
    foreach ($a in $agentItems) {
        if ($a.id -eq "dev") {
            $devAgent = $a
            break
        }
    }
    Add-Check -Name "config:dev-agent-exists" -Ok ($null -ne $devAgent) -Detail "agents.list[id=dev]"

    if ($null -ne $devAgent) {
        Add-Check -Name "config:dev.tools.profile=minimal" -Ok ($devAgent.tools.profile -eq "minimal") -Detail "agents.list[id=dev].tools.profile"
        Add-Check -Name "config:dev.workspace=rw" -Ok ($devAgent.sandbox.workspaceAccess -eq "rw") -Detail "agents.list[id=dev].sandbox.workspaceAccess"

        $allow = @()
        if ($devAgent.tools.allow) {
            $allow = @($devAgent.tools.allow)
        }
        $hasBad = $false
        foreach ($token in @("apply_patch", "image", "cron")) {
            if ($allow -contains $token) {
                $hasBad = $true
            }
        }
        Add-Check -Name "config:dev.allowlist-no-apply_patch-image-cron" -Ok (-not $hasBad) -Detail ("tools.allow={0}" -f ($allow -join ","))
    }

    Add-Check -Name "config:approvals.exec.enabled=true" -Ok ((Get-Value -Obj $cfg -PathSegments @("approvals", "exec", "enabled")) -eq $true) -Detail "approvals.exec.enabled"
    Add-Check -Name "config:hooks.session-memory=enabled" -Ok ((Get-Value -Obj $cfg -PathSegments @("hooks", "internal", "entries", "session-memory", "enabled")) -eq $true) -Detail "hooks.internal.entries.session-memory.enabled"
    Add-Check -Name "config:hooks.boot-md=enabled" -Ok ((Get-Value -Obj $cfg -PathSegments @("hooks", "internal", "entries", "boot-md", "enabled")) -eq $true) -Detail "hooks.internal.entries.boot-md.enabled"
}

$approvalsPath = Join-Path $OpenClawHome "exec-approvals.json"
Add-Check -Name "config:exec-approvals.json" -Ok (Test-Path $approvalsPath) -Detail $approvalsPath
if (Test-Path $approvalsPath) {
    $approvals = Get-Content -Raw -Encoding UTF8 $approvalsPath | ConvertFrom-Json
    Add-Check -Name "approvals:defaults.ask=always" -Ok ($approvals.defaults.ask -eq "always") -Detail "defaults.ask"
    Add-Check -Name "approvals:defaults.security=allowlist" -Ok ($approvals.defaults.security -eq "allowlist") -Detail "defaults.security"
}

$logDir = Join-Path $env:LOCALAPPDATA "Temp\openclaw"
if (Test-Path $logDir) {
    $latestLog = Get-ChildItem $logDir -Filter "openclaw-*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($null -ne $latestLog) {
        $recentThreshold = (Get-Date).AddMinutes(-45)
        $warningHits = @()
        foreach ($line in (Get-Content -Path $latestLog.FullName)) {
            if ($line -notmatch "tools\.profile \(coding\) allowlist contains unknown entries") {
                continue
            }
            try {
                $obj = $line | ConvertFrom-Json
                $lineTime = [datetime]$obj.time
                if ($lineTime -ge $recentThreshold) {
                    $warningHits += $line
                }
            }
            catch {
                continue
            }
        }
        $detail = "{0} (window >= {1:yyyy-MM-dd HH:mm})" -f $latestLog.FullName, $recentThreshold
        Add-Check -Name "advisory:latest-log-no-coding-profile-warning" -Ok ($warningHits.Count -eq 0) -Detail $detail -Required $false
    }
    else {
        Add-Check -Name "advisory:openclaw-log-present" -Ok $false -Detail $logDir -Required $false
    }
}
else {
    Add-Check -Name "advisory:openclaw-log-dir-present" -Ok $false -Detail $logDir -Required $false
}

$cli = Get-Command openclaw.cmd -ErrorAction SilentlyContinue
if ($null -ne $cli) {
    try {
        $null = & openclaw.cmd skills check 2>$null
        Add-Check -Name "advisory:openclaw.skills.check-ran" -Ok $true -Detail "openclaw.cmd skills check" -Required $false
    }
    catch {
        Add-Check -Name "advisory:openclaw.skills.check-ran" -Ok $false -Detail $_.Exception.Message -Required $false
    }
}
else {
    Add-Check -Name "advisory:openclaw.cmd-present" -Ok $false -Detail "openclaw.cmd not found" -Required $false
}

$checks | Sort-Object Name | Format-Table -AutoSize

$failedRequired = @($checks | Where-Object { $_.Required -and -not $_.Ok })
if ($failedRequired.Count -gt 0) {
    Write-Host ""
    Write-Host "Required checks failed:" -ForegroundColor Red
    $failedRequired | ForEach-Object { Write-Host ("- {0}: {1}" -f $_.Name, $_.Detail) -ForegroundColor Red }
    exit 1
}

Write-Host ""
Write-Host "All required checks passed." -ForegroundColor Green
