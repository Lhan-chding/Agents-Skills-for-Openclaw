param(
    [Parameter(Mandatory = $true)]
    [string]$To,

    [string]$Channel = "feishu",
    [string]$Agent = "dev",
    [string]$Timezone = "Asia/Shanghai",

    [string]$Location = "中国·成都市双流区",
    [string]$EveningCron = "0 22 * * *",
    [string]$CaptureCron = "40 22 * * *",
    [string]$MorningCron = "30 7 * * *",

    [string]$EveningJobName = "daily-plan-reminder-2200",
    [string]$CaptureJobName = "daily-plan-capture-2240",
    [string]$LegacyPrefetchJobName = "daily-news-weather-capture-0715",
    [string]$MorningJobName = "daily-plan-weather-summary-0730",
    [string]$SessionKey = "",

    [switch]$Force,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-OpenClaw {
    param([string[]]$CliArgs)
    $cmd = @("openclaw.cmd") + $CliArgs
    if ($DryRun) {
        Write-Host ("[DryRun] " + ($cmd -join " "))
        return $null
    }
    & $cmd[0] $cmd[1..($cmd.Count - 1)]
}

function Get-CronJobs {
    if ($DryRun) { return @() }
    $raw = & openclaw.cmd cron list --json
    if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
    $obj = $raw | ConvertFrom-Json
    if ($null -eq $obj -or $null -eq $obj.jobs) { return @() }
    return @($obj.jobs)
}

function Remove-JobByName {
    param(
        [string]$Name,
        [object[]]$Jobs
    )
    $hit = @($Jobs | Where-Object { $_.name -eq $Name })
    foreach ($j in $hit) {
        $id = [string]$j.id
        if ([string]::IsNullOrWhiteSpace($id)) { continue }
        Write-Host "Removing existing cron job: $Name ($id)"
        Invoke-OpenClaw -CliArgs @("cron", "rm", $id) | Out-Null
    }
}

function Compact-Message {
    param([string]$Text)
    $parts = $Text -split "(`r`n|`n|`r)"
    $clean = @()
    foreach ($p in $parts) {
        $t = $p.Trim()
        if (-not [string]::IsNullOrWhiteSpace($t)) {
            $clean += $t
        }
    }
    $msg = ($clean -join " ~ ")
    $msg = $msg.Replace('"', "'")
    $msg = $msg.Replace("&", " and ")
    $msg = $msg.Replace("|", " / ")
    return $msg
}

if ([string]::IsNullOrWhiteSpace($SessionKey) -and $Channel -eq "feishu" -and $To -like "ou_*") {
    $SessionKey = "agent:${Agent}:feishu:direct:${To}"
}

$eveningMessage = @"
请现在发我明天计划，直接按这 5 项回复即可：
1. 主任务
2. 上午安排
3. 下午安排
4. 晚上安排
5. 风险 / 阻塞
要求：简短、可执行、不要写空话。
"@.Trim()
$eveningMessage = Compact-Message -Text $eveningMessage

$captureMessage = @"
Silent internal task. Do not send user-facing reply.
Goal:
- Find the user's latest plan message from the recent 6 hours.
- Update only memory markdown files.
Rules:
1) Only read/write under memory/.
2) If no valid plan is found, return skipped.
3) If a plan is found, update or create this section in today's memory file:
   ## Tomorrow Plan Capture (for next day)
   - main_task:
   - morning:
   - afternoon:
   - evening:
   - risks:
4) Keep it concise and idempotent.
5) Final output only: captured or skipped.
"@.Trim()
$captureMessage = Compact-Message -Text $captureMessage

$morningMessage = @"
You are a morning brief assistant.
Output language: Chinese.
Region fixed: $Location

Hard tool boundary:
- Read local files only.
- Do not use web_search, web_fetch, browser, or any networked tool.

Read-only inputs:
1) cache/morning-digest/<today>.json
2) memory/<today>.md
3) memory/<yesterday>.md

Rules:
1) Read the cache JSON first. It already contains weather and yesterday news.
2) Read memory only to find `Tomorrow Plan Capture (for next day)`.
3) Never mention file paths, source sites, fetch status, diagnostics, or any internal process.
4) If the plan is missing, write:
   - 主任务: 昨晚未提交，先补今天三件事
   - 上午: 待补充
   - 下午: 待补充
   - 晚上: 待补充
5) Any missing cache value must be rendered exactly as: 暂无可核验更新
6) Rewrite all news items into neutral news style. Remove hashtags, exclamation marks, sensational wording, self-media tone, and rhetorical phrases.
7) For VALORANT, KPL, and football, keep the cache's factual structure: time first, then event or stage, then teams and score.
8) For international news, rewrite each item into compact hard-news style: time, what happened, and why it matters.
9) Do not output the literal text `暂无可核验更新` for plan fields. Use the missing-plan fallback in rule 4.
10) For esports with no verified update, write `昨晚无已核验官方赛事结果`.
11) For football leagues with no finished match, write `昨晚无已完赛赛事`.
12) For international news with no verified update, write `昨晚无已核验国际要闻更新`.
13) Keep the reply short, structured, and easy to scan.
14) Do not add hype, metaphor, or dramatic wording.
15) If football cache entries include scorers, keep the scorer names and minutes. Do not drop them.
16) Keep `无畏契约` in the competition name. Do not shorten it to only `大师赛` or `冠军赛`.
17) Keep one category per line. Do not merge KPL, football, and international news into one paragraph.
18) If one sports category contains multiple matches, split them into 1 to 3 short bullet lines starting with `- `. Do not use numbered lists.
19) Under international news, use 1 to 3 short bullet lines starting with `- ` instead of one long sentence block.
20) Keep blank lines between sections.

Output format:
【今日重点】
主任务：
天气：
带伞：

【今日执行】
上午：
下午：
晚上：

【昨夜赛果】
无畏契约：
- 
- 
KPL：
- 
- 
- 
西甲：
- 
- 
英超：
- 
欧冠：
- 

【国际要闻】
- 
- 
- 
"@.Trim()
$morningMessage = Compact-Message -Text $morningMessage

Write-Host "Target: channel=$Channel to=$To agent=$Agent tz=$Timezone location=$Location"
if (-not [string]::IsNullOrWhiteSpace($SessionKey)) {
    Write-Host "Pinned session key: $SessionKey"
}
Write-Host "Evening cron: $EveningCron ($EveningJobName)"
Write-Host "Capture cron: $CaptureCron ($CaptureJobName)"
Write-Host "Morning cron: $MorningCron ($MorningJobName)"
Write-Host "Legacy prefetch job to remove when replacing: $LegacyPrefetchJobName"

$jobs = @(Get-CronJobs)
if ($jobs.Count -gt 0) {
    $hasEvening = @($jobs | Where-Object { $_.name -eq $EveningJobName }).Count -gt 0
    $hasCapture = @($jobs | Where-Object { $_.name -eq $CaptureJobName }).Count -gt 0
    $hasLegacyPrefetch = @($jobs | Where-Object { $_.name -eq $LegacyPrefetchJobName }).Count -gt 0
    $hasMorning = @($jobs | Where-Object { $_.name -eq $MorningJobName }).Count -gt 0

    if (($hasEvening -or $hasCapture -or $hasLegacyPrefetch -or $hasMorning) -and (-not $Force.IsPresent)) {
        throw "Cron jobs already exist. Use -Force to replace."
    }

    if ($Force.IsPresent) {
        Remove-JobByName -Name $EveningJobName -Jobs $jobs
        Remove-JobByName -Name $CaptureJobName -Jobs $jobs
        Remove-JobByName -Name $LegacyPrefetchJobName -Jobs $jobs
        Remove-JobByName -Name $MorningJobName -Jobs $jobs
    }
}

function New-AgentTurnArgs {
    param(
        [string]$Name,
        [string]$CronExpr,
        [string]$Message,
        [bool]$Deliver,
        [string]$Thinking = "minimal",
        [int]$TimeoutSeconds = 90,
        [bool]$LightContext = $true
    )

    $args = @(
        "cron", "add",
        "--name", $Name,
        "--cron", $CronExpr,
        "--tz", $Timezone,
        "--agent", $Agent,
        "--thinking", $Thinking,
        "--timeout-seconds", [string]$TimeoutSeconds
    )

    if ($LightContext) {
        $args += @("--light-context")
    }

    if ([string]::IsNullOrWhiteSpace($SessionKey)) {
        $args += @("--message", $Message)
        if ($Deliver) {
            $args += @("--announce", "--channel", $Channel, "--to", $To)
        }
        else {
            $args += @("--no-deliver", "--channel", $Channel, "--to", $To)
        }
    }
    else {
        $args += @("--session-key", $SessionKey, "--message", $Message)
        if ($Deliver) {
            $args += @("--announce")
        }
        else {
            $args += @("--no-deliver")
        }
    }

    return ,$args
}

Write-Host "Adding evening reminder job..."
$eveningArgs = New-AgentTurnArgs -Name $EveningJobName -CronExpr $EveningCron -Message $eveningMessage -Deliver $true -Thinking "minimal" -TimeoutSeconds 60 -LightContext $true
Invoke-OpenClaw -CliArgs $eveningArgs | Out-Null

Write-Host "Adding night capture job (silent)..."
$captureArgs = New-AgentTurnArgs -Name $CaptureJobName -CronExpr $CaptureCron -Message $captureMessage -Deliver $false -Thinking "minimal" -TimeoutSeconds 90 -LightContext $true
Invoke-OpenClaw -CliArgs $captureArgs | Out-Null

Write-Host "Adding morning summary job..."
$morningArgs = New-AgentTurnArgs -Name $MorningJobName -CronExpr $MorningCron -Message $morningMessage -Deliver $true -Thinking "minimal" -TimeoutSeconds 45 -LightContext $true
Invoke-OpenClaw -CliArgs $morningArgs | Out-Null

Write-Host ""
if ($DryRun) {
    Write-Host "Dry-run complete. No cron jobs were changed."
}
else {
    Write-Host "Done. Current cron jobs:"
    & openclaw.cmd cron list
    $jobsAfter = @(Get-CronJobs)
    $evening = $jobsAfter | Where-Object { $_.name -eq $EveningJobName } | Select-Object -First 1
    $capture = $jobsAfter | Where-Object { $_.name -eq $CaptureJobName } | Select-Object -First 1
    $morning = $jobsAfter | Where-Object { $_.name -eq $MorningJobName } | Select-Object -First 1

    Write-Host ""
    Write-Host "Next:"
    Write-Host "  Install-MorningDigestScheduledTask.ps1  (07:05 local cache prefetch)"
    Write-Host ""
    Write-Host "Optional test now:"
    if ($null -ne $evening -and -not [string]::IsNullOrWhiteSpace([string]$evening.id)) {
        Write-Host "  openclaw.cmd cron run $($evening.id)"
    }
    if ($null -ne $capture -and -not [string]::IsNullOrWhiteSpace([string]$capture.id)) {
        Write-Host "  openclaw.cmd cron run $($capture.id)"
    }
    if ($null -ne $morning -and -not [string]::IsNullOrWhiteSpace([string]$morning.id)) {
        Write-Host "  openclaw.cmd cron run $($morning.id)"
    }
}
