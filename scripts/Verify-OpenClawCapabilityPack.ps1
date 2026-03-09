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

$managedSkillsPath = Join-Path $OpenClawHome "skills"
$workspaceSkillsPath = Join-Path $Workspace "skills"
$expectedSkills = @(
    "research-first-secure-coding",
    "paper-reading-formula-tutor",
    "writing-feishu-copilot",
    "feishu-chat-admin-bridge",
    "memory-curator"
)
foreach ($skill in $expectedSkills) {
    $workspacePath = Join-Path $workspaceSkillsPath $skill
    $managedPath = Join-Path $managedSkillsPath $skill

    # Workspace skills are required to avoid sandbox path-escape reads.
    Add-Check -Name "skill.workspace:$skill" -Ok (Test-Path $workspacePath) -Detail $workspacePath
    Add-Check -Name "skill.managed:$skill" -Ok (Test-Path $managedPath) -Detail $managedPath -Required $false
}

$workspaceFiles = @("AGENTS.md", "TOOLS.md", "MEMORY.md", "BOOT.md")
foreach ($file in $workspaceFiles) {
    $path = Join-Path $Workspace $file
    Add-Check -Name "workspace:$file" -Ok (Test-Path $path) -Detail $path
}

$workspaceBridgeScripts = @(
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
foreach ($script in $workspaceBridgeScripts) {
    $path = Join-Path $Workspace "scripts\$script"
    Add-Check -Name "workspace-script:$script" -Ok (Test-Path $path) -Detail $path
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
    Add-Check -Name "config:default.scope=agent" -Ok ((Get-Value -Obj $cfg -PathSegments @("agents", "defaults", "sandbox", "scope")) -eq "agent") -Detail "agents.defaults.sandbox.scope"

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
        Add-Check -Name "config:dev.tools.profile=full" -Ok ($devAgent.tools.profile -eq "full") -Detail "agents.list[id=dev].tools.profile"
        Add-Check -Name "config:dev.workspace=rw" -Ok ($devAgent.sandbox.workspaceAccess -eq "rw") -Detail "agents.list[id=dev].sandbox.workspaceAccess"
        Add-Check -Name "config:dev.scope=agent" -Ok ($devAgent.sandbox.scope -eq "agent") -Detail "agents.list[id=dev].sandbox.scope"

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

        $feishuToolBaseline = @("feishu_chat", "feishu_doc", "feishu_app_scopes")
        $missingFeishuTools = @()
        foreach ($t in $feishuToolBaseline) {
            if ($allow -notcontains $t) {
                $missingFeishuTools += $t
            }
        }
        Add-Check -Name "config:dev.allowlist-feishu-tools-enabled" -Ok ($missingFeishuTools.Count -eq 0) -Detail ("missing={0}" -f ($missingFeishuTools -join ","))
    }

    Add-Check -Name "config:approvals.exec.enabled=true" -Ok ((Get-Value -Obj $cfg -PathSegments @("approvals", "exec", "enabled")) -eq $true) -Detail "approvals.exec.enabled"
    Add-Check -Name "config:hooks.session-memory=enabled" -Ok ((Get-Value -Obj $cfg -PathSegments @("hooks", "internal", "entries", "session-memory", "enabled")) -eq $true) -Detail "hooks.internal.entries.session-memory.enabled"
    Add-Check -Name "config:hooks.boot-md=enabled" -Ok ((Get-Value -Obj $cfg -PathSegments @("hooks", "internal", "entries", "boot-md", "enabled")) -eq $true) -Detail "hooks.internal.entries.boot-md.enabled"

    $fallbacks = @()
    $fallbackValue = Get-Value -Obj $cfg -PathSegments @("agents", "defaults", "model", "fallbacks")
    if ($fallbackValue) {
        $fallbacks = @($fallbackValue)
    }

    $authProviders = @()
    $authProfiles = Get-Value -Obj $cfg -PathSegments @("auth", "profiles")
    if ($authProfiles) {
        if ($authProfiles -is [System.Collections.IDictionary]) {
            foreach ($key in $authProfiles.Keys) {
                $profile = $authProfiles[$key]
                if ($null -ne $profile -and $profile.PSObject.Properties.Name -contains "provider") {
                    $authProviders += [string]$profile.provider
                }
            }
        }
        else {
            foreach ($profile in @($authProfiles)) {
                if ($null -ne $profile -and $profile.PSObject.Properties.Name -contains "provider") {
                    $authProviders += [string]$profile.provider
                }
            }
        }
    }
    $authProviders = @($authProviders | Select-Object -Unique)

    $missingFallbackProviders = @()
    foreach ($fallback in $fallbacks) {
        $provider = ([string]$fallback -split "/")[0]
        if (-not [string]::IsNullOrWhiteSpace($provider) -and $authProviders -notcontains $provider) {
            $missingFallbackProviders += [string]$fallback
        }
    }
    Add-Check -Name "advisory:model.fallbacks-authenticated" -Ok ($missingFallbackProviders.Count -eq 0) -Detail ("missing={0}" -f ($missingFallbackProviders -join ",")) -Required $false
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
            if ($line -notmatch "tools\.profile \(coding\) allowlist contains unknown entries|LLM request timed out|lane wait exceeded|API rate limit reached|No API key found for provider ""openrouter""") {
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
        Add-Check -Name "advisory:latest-log-no-known-routing-warnings" -Ok ($warningHits.Count -eq 0) -Detail $detail -Required $false
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

    try {
        $skillInfoRaw = & openclaw.cmd skills info feishu-chat-admin-bridge --json 2>$null
        $skillInfoText = [string]$skillInfoRaw
        $isWorkspaceSource = $skillInfoText -match "\\.openclaw[\\/]+workspace[\\/]+skills"
        Add-Check -Name "advisory:skills-info-from-workspace" -Ok $isWorkspaceSource -Detail "openclaw.cmd skills info feishu-chat-admin-bridge --json" -Required $false
    }
    catch {
        Add-Check -Name "advisory:skills-info-from-workspace" -Ok $false -Detail $_.Exception.Message -Required $false
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
