param(
    [ValidateSet("CreateAndAdd", "CreateOnly", "AddOnly")]
    [string]$Flow = "CreateAndAdd",

    [string]$Domain = "feishu",
    [string]$AppId = $env:FEISHU_APP_ID,
    [string]$AppSecret = $env:FEISHU_APP_SECRET,

    [string]$ChatName,
    [string]$Description = "",
    [string]$OwnerId,
    [string[]]$CreateUserIds = @(),

    [string]$ChatId,
    [string[]]$AddMemberIds = @(),

    [ValidateSet("open_id", "user_id", "union_id")]
    [string]$MemberIdType = "open_id",

    [ValidateSet("private", "public")]
    [string]$ChatMode = "private",

    [switch]$Execute,
    [string]$ApprovalText = "",

    [string]$WriteBackDir = "",
    [switch]$WriteBackDailyMemory,
    [string]$DailyMemoryPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$requiredApproval = "APPROVE_FEISHU_CHAT_ADMIN"
$bridgeScript = Join-Path $PSScriptRoot "Invoke-FeishuChatAdmin.ps1"

function Assert-Required {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Expand-IdList {
    param([string[]]$Values)
    $result = @()
    foreach ($v in $Values) {
        if ([string]::IsNullOrWhiteSpace($v)) { continue }
        foreach ($p in ($v -split ",")) {
            $trimmed = $p.Trim()
            if ($trimmed.Length -gt 0) {
                $result += $trimmed
            }
        }
    }
    return ,$result
}

function Resolve-DefaultWriteBackDir {
    $workspace = Join-Path $env:USERPROFILE ".openclaw\workspace\memory"
    if (Test-Path $workspace) {
        return (Join-Path $workspace "feishu-group-flow")
    }
    return (Join-Path $PSScriptRoot "..\logs\feishu-group-flow")
}

function Resolve-DailyMemoryPath {
    param([string]$ProvidedPath)
    if ([string]::IsNullOrWhiteSpace($ProvidedPath) -eq $false) {
        return $ProvidedPath
    }
    $day = Get-Date -Format "yyyy-MM-dd"
    return (Join-Path $env:USERPROFILE ".openclaw\workspace\memory\$day.md")
}

function Convert-OutputToText {
    param([object]$OutputObject)
    if ($null -eq $OutputObject) { return "" }
    if ($OutputObject -is [System.Array]) {
        return (($OutputObject | ForEach-Object { $_.ToString() }) -join "`n")
    }
    return $OutputObject.ToString()
}

function Invoke-BridgeAction {
    param([hashtable]$ActionParams)

    try {
        $raw = & $bridgeScript @ActionParams 2>&1
        $text = Convert-OutputToText -OutputObject $raw
        $json = $null
        try {
            $json = $text | ConvertFrom-Json -Depth 100
        }
        catch {
            $json = $null
        }
        return [pscustomobject]@{
            ok = $true
            text = $text
            json = $json
            args = $ActionParams
        }
    }
    catch {
        return [pscustomobject]@{
            ok = $false
            text = $_.Exception.Message
            json = $null
            args = $ActionParams
        }
    }
}

function Resolve-ChatIdFromResponse {
    param([object]$JsonResponse)
    if ($null -eq $JsonResponse) { return $null }
    if ($JsonResponse.PSObject.Properties.Name -contains "chat_id") {
        if ([string]::IsNullOrWhiteSpace([string]$JsonResponse.chat_id) -eq $false) {
            return [string]$JsonResponse.chat_id
        }
    }
    if ($JsonResponse.PSObject.Properties.Name -contains "data") {
        $data = $JsonResponse.data
        if ($null -ne $data) {
            if ($data.PSObject.Properties.Name -contains "chat_id") {
                if ([string]::IsNullOrWhiteSpace([string]$data.chat_id) -eq $false) {
                    return [string]$data.chat_id
                }
            }
            if ($data.PSObject.Properties.Name -contains "chat") {
                $chat = $data.chat
                if ($null -ne $chat -and $chat.PSObject.Properties.Name -contains "chat_id") {
                    if ([string]::IsNullOrWhiteSpace([string]$chat.chat_id) -eq $false) {
                        return [string]$chat.chat_id
                    }
                }
            }
        }
    }
    return $null
}

function New-StepRecord {
    param(
        [string]$Phase,
        [string]$Action,
        [bool]$Ok,
        [string]$Message,
        [object]$Data
    )
    return [ordered]@{
        phase = $Phase
        action = $Action
        ok = $Ok
        message = $Message
        data = $Data
        at = (Get-Date).ToString("s")
    }
}

Assert-Required (Test-Path $bridgeScript) "Bridge script not found: $bridgeScript"

$CreateUserIds = Expand-IdList -Values $CreateUserIds
$AddMemberIds = Expand-IdList -Values $AddMemberIds

$needCreate = $Flow -in @("CreateAndAdd", "CreateOnly")
$needAdd = $Flow -in @("CreateAndAdd", "AddOnly")

if ($needCreate) {
    Assert-Required ([string]::IsNullOrWhiteSpace($ChatName) -eq $false) "-ChatName is required for $Flow."
    Assert-Required ([string]::IsNullOrWhiteSpace($OwnerId) -eq $false) "-OwnerId is required for $Flow."
    Assert-Required ($CreateUserIds.Count -gt 0) "-CreateUserIds must include at least one user for $Flow."
}
if ($needAdd) {
    Assert-Required ($AddMemberIds.Count -gt 0) "-AddMemberIds must include at least one user for $Flow."
}
if ($Flow -eq "AddOnly") {
    Assert-Required ([string]::IsNullOrWhiteSpace($ChatId) -eq $false) "-ChatId is required for AddOnly."
}
if ($Execute -and $ApprovalText -ne $requiredApproval) {
    throw "Execute requires -ApprovalText $requiredApproval"
}

if ([string]::IsNullOrWhiteSpace($WriteBackDir)) {
    $WriteBackDir = Resolve-DefaultWriteBackDir
}
if (-not (Test-Path $WriteBackDir)) {
    New-Item -ItemType Directory -Path $WriteBackDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$reportBase = "feishu-group-flow-$timestamp"
$jsonPath = Join-Path $WriteBackDir "$reportBase.json"
$mdPath = Join-Path $WriteBackDir "$reportBase.md"

$report = [ordered]@{
    flow = $Flow
    execute = [bool]$Execute
    startedAt = (Get-Date).ToString("s")
    domain = $Domain
    memberIdType = $MemberIdType
    chatMode = $ChatMode
    inputs = [ordered]@{
        chatName = $ChatName
        ownerId = $OwnerId
        chatId = $ChatId
        createUserIds = $CreateUserIds
        addMemberIds = $AddMemberIds
    }
    dryRun = @()
    execution = @()
    final = [ordered]@{
        ok = $false
        chatId = $ChatId
    }
}

# Phase 1: always dry-run
if ($needCreate) {
    $createDryArgs = @{
        Action = "CreateChat"
        Domain = $Domain
        AppId = $AppId
        AppSecret = $AppSecret
        ChatName = $ChatName
        Description = $Description
        OwnerId = $OwnerId
        UserIds = $CreateUserIds
        MemberIdType = $MemberIdType
        ChatMode = $ChatMode
        DryRun = $true
    }
    $dryCreate = Invoke-BridgeAction -ActionParams $createDryArgs
    $report.dryRun += (New-StepRecord -Phase "dry-run" -Action "CreateChat" -Ok $dryCreate.ok -Message $dryCreate.text -Data $dryCreate.json)
}

if ($needAdd) {
    $dryChatId = if ([string]::IsNullOrWhiteSpace($ChatId)) { "<CHAT_ID_FROM_CREATE>" } else { $ChatId }
    $addDryArgs = @{
        Action = "AddMembers"
        Domain = $Domain
        AppId = $AppId
        AppSecret = $AppSecret
        ChatId = $dryChatId
        MemberIds = $AddMemberIds
        MemberIdType = $MemberIdType
        DryRun = $true
    }
    $dryAdd = Invoke-BridgeAction -ActionParams $addDryArgs
    $report.dryRun += (New-StepRecord -Phase "dry-run" -Action "AddMembers" -Ok $dryAdd.ok -Message $dryAdd.text -Data $dryAdd.json)
}

$allDryOk = @($report.dryRun | Where-Object { -not $_.ok }).Count -eq 0
if (-not $allDryOk) {
    $report.final.ok = $false
    $report.final.reason = "DryRun failed; execution skipped."
}
elseif (-not $Execute) {
    $report.final.ok = $false
    $report.final.reason = "DryRun completed. Waiting for explicit execution approval."
}
else {
    # Phase 2: execute
    $runtimeChatId = $ChatId

    if ($needCreate) {
        $createExecArgs = @{
            Action = "CreateChat"
            Domain = $Domain
            AppId = $AppId
            AppSecret = $AppSecret
            ChatName = $ChatName
            Description = $Description
            OwnerId = $OwnerId
            UserIds = $CreateUserIds
            MemberIdType = $MemberIdType
            ChatMode = $ChatMode
            ApprovalText = $ApprovalText
        }
        $execCreate = Invoke-BridgeAction -ActionParams $createExecArgs
        $report.execution += (New-StepRecord -Phase "execute" -Action "CreateChat" -Ok $execCreate.ok -Message $execCreate.text -Data $execCreate.json)
        if (-not $execCreate.ok) {
            $report.final.ok = $false
            $report.final.reason = "CreateChat failed."
        }
        else {
            $resolvedChatId = Resolve-ChatIdFromResponse -JsonResponse $execCreate.json
            if ([string]::IsNullOrWhiteSpace($resolvedChatId) -eq $false) {
                $runtimeChatId = $resolvedChatId
                $report.final.chatId = $resolvedChatId
            }
        }
    }

    if ($needAdd) {
        if ([string]::IsNullOrWhiteSpace($runtimeChatId)) {
            $report.execution += (New-StepRecord -Phase "execute" -Action "AddMembers" -Ok $false -Message "AddMembers skipped: chat_id unavailable." -Data $null)
            $report.final.ok = $false
            $report.final.reason = "AddMembers skipped due to missing chat_id."
        }
        else {
            $addExecArgs = @{
                Action = "AddMembers"
                Domain = $Domain
                AppId = $AppId
                AppSecret = $AppSecret
                ChatId = $runtimeChatId
                MemberIds = $AddMemberIds
                MemberIdType = $MemberIdType
                ApprovalText = $ApprovalText
            }
            $execAdd = Invoke-BridgeAction -ActionParams $addExecArgs
            $report.execution += (New-StepRecord -Phase "execute" -Action "AddMembers" -Ok $execAdd.ok -Message $execAdd.text -Data $execAdd.json)
            if (-not $execAdd.ok) {
                $report.final.ok = $false
                $report.final.reason = "AddMembers failed."
            }
        }
    }

    if ((@($report.execution | Where-Object { -not $_.ok }).Count -eq 0) -and ($needCreate -or $needAdd)) {
        $report.final.ok = $true
        $report.final.reason = "Execution completed successfully."
    }
}

$report.finishedAt = (Get-Date).ToString("s")
$report.durationSeconds = [math]::Round(((Get-Date) - [datetime]$report.startedAt).TotalSeconds, 2)

$report | ConvertTo-Json -Depth 50 | Set-Content -Path $jsonPath -Encoding UTF8

$md = @()
$md += "# Feishu Group Flow Report"
$md += ""
$md += "- Flow: $Flow"
$md += "- Execute: $([bool]$Execute)"
$md += "- Final OK: $($report.final.ok)"
$md += "- Reason: $($report.final.reason)"
$md += "- Chat ID: $($report.final.chatId)"
$md += "- Started: $($report.startedAt)"
$md += "- Finished: $($report.finishedAt)"
$md += ""
$md += "## Dry Run Steps"
if ($report.dryRun.Count -eq 0) {
    $md += "- none"
}
else {
    foreach ($s in $report.dryRun) {
        $md += "- [$($s.action)] ok=$($s.ok)"
    }
}
$md += ""
$md += "## Execute Steps"
if ($report.execution.Count -eq 0) {
    $md += "- none"
}
else {
    foreach ($s in $report.execution) {
        $md += "- [$($s.action)] ok=$($s.ok)"
    }
}
$md += ""
$md += "JSON report: $jsonPath"
$md | Set-Content -Path $mdPath -Encoding UTF8

if ($WriteBackDailyMemory) {
    $targetDaily = Resolve-DailyMemoryPath -ProvidedPath $DailyMemoryPath
    if (Test-Path $targetDaily) {
        $append = @()
        $append += ""
        $append += "## Feishu Group Flow ($timestamp)"
        $append += "- flow: $Flow"
        $append += "- execute: $([bool]$Execute)"
        $append += "- final_ok: $($report.final.ok)"
        $append += "- reason: $($report.final.reason)"
        $append += "- chat_id: $($report.final.chatId)"
        $append += "- report_json: $jsonPath"
        $append += "- report_md: $mdPath"
        Add-Content -Path $targetDaily -Value ($append -join "`n")
    }
}

Write-Host "DryRun completed: $allDryOk"
Write-Host "Executed: $([bool]$Execute)"
Write-Host "Final OK: $($report.final.ok)"
Write-Host "Chat ID: $($report.final.chatId)"
Write-Host "Report JSON: $jsonPath"
Write-Host "Report MD:   $mdPath"

if (-not $Execute) {
    Write-Host ""
    Write-Host "To execute this flow, rerun with:" -ForegroundColor Yellow
    Write-Host "  -Execute -ApprovalText $requiredApproval" -ForegroundColor Yellow
}
