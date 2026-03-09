param(
    [string]$OpenClawHome = "$env:USERPROFILE\.openclaw",
    [string]$Workspace = "$env:USERPROFILE\.openclaw\workspace",
    [string]$TaskName = "OpenClaw-MorningDigestCache-0705"
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

try {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
    Add-Check -Name 'scheduled-task:exists' -Ok $true -Detail $task.TaskName
}
catch {
    Add-Check -Name 'scheduled-task:exists' -Ok $false -Detail $TaskName
}

$today = Get-Date -Format 'yyyy-MM-dd'
$cachePath = Join-Path $Workspace "cache\morning-digest\$today.json"
$cacheRequired = ((Get-Date).TimeOfDay -ge [TimeSpan]::FromHours(7.25))
Add-Check -Name 'cache:today-file' -Ok (Test-Path $cachePath) -Detail $cachePath -Required $cacheRequired

if (Test-Path $cachePath) {
    $cache = Get-Content -Raw -Encoding UTF8 $cachePath | ConvertFrom-Json
    foreach ($path in @(
        @('region'),
        @('weather', 'summary'),
        @('weather', 'umbrella'),
        @('plan', 'main_task'),
        @('plan', 'morning'),
        @('plan', 'afternoon'),
        @('plan', 'evening'),
        @('news', 'valorant'),
        @('news', 'kpl'),
        @('news', 'football', 'laliga'),
        @('news', 'football', 'epl'),
        @('news', 'football', 'ucl'),
        @('news', 'international')
    )) {
        $name = 'cache:' + ($path -join '.')
        $value = Get-Value -Obj $cache -PathSegments $path
        $ok = -not [string]::IsNullOrWhiteSpace([string]$value)
        Add-Check -Name $name -Ok $ok -Detail ([string]$value)
    }
}

$cli = Get-Command openclaw.cmd -ErrorAction SilentlyContinue
if ($null -ne $cli) {
    try {
        $raw = & openclaw.cmd cron list --json
        $jobs = @()
        if (-not [string]::IsNullOrWhiteSpace($raw)) {
            $obj = $raw | ConvertFrom-Json
            if ($null -ne $obj -and $null -ne $obj.jobs) {
                $jobs = @($obj.jobs)
            }
        }

        foreach ($jobName in @('daily-plan-reminder-2200', 'daily-plan-capture-2240', 'daily-plan-weather-summary-0730')) {
            $ok = @($jobs | Where-Object { $_.name -eq $jobName }).Count -gt 0
            Add-Check -Name "cron:$jobName" -Ok $ok -Detail $jobName
        }

        $legacyPrefetch = @($jobs | Where-Object { $_.name -eq 'daily-news-weather-capture-0715' }).Count -eq 0
        Add-Check -Name 'cron:no-legacy-prefetch' -Ok $legacyPrefetch -Detail 'daily-news-weather-capture-0715'

        $tempJobs = @($jobs | Where-Object { $_.name -like 'temp-*' })
        Add-Check -Name 'cron:no-temp-jobs' -Ok ($tempJobs.Count -eq 0) -Detail (($tempJobs | ForEach-Object { $_.name }) -join ',') -Required $false
    }
    catch {
        Add-Check -Name 'cron:list-readable' -Ok $false -Detail $_.Exception.Message -Required $false
    }
}
else {
    Add-Check -Name 'cron:openclaw.cmd-present' -Ok $false -Detail 'openclaw.cmd not found' -Required $false
}

$configPath = Join-Path $OpenClawHome 'openclaw.json'
if (Test-Path $configPath) {
    $cfg = Get-Content -Raw -Encoding UTF8 $configPath | ConvertFrom-Json
    $fallbacks = @()
    $fallbackValue = Get-Value -Obj $cfg -PathSegments @('agents', 'defaults', 'model', 'fallbacks')
    if ($fallbackValue) { $fallbacks = @($fallbackValue) }

    $providers = @()
    $authProfiles = Get-Value -Obj $cfg -PathSegments @('auth', 'profiles')
    if ($authProfiles) {
        if ($authProfiles -is [System.Collections.IDictionary]) {
            foreach ($key in $authProfiles.Keys) {
                $profile = $authProfiles[$key]
                if ($null -ne $profile -and $profile.PSObject.Properties.Name -contains 'provider') {
                    $providers += [string]$profile.provider
                }
            }
        }
        else {
            foreach ($profile in @($authProfiles)) {
                if ($null -ne $profile -and $profile.PSObject.Properties.Name -contains 'provider') {
                    $providers += [string]$profile.provider
                }
            }
        }
    }
    $providers = @($providers | Select-Object -Unique)

    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($fallback in $fallbacks) {
        $provider = ([string]$fallback -split '/')[0]
        if (-not [string]::IsNullOrWhiteSpace($provider) -and $providers -notcontains $provider) {
            $missing.Add([string]$fallback)
        }
    }
    Add-Check -Name 'config:fallback-providers-authenticated' -Ok ($missing.Count -eq 0) -Detail (($missing | Select-Object -Unique) -join ',') -Required $false
}

$logDir = Join-Path $env:LOCALAPPDATA 'Temp\openclaw'
if (Test-Path $logDir) {
    $latestLog = Get-ChildItem $logDir -Filter 'openclaw-*.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($null -ne $latestLog) {
        $recent = Get-Content -Path $latestLog.FullName | Select-Object -Last 4000
        $patterns = @(
            @{ Name = 'log:no-lane-wait-exceeded'; Pattern = 'lane wait exceeded' },
            @{ Name = 'log:no-llm-timeout'; Pattern = 'LLM request timed out' },
            @{ Name = 'log:no-rate-limit'; Pattern = 'API rate limit reached' },
            @{ Name = 'log:no-openrouter-auth-miss'; Pattern = 'No API key found for provider "openrouter"' }
        )
        foreach ($p in $patterns) {
            $hit = @($recent | Where-Object { $_ -match [regex]::Escape($p.Pattern) }).Count
            Add-Check -Name $p.Name -Ok ($hit -eq 0) -Detail $latestLog.FullName -Required $false
        }
    }
}

$checks | Sort-Object Name | Format-Table -AutoSize

$failedRequired = @($checks | Where-Object { $_.Required -and -not $_.Ok })
if ($failedRequired.Count -gt 0) {
    Write-Host ''
    Write-Host 'Required checks failed:' -ForegroundColor Red
    $failedRequired | ForEach-Object { Write-Host ('- {0}: {1}' -f $_.Name, $_.Detail) -ForegroundColor Red }
    exit 1
}

Write-Host ''
Write-Host 'Morning digest pipeline checks passed.' -ForegroundColor Green
