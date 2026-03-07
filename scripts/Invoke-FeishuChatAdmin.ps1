param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("GetChatInfo", "ListMembers", "CreateChat", "AddMembers", "BatchGetIds")]
    [string]$Action,

    [string]$Domain = "feishu",
    [string]$AppId = $env:FEISHU_APP_ID,
    [string]$AppSecret = $env:FEISHU_APP_SECRET,

    [string]$ChatId,
    [string]$ChatName,
    [string]$Description = "",
    [string]$OwnerId,
    [string[]]$UserIds = @(),
    [string[]]$MemberIds = @(),
    [string[]]$Mobiles = @(),
    [string[]]$Emails = @(),

    [ValidateSet("open_id", "user_id", "union_id")]
    [string]$MemberIdType = "open_id",

    [ValidateSet("group", "private", "public")]
    [string]$ChatMode = "group",

    [ValidateSet("private", "public")]
    [string]$ChatType = "private",

    [string]$ApprovalText = "",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$requiredApproval = "APPROVE_FEISHU_CHAT_ADMIN"
$mutatingActions = @("CreateChat", "AddMembers")

function Resolve-BaseUrl {
    param([string]$Domain)
    switch ($Domain.ToLowerInvariant()) {
        "lark" { return "https://open.larksuite.com" }
        default { return "https://open.feishu.cn" }
    }
}

function Assert-Approval {
    param(
        [string]$Action,
        [string]$ApprovalText,
        [bool]$DryRun
    )
    if ($DryRun) { return }
    if ($mutatingActions -notcontains $Action) { return }
    if ($ApprovalText -ne $requiredApproval) {
        throw "Mutating action '$Action' requires -ApprovalText $requiredApproval"
    }
}

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
        $parts = $v -split ","
        foreach ($p in $parts) {
            $trimmed = $p.Trim()
            if ($trimmed.Length -gt 0) {
                $result += $trimmed
            }
        }
    }
    return ,$result
}

function Build-IdResolutionSummary {
    param(
        [object]$ApiResponse,
        [string]$RequestedIdType
    )

    $resolved = @()
    $orderedFields = @()
    if ([string]::IsNullOrWhiteSpace($RequestedIdType) -eq $false) {
        $orderedFields += $RequestedIdType
    }
    foreach ($f in @("open_id", "user_id", "union_id")) {
        if ($orderedFields -notcontains $f) {
            $orderedFields += $f
        }
    }

    if ($null -ne $ApiResponse -and $ApiResponse.PSObject.Properties.Name -contains "data") {
        $data = $ApiResponse.data
        if ($null -ne $data -and $data.PSObject.Properties.Name -contains "user_list") {
            foreach ($u in @($data.user_list)) {
                if ($null -eq $u) { continue }
                foreach ($field in $orderedFields) {
                    if ($u.PSObject.Properties.Name -contains $field) {
                        $value = [string]$u.$field
                        if ([string]::IsNullOrWhiteSpace($value) -eq $false) {
                            $resolved += $value
                            break
                        }
                    }
                }
            }
        }
    }

    $unique = @($resolved | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    return [ordered]@{
        action = "BatchGetIds"
        code = $ApiResponse.code
        msg = $ApiResponse.msg
        requested_id_type = $RequestedIdType
        resolved_count = $unique.Count
        resolved_ids = $unique
        raw = $ApiResponse
    }
}

function Get-TenantAccessToken {
    param(
        [string]$BaseUrl,
        [string]$AppId,
        [string]$AppSecret
    )
    Assert-Required ($AppId -and $AppSecret) "AppId/AppSecret required. Set parameters or FEISHU_APP_ID + FEISHU_APP_SECRET."
    $uri = "$BaseUrl/open-apis/auth/v3/tenant_access_token/internal/"
    $body = @{
        app_id = $AppId
        app_secret = $AppSecret
    } | ConvertTo-Json
    $resp = Invoke-RestMethod -Method Post -Uri $uri -ContentType "application/json; charset=utf-8" -Body $body
    if ($resp.code -ne 0) {
        throw "tenant_access_token failed: code=$($resp.code) msg=$($resp.msg)"
    }
    return [string]$resp.tenant_access_token
}

function Invoke-FeishuApi {
    param(
        [string]$Method,
        [string]$Uri,
        [string]$Token,
        [object]$Body = $null
    )
    $headers = @{
        Authorization = "Bearer $Token"
    }
    if ($null -eq $Body) {
        return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers
    }
    $jsonBody = $Body | ConvertTo-Json -Depth 20
    return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers -ContentType "application/json; charset=utf-8" -Body $jsonBody
}

$baseUrl = Resolve-BaseUrl -Domain $Domain
Assert-Approval -Action $Action -ApprovalText $ApprovalText -DryRun ([bool]$DryRun)

$UserIds = Expand-IdList -Values $UserIds
$MemberIds = Expand-IdList -Values $MemberIds
$Mobiles = Expand-IdList -Values $Mobiles
$Emails = Expand-IdList -Values $Emails

if ($Action -in @("GetChatInfo", "ListMembers", "AddMembers")) {
    Assert-Required ([string]::IsNullOrWhiteSpace($ChatId) -eq $false) "-ChatId is required for $Action."
}

if ($Action -eq "CreateChat") {
    Assert-Required ([string]::IsNullOrWhiteSpace($ChatName) -eq $false) "-ChatName is required for CreateChat."
    Assert-Required ($UserIds.Count -gt 0) "-UserIds must include at least one member for CreateChat."

    # Backward compatibility: older flow used ChatMode=private/public.
    if ($ChatMode -in @("private", "public")) {
        if ($PSBoundParameters.ContainsKey("ChatType") -eq $false) {
            $ChatType = $ChatMode
        }
        $ChatMode = "group"
    }
}

if ($Action -eq "AddMembers") {
    Assert-Required ($MemberIds.Count -gt 0) "-MemberIds must include at least one member for AddMembers."
}

if ($Action -eq "BatchGetIds") {
    Assert-Required (($Mobiles.Count -gt 0) -or ($Emails.Count -gt 0)) "-Mobiles or -Emails is required for BatchGetIds."
}

switch ($Action) {
    "GetChatInfo" {
        $uri = "$baseUrl/open-apis/im/v1/chats/$ChatId"
        if ($DryRun) {
            [pscustomobject]@{
                action = $Action
                method = "GET"
                uri = $uri
            } | ConvertTo-Json -Depth 10
            exit 0
        }
        $token = Get-TenantAccessToken -BaseUrl $baseUrl -AppId $AppId -AppSecret $AppSecret
        $resp = Invoke-FeishuApi -Method Get -Uri $uri -Token $token
        $resp | ConvertTo-Json -Depth 30
        exit 0
    }
    "ListMembers" {
        $uri = "$baseUrl/open-apis/im/v1/chats/$ChatId/members?page_size=50&member_id_type=$MemberIdType"
        if ($DryRun) {
            [pscustomobject]@{
                action = $Action
                method = "GET"
                uri = $uri
            } | ConvertTo-Json -Depth 10
            exit 0
        }
        $token = Get-TenantAccessToken -BaseUrl $baseUrl -AppId $AppId -AppSecret $AppSecret
        $resp = Invoke-FeishuApi -Method Get -Uri $uri -Token $token
        $resp | ConvertTo-Json -Depth 30
        exit 0
    }
    "CreateChat" {
        $uri = "$baseUrl/open-apis/im/v1/chats?user_id_type=$MemberIdType"
        $body = @{
            name = $ChatName
            description = $Description
            owner_id = $OwnerId
            user_id_list = $UserIds
            chat_mode = $ChatMode
            chat_type = $ChatType
        }
        if ($DryRun) {
            [pscustomobject]@{
                action = $Action
                method = "POST"
                uri = $uri
                body = $body
            } | ConvertTo-Json -Depth 10
            exit 0
        }
        $token = Get-TenantAccessToken -BaseUrl $baseUrl -AppId $AppId -AppSecret $AppSecret
        $resp = Invoke-FeishuApi -Method Post -Uri $uri -Token $token -Body $body
        $resp | ConvertTo-Json -Depth 30
        exit 0
    }
    "AddMembers" {
        $uri = "$baseUrl/open-apis/im/v1/chats/$ChatId/members?member_id_type=$MemberIdType"
        $body = @{
            id_list = $MemberIds
        }
        if ($DryRun) {
            [pscustomobject]@{
                action = $Action
                method = "POST"
                uri = $uri
                body = $body
            } | ConvertTo-Json -Depth 10
            exit 0
        }
        $token = Get-TenantAccessToken -BaseUrl $baseUrl -AppId $AppId -AppSecret $AppSecret
        $resp = Invoke-FeishuApi -Method Post -Uri $uri -Token $token -Body $body
        $resp | ConvertTo-Json -Depth 30
        exit 0
    }
    "BatchGetIds" {
        $uri = "$baseUrl/open-apis/contact/v3/users/batch_get_id?user_id_type=$MemberIdType"
        $body = @{}
        if ($Mobiles.Count -gt 0) { $body["mobiles"] = $Mobiles }
        if ($Emails.Count -gt 0) { $body["emails"] = $Emails }

        if ($DryRun) {
            [pscustomobject]@{
                action = $Action
                method = "POST"
                uri = $uri
                body = $body
            } | ConvertTo-Json -Depth 10
            exit 0
        }

        $token = Get-TenantAccessToken -BaseUrl $baseUrl -AppId $AppId -AppSecret $AppSecret
        $resp = Invoke-FeishuApi -Method Post -Uri $uri -Token $token -Body $body
        $summary = Build-IdResolutionSummary -ApiResponse $resp -RequestedIdType $MemberIdType
        $summary | ConvertTo-Json -Depth 50
        exit 0
    }
}
