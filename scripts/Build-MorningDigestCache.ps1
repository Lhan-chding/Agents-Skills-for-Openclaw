param(
    [string]$Workspace = "$env:USERPROFILE\.openclaw\workspace",
    [string]$Location = "中国·成都市双流区",
    [string]$WeatherDistrictCode = "101270106",
    [string]$WeatherCityCode = "101270101",
    [datetime]$AsOf = (Get-Date),
    [int]$TimeoutSec = 10,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Ensure-Dir {
    param([string]$Path)
    if ($DryRun) {
        if (-not (Test-Path $Path)) {
            Write-Host "[DryRun] Would create directory: $Path"
        }
        return
    }
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Normalize-Whitespace {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    $normalized = ($Text -replace '&nbsp;', ' ' -replace '\s+', ' ').Trim()
    $normalized = $normalized -replace '(?<=[\u4e00-\u9fff])\s+(?=[\u4e00-\u9fff])', ''
    return $normalized
}

function Strip-Html {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    $decoded = [System.Net.WebUtility]::HtmlDecode($Text)
    $plain = $decoded -replace '<[^>]+>', ' '
    return (Normalize-Whitespace -Text $plain)
}

function Normalize-NewsText {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    $clean = Strip-Html -Text $Text
    $clean = $clean -replace '#[^#]{1,80}#', ''
    $clean = $clean -replace '[!！]{1,}', ''
    $clean = $clean -replace '燃爆|火热进行|冠军在望|问鼎|炸裂|封神|神剧情', ''
    $clean = $clean -replace '\s+', ' '
    $clean = $clean.Trim(' ', '，', '；', '：', '。')
    return $clean
}

function Get-ChinaTimeText {
    param([datetime]$DateTimeValue)
    try {
        $tz = [TimeZoneInfo]::FindSystemTimeZoneById('China Standard Time')
        $local = [TimeZoneInfo]::ConvertTime($DateTimeValue, $tz)
        return $local.ToString('MM-dd HH:mm')
    }
    catch {
        return $DateTimeValue.ToString('MM-dd HH:mm')
    }
}

function Get-CjkCount {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return 0 }
    return ([regex]::Matches($Text, '[\u4e00-\u9fff]')).Count
}

function Repair-MojibakeUtf8 {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    try {
        $bytes = [System.Text.Encoding]::GetEncoding(28591).GetBytes($Text)
        $fixed = [System.Text.Encoding]::UTF8.GetString($bytes)
        if ((Get-CjkCount -Text $fixed) -gt (Get-CjkCount -Text $Text)) {
            return $fixed
        }
    }
    catch {
    }
    return $Text
}

function Invoke-TextRequest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,
        [int]$Timeout = 10,
        [hashtable]$Headers
    )

    $defaultHeaders = @{
        'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) OpenClawCapabilityPack/2.0'
        'Accept-Language' = 'zh-CN,zh;q=0.9,en;q=0.7'
    }
    if ($Headers) {
        foreach ($key in $Headers.Keys) {
            $defaultHeaders[$key] = $Headers[$key]
        }
    }

    try {
        $resp = Invoke-WebRequest -Uri $Url -Headers $defaultHeaders -UseBasicParsing -TimeoutSec $Timeout
        return (Repair-MojibakeUtf8 -Text ([string]$resp.Content))
    }
    catch {
        return $null
    }
}

function Invoke-JsonRequest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,
        [int]$Timeout = 10,
        [hashtable]$Headers
    )

    $defaultHeaders = @{
        'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) OpenClawCapabilityPack/2.0'
        'Accept-Language' = 'zh-CN,zh;q=0.9,en;q=0.7'
    }
    if ($Headers) {
        foreach ($key in $Headers.Keys) {
            $defaultHeaders[$key] = $Headers[$key]
        }
    }

    try {
        return Invoke-RestMethod -Uri $Url -Headers $defaultHeaders -TimeoutSec $Timeout
    }
    catch {
        return $null
    }
}

function New-DefaultDigest {
    param(
        [string]$Region,
        [datetime]$RunTime
    )

    $none = '暂无可核验更新'
    return [ordered]@{
        generatedAt = $RunTime.ToString('s')
        targetNewsDate = $RunTime.Date.AddDays(-1).ToString('yyyy-MM-dd')
        region = $Region
        weather = [ordered]@{
            summary = $none
            umbrella = $none
        }
        plan = [ordered]@{
            main_task = $none
            morning = $none
            afternoon = $none
            evening = $none
        }
        news = [ordered]@{
            valorant = $none
            kpl = $none
            football = [ordered]@{
                laliga = $none
                epl = $none
                ucl = $none
            }
            international = $none
        }
    }
}

function Get-PlanCaptureBody {
    param([string]$MemoryDir)

    $candidates = @(
        (Join-Path $MemoryDir ($AsOf.ToString('yyyy-MM-dd') + '.md')),
        (Join-Path $MemoryDir ($AsOf.AddDays(-1).ToString('yyyy-MM-dd') + '.md'))
    )

    foreach ($path in $candidates) {
        if (-not (Test-Path $path)) { continue }
        $raw = Get-Content -Raw -Encoding UTF8 $path
        $m = [regex]::Match($raw, '## Tomorrow Plan Capture \(for next day\)(?<body>.*?)(?=\r?\n## |\z)', 'Singleline')
        if ($m.Success) {
            return $m.Groups['body'].Value.Trim()
        }
    }

    return ''
}

function Parse-PlanFields {
    param([string]$Body)

    $none = '暂无可核验更新'
    $result = [ordered]@{
        main_task = $none
        morning = $none
        afternoon = $none
        evening = $none
    }

    if ([string]::IsNullOrWhiteSpace($Body)) {
        return $result
    }

    $lines = @($Body -split "(`r`n|`n|`r)" | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    foreach ($line in $lines) {
        if ($result.main_task -eq $none -and $line -match '(?i)(main_task|主任务|最高优先级|MIT)') {
            $result.main_task = (($line -replace '^[\-*\d\.\)\s]+', '') -replace '^[^:：]+[:：]\s*', '')
            continue
        }
        if ($result.morning -eq $none -and $line -match '(?i)(morning|上午)') {
            $result.morning = (($line -replace '^[\-*\d\.\)\s]+', '') -replace '^[^:：]+[:：]\s*', '')
            continue
        }
        if ($result.afternoon -eq $none -and $line -match '(?i)(afternoon|下午)') {
            $result.afternoon = (($line -replace '^[\-*\d\.\)\s]+', '') -replace '^[^:：]+[:：]\s*', '')
            continue
        }
        if ($result.evening -eq $none -and $line -match '(?i)(evening|晚上)') {
            $result.evening = (($line -replace '^[\-*\d\.\)\s]+', '') -replace '^[^:：]+[:：]\s*', '')
            continue
        }
    }

    $bullets = @($lines | ForEach-Object { ($_ -replace '^[\-*\d\.\)\s]+', '').Trim() } | Where-Object { $_ })
    if ($result.main_task -eq $none -and $bullets.Count -ge 1) { $result.main_task = $bullets[0] }
    if ($result.morning -eq $none -and $bullets.Count -ge 2) { $result.morning = $bullets[1] }
    if ($result.afternoon -eq $none -and $bullets.Count -ge 3) { $result.afternoon = $bullets[2] }
    if ($result.evening -eq $none -and $bullets.Count -ge 4) { $result.evening = $bullets[3] }

    return $result
}

function Get-WeatherDigest {
    param(
        [string]$Region,
        [string[]]$Codes
    )

    foreach ($code in $Codes) {
        $url = "https://www.weather.com.cn/weather1d/$code.shtml"
        $html = Invoke-TextRequest -Url $url -Timeout $TimeoutSec
        if ([string]::IsNullOrWhiteSpace($html)) { continue }

        $titleMatch = [regex]::Match($html, '<input type="hidden" id="hidden_title" value="(?<value>[^"]+)"', 'IgnoreCase')
        $hourMatch = [regex]::Match($html, 'var hour3data=(?<value>\{.*?\});', 'IgnoreCase,Singleline')
        if (-not $titleMatch.Success -and -not $hourMatch.Success) { continue }

        $title = $titleMatch.Groups['value'].Value
        $hourBlock = $hourMatch.Groups['value'].Value

        $condition = ''
        $high = ''
        $low = ''
        if ($title -match '\s(?<condition>[^\s]+)\s+(?<high>\d+)\/(?<low>\d+)°C') {
            $condition = $Matches['condition']
            $high = $Matches['high']
            $low = $Matches['low']
        }

        if ([string]::IsNullOrWhiteSpace($condition) -and $hourBlock -match '"1d":\["[^"]+,[^"]+,(?<condition>[^,]+),(?<temp>\d+)℃') {
            $condition = $Matches['condition']
        }

        $todayBlock = $hourBlock
        $todayBlockMatch = [regex]::Match($hourBlock, '"1d":\[(?<block>.*?)\](?:,"23d"|,"7d"|,"40d")', 'IgnoreCase,Singleline')
        if ($todayBlockMatch.Success) {
            $todayBlock = $todayBlockMatch.Groups['block'].Value
        }

        $rainWords = @('小雨', '中雨', '大雨', '暴雨', '阵雨', '雷阵雨', '雨夹雪', '雪')
        $rainSignal = $false
        foreach ($word in $rainWords) {
            if ($todayBlock -match [regex]::Escape($word) -or $title -match [regex]::Escape($word)) {
                $rainSignal = $true
                break
            }
        }

        $conditionText = if ([string]::IsNullOrWhiteSpace($condition)) { '天气平稳' } else { $condition }
        $tempText = if ($high -and $low) { "，气温约$low-$high°C" } else { '' }
        $summary = "${Region}今天${conditionText}${tempText}。"
        $umbrella = if ($rainSignal) {
            '有降雨信号，建议带折叠伞。'
        }
        elseif ($conditionText -match '阴') {
            '天气偏阴，建议备一把折叠伞。'
        }
        else {
            '降雨风险不高，通勤前再看一次本地天气即可。'
        }

        return [ordered]@{
            summary = $summary
            umbrella = $umbrella
        }
    }

    return [ordered]@{
        summary = '暂无可核验更新'
        umbrella = '暂无可核验更新'
    }
}

function Get-KplSeasonCandidates {
    param([datetime]$TargetDate)

    $order = if ($TargetDate.Month -le 6) { @('S1', 'S2') } else { @('S2', 'S1') }
    $years = @($TargetDate.Year, ($TargetDate.Year - 1), ($TargetDate.Year - 2))
    $seen = New-Object System.Collections.Generic.HashSet[string]
    $result = New-Object System.Collections.Generic.List[string]

    foreach ($year in $years) {
        foreach ($suffix in $order) {
            $id = "KPL{0}{1}" -f $year, $suffix
            if ($seen.Add($id)) {
                $result.Add($id) | Out-Null
            }
        }
    }

    return @($result)
}

function Get-KplOfficialSummary {
    param([datetime]$TargetDate)

    $targetToken = $TargetDate.ToString('yyyy-MM-dd')
    foreach ($seasonId in (Get-KplSeasonCandidates -TargetDate $TargetDate)) {
        $url = "https://tga-openapi.tga.qq.com/web/tgabank/getSchedules?seasonid=$seasonId&is_people=1"
        $data = Invoke-JsonRequest -Url $url -Timeout $TimeoutSec
        if ($null -eq $data -or $null -eq $data.data) { continue }

        $matches = @(
            $data.data |
                Where-Object { $_.match_state -eq 4 -and [string]$_.match_time -like "$targetToken*" } |
                Sort-Object match_time
        )
        if ($matches.Count -eq 0) { continue }

        $summaries = @()
        foreach ($match in ($matches | Select-Object -First 3)) {
            try {
                $timeText = ([datetime]$match.match_time).ToString('HH:mm')
            }
            catch {
                $timeText = [string]$match.match_time
            }
            $stageText = Normalize-NewsText -Text ([string]$match.stage_name)
            $summaries += ('{0} {1} {2}-{3} {4}（{5}）' -f $timeText, $match.hname, $match.host_score, $match.guest_score, $match.gname, $stageText)
        }

        if ($summaries.Count -gt 0) {
            return ($summaries -join '；')
        }
    }

    return '暂无可核验更新'
}

function Convert-ValorantEventText {
    param([string]$Text)
    $result = Normalize-NewsText -Text $Text
    $result = $result -replace '(?i)^Valorant ', '无畏契约'
    $result = $result -replace '(?i)Masters', '大师赛'
    $result = $result -replace '(?i)Champions', '全球冠军赛'
    $result = $result -replace '(?i)Santiago', '圣地亚哥'
    $result = $result -replace '(?i)Bangkok', '曼谷'
    return $result
}

function Convert-ValorantStageText {
    param([string]$Text)
    $result = Normalize-NewsText -Text $Text
    $map = [ordered]@{
        'Playoffs–Upper Quarterfinals' = '淘汰赛上半区四分之一决赛'
        'Playoffs–Upper Semifinals' = '淘汰赛上半区半决赛'
        'Playoffs–Upper Final' = '淘汰赛上半区决赛'
        'Playoffs–Lower Round 1' = '淘汰赛败者组第一轮'
        'Playoffs–Lower Round 2' = '淘汰赛败者组第二轮'
        'Playoffs–Lower Round 3' = '淘汰赛败者组第三轮'
        'Playoffs–Lower Final' = '淘汰赛败者组决赛'
        'Playoffs–Grand Final' = '总决赛'
        'Upper Quarterfinals' = '上半区四分之一决赛'
        'Upper Semifinals' = '上半区半决赛'
        'Upper Final' = '上半区决赛'
        'Lower Round 1' = '败者组第一轮'
        'Lower Round 2' = '败者组第二轮'
        'Lower Round 3' = '败者组第三轮'
        'Lower Final' = '败者组决赛'
        'Grand Final' = '总决赛'
    }
    foreach ($key in $map.Keys) {
        $result = $result -replace [regex]::Escape($key), $map[$key]
    }
    return $result
}

function Convert-EnglishClockText {
    param([string]$Text)

    $value = Normalize-NewsText -Text $Text
    if ($value -match '^(?<hour>\d{1,2}):(?<minute>\d{2})\s*(?<ampm>AM|PM)$') {
        $hour = [int]$Matches['hour']
        $minute = $Matches['minute']
        $ampm = $Matches['ampm']
        if ($ampm -eq 'AM') {
            if ($hour -eq 12) { $hour = 0 }
        }
        else {
            if ($hour -lt 12) { $hour += 12 }
        }
        return ('{0:D2}:{1}' -f $hour, $minute)
    }
    return $value
}

function Get-ValorantSummary {
    param([datetime]$TargetDate)

    $html = Invoke-TextRequest -Url 'https://www.vlr.gg/matches/results' -Timeout $TimeoutSec
    if ([string]::IsNullOrWhiteSpace($html)) {
        return '暂无可核验更新'
    }

    $culture = [System.Globalization.CultureInfo]::GetCultureInfo('en-US')
    $targetLabel = $TargetDate.ToString('ddd, MMMM d, yyyy', $culture)
    $sectionPattern = [regex]::Escape($targetLabel)
    $sectionMatch = [regex]::Match(
        $html,
        '(?s)<div class="wf-label mod-large">\s*' + $sectionPattern + '.*?</div>(?<block>.*?)(?=<div class="wf-label mod-large">|<div class="action-container">)',
        'IgnoreCase'
    )
    if (-not $sectionMatch.Success) {
        return '暂无可核验更新'
    }

    $section = $sectionMatch.Groups['block'].Value
    $itemMatches = [regex]::Matches($section, '(?s)<a href="[^"]+" class="wf-module-item match-item .*?">(?<body>.*?)</a>', 'IgnoreCase')
    if ($itemMatches.Count -eq 0) {
        return '暂无可核验更新'
    }

    $officialPattern = '(?i)\b(Masters|Champions|VCT)\b'
    $summaries = @()
    foreach ($item in $itemMatches) {
        $body = $item.Groups['body'].Value
        $eventMatch = [regex]::Match($body, '(?s)<div class="match-item-event text-of">\s*<div class="match-item-event-series text-of">\s*(?<series>.*?)\s*</div>\s*(?<event>[^<]+)', 'IgnoreCase')
        if (-not $eventMatch.Success) { continue }

        $eventText = Strip-Html -Text $eventMatch.Groups['event'].Value
        $seriesText = Strip-Html -Text $eventMatch.Groups['series'].Value
        if (($eventText + ' ' + $seriesText) -notmatch $officialPattern) { continue }

        $nameMatches = [regex]::Matches($body, '(?s)<div class="match-item-vs-team-name">\s*(?:<i[^>]*></i>\s*)?<div class="text-of">\s*(?:<span[^>]*></span>\s*)?(?<name>.*?)\s*</div>', 'IgnoreCase')
        $scoreMatches = [regex]::Matches($body, '<div class="match-item-vs-team-score[^"]*">\s*(?<score>\d+)\s*</div>', 'IgnoreCase')
        $timeMatch = [regex]::Match($body, '<div class="match-item-time">\s*(?<time>[^<]+?)\s*</div>', 'IgnoreCase')

        if ($nameMatches.Count -lt 2 -or $scoreMatches.Count -lt 2 -or -not $timeMatch.Success) { continue }

        $teamA = Normalize-NewsText -Text $nameMatches[0].Groups['name'].Value
        $teamB = Normalize-NewsText -Text $nameMatches[1].Groups['name'].Value
        $scoreA = $scoreMatches[0].Groups['score'].Value
        $scoreB = $scoreMatches[1].Groups['score'].Value
        $timeText = Convert-EnglishClockText -Text $timeMatch.Groups['time'].Value
        $eventLabel = Convert-ValorantEventText -Text $eventText
        $stageLabel = Convert-ValorantStageText -Text $seriesText

        $summaries += ('{0} {1} {2}：{3} {4}比{5} {6}' -f $timeText, $eventLabel, $stageLabel, $teamA, $scoreA, $scoreB, $teamB)
        if ($summaries.Count -ge 2) { break }
    }

    if ($summaries.Count -eq 0) {
        return '暂无可核验更新'
    }

    return ($summaries -join '；')
}

function Get-FirstArticleParagraph {
    param([string]$Html)

    $bodyMatch = [regex]::Match($Html, '(?s)<span id="detailContent">(?<content>.*?)</span>', 'IgnoreCase')
    if (-not $bodyMatch.Success) { return '' }

    $paragraphs = [regex]::Matches($bodyMatch.Groups['content'].Value, '(?s)<p>(?<text>.*?)</p>', 'IgnoreCase')
    foreach ($paragraph in $paragraphs) {
        $text = Normalize-NewsText -Text $paragraph.Groups['text'].Value
        $text = $text -replace '^新华社[\u4e00-\u9fff·]+?\d+月\d+日电[讯]?[，、]?', ''
        $text = $text -replace '^新华社[\u4e00-\u9fff·]+?电[，、]?', ''
        $text = $text.Trim('，', '。', ' ')
        if ($text.Length -ge 12) {
            return $text
        }
    }

    return ''
}

function Get-InternationalTopicBucket {
    param([string]$Text)

    switch -Regex ($Text) {
        '伊朗|以军|以色列|中东|黎巴嫩|叙利亚|沙特' { return 'middle-east' }
        '美国|白宫|国会|特朗普|拜登' { return 'us' }
        '俄罗斯|乌克兰|欧盟|法国|德国|挪威|英国' { return 'europe' }
        '日本|韩国|东盟|马来西亚|菲律宾|印度|巴基斯坦' { return 'asia' }
        '油价|能源|市场|制裁|贸易|经济|关税' { return 'economy' }
        default { return 'general' }
    }
}

function Get-InternationalImpactText {
    param([string]$Text)

    switch -Regex ($Text) {
        '爆炸|袭击|空袭|打击|战机|导弹|冲突|伤亡|战争' { return '相关地区安全风险仍在上升' }
        '制裁|军售|军火|关税|油价|能源|市场|经济' { return '后续可能继续影响地缘局势和市场预期' }
        '选举|政权|领导人|政府|总统|总理' { return '相关政治走向仍值得继续关注' }
        '搜寻|调查|残骸|失踪' { return '后续调查结果仍待进一步披露' }
        '会谈|通话|谈判|停火|磋商' { return '后续外交进展仍需观察' }
        default { return '后续进展仍需继续关注' }
    }
}

function Get-InternationalSummary {
    param([datetime]$TargetDate)

    $html = Invoke-TextRequest -Url 'https://www.news.cn/world/' -Timeout $TimeoutSec
    if ([string]::IsNullOrWhiteSpace($html)) {
        return '暂无可核验更新'
    }

    $dateToken = $TargetDate.ToString('yyyyMMdd')
    $pattern = 'href=[''\"](?<url>https://www\.news\.cn/world/' + $dateToken + '/[^''\"]+/c\.html)[''\"][^>]*>(?<title>[^<]{6,90})</a>'
    $matches = [regex]::Matches($html, $pattern, 'IgnoreCase')
    if ($matches.Count -eq 0) {
        return '暂无可核验更新'
    }

    $blacklist = @(
        '国际观察',
        '全球瞭望',
        '新华网国际看点',
        '记者手记',
        '记者观察',
        '综述',
        '特稿',
        '微视频',
        '图集',
        '图片',
        '列国鉴',
        '两会',
        '新华鲜报',
        '新华视点',
        '中国担当',
        '现场直击',
        '记者连线'
    )
    $hardNewsPattern = '爆炸|袭击|打击|军售|制裁|搜寻|发现|伤亡|事故|冲突|空袭|导弹|会谈|宣布|通话|调查|决定|批准|呼吁|警方|政府|总统|总理|使馆|残骸|停火|谈判|市场|油价|搜救'
    $candidates = New-Object System.Collections.Generic.List[object]
    $seenUrls = New-Object System.Collections.Generic.HashSet[string]
    foreach ($match in $matches) {
        $url = $match.Groups['url'].Value
        $title = Normalize-NewsText -Text $match.Groups['title'].Value
        if ([string]::IsNullOrWhiteSpace($url) -or [string]::IsNullOrWhiteSpace($title)) { continue }
        if (-not $seenUrls.Add($url)) { continue }

        $blocked = $false
        foreach ($token in $blacklist) {
            if ($title -like "*$token*") {
                $blocked = $true
                break
            }
        }
        if ($blocked) { continue }

        $score = 0
        if ($title -match $hardNewsPattern) { $score += 3 }
        if ($title -match '伊朗|以色列|美国|俄罗斯|乌克兰|欧盟|日本|韩国|马来西亚|挪威|使馆|油价|军售') { $score += 2 }

        $candidates.Add([pscustomobject]@{
            Url = $url
            Title = $title
            Score = $score
        }) | Out-Null
        if ($candidates.Count -ge 16) { break }
    }

    if ($candidates.Count -eq 0) {
        return '暂无可核验更新'
    }

    $digests = New-Object System.Collections.Generic.List[object]
    foreach ($candidate in ($candidates | Sort-Object @{ Expression = { $_.Score }; Descending = $true }, @{ Expression = { $_.Title }; Descending = $false } | Select-Object -First 8)) {
        $articleHtml = Invoke-TextRequest -Url $candidate.Url -Timeout $TimeoutSec
        if ([string]::IsNullOrWhiteSpace($articleHtml)) { continue }

        $titleMatch = [regex]::Match($articleHtml, '<span class="title">(?<title>.*?)</span>', 'IgnoreCase,Singleline')
        $headerTimeMatch = [regex]::Match($articleHtml, '<span class="time">(?<time>\d{2}:\d{2}:\d{2})</span>', 'IgnoreCase')
        $title = if ($titleMatch.Success) { Normalize-NewsText -Text $titleMatch.Groups['title'].Value } else { $candidate.Title }
        $lead = Get-FirstArticleParagraph -Html $articleHtml
        if ([string]::IsNullOrWhiteSpace($lead)) {
            $lead = $title
        }
        if ($lead.Length -gt 46) {
            $lead = $lead.Substring(0, 46).TrimEnd() + '...'
        }

        if ($title -notmatch $hardNewsPattern -and $lead -notmatch $hardNewsPattern) {
            continue
        }

        $timeText = $TargetDate.ToString('MM-dd')
        if ($headerTimeMatch.Success) {
            $timeText = '{0} {1}' -f $TargetDate.ToString('MM-dd'), $headerTimeMatch.Groups['time'].Value.Substring(0, 5)
        }

        $impact = Get-InternationalImpactText -Text ($title + ' ' + $lead)
        $summary = '{0} {1}：{2}，{3}' -f $timeText, $title, $lead, $impact
        $digests.Add([pscustomobject]@{
            Url = $candidate.Url
            Topic = Get-InternationalTopicBucket -Text ($title + ' ' + $lead)
            Summary = $summary
        }) | Out-Null
        if ($digests.Count -ge 6) { break }
    }

    if ($digests.Count -eq 0) {
        return '暂无可核验更新'
    }

    $picked = New-Object System.Collections.Generic.List[object]
    $seenTopics = New-Object System.Collections.Generic.HashSet[string]
    foreach ($item in $digests) {
        if ($seenTopics.Add($item.Topic)) {
            $picked.Add($item) | Out-Null
        }
        if ($picked.Count -ge 3) { break }
    }
    if ($picked.Count -lt 3) {
        foreach ($item in $digests) {
            $already = @($picked | Where-Object { $_.Url -eq $item.Url }).Count -gt 0
            if (-not $already) {
                $picked.Add($item) | Out-Null
            }
            if ($picked.Count -ge 3) { break }
        }
    }

    return ((@($picked | Select-Object -First 3).Summary) -join '；')
}

function Convert-FootballClubNameToChinese {
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) { return '' }

    $normalized = $Name.Trim()
    $map = @{
        'Arsenal' = '阿森纳'
        'Aston Villa' = '阿斯顿维拉'
        'Bournemouth' = '伯恩茅斯'
        'Brentford' = '布伦特福德'
        'Brighton' = '布莱顿'
        'Brighton & Hove Albion' = '布莱顿'
        'Burnley' = '伯恩利'
        'Chelsea' = '切尔西'
        'Crystal Palace' = '水晶宫'
        'Everton' = '埃弗顿'
        'Fulham' = '富勒姆'
        'Ipswich Town' = '伊普斯维奇'
        'Leicester City' = '莱斯特城'
        'Liverpool' = '利物浦'
        'Manchester City' = '曼城'
        'Man City' = '曼城'
        'Manchester United' = '曼联'
        'Man United' = '曼联'
        'Newcastle United' = '纽卡斯尔联'
        'Nottingham Forest' = '诺丁汉森林'
        'Southampton' = '南安普顿'
        'Tottenham Hotspur' = '托特纳姆热刺'
        'Tottenham' = '托特纳姆热刺'
        'West Ham United' = '西汉姆联'
        'Wolverhampton Wanderers' = '狼队'
        'Wolves' = '狼队'
        'Athletic Club' = '毕尔巴鄂竞技'
        'Atlético de Madrid' = '马德里竞技'
        'Atletico Madrid' = '马德里竞技'
        'Barcelona' = '巴塞罗那'
        'Real Madrid' = '皇家马德里'
        'Villarreal' = '比利亚雷亚尔'
        'Villarreal CF' = '比利亚雷亚尔'
        'Elche' = '埃尔切'
        'Elche CF' = '埃尔切'
        'Getafe' = '赫塔费'
        'Getafe CF' = '赫塔费'
        'Real Betis' = '皇家贝蒂斯'
        'Sevilla' = '塞维利亚'
        'Valencia' = '瓦伦西亚'
        'Real Sociedad' = '皇家社会'
        'Celta Vigo' = '塞尔塔'
        'RC Celta' = '塞尔塔'
        'Girona' = '赫罗纳'
        'Rayo Vallecano' = '巴列卡诺'
        'Mallorca' = '马略卡'
        'Espanyol' = '西班牙人'
        'Las Palmas' = '拉斯帕尔马斯'
        'Alavés' = '阿拉维斯'
        'Alaves' = '阿拉维斯'
        'Leganés' = '莱加内斯'
        'Leganes' = '莱加内斯'
        'Osasuna' = '奥萨苏纳'
        'Real Valladolid' = '巴拉多利德'
        'Bayern Munich' = '拜仁慕尼黑'
        'Borussia Dortmund' = '多特蒙德'
        'Bayer Leverkusen' = '勒沃库森'
        'RB Leipzig' = 'RB莱比锡'
        'Paris Saint-Germain' = '巴黎圣日耳曼'
        'PSG' = '巴黎圣日耳曼'
        'Inter' = '国际米兰'
        'Internazionale' = '国际米兰'
        'AC Milan' = 'AC米兰'
        'Milan' = 'AC米兰'
        'Juventus' = '尤文图斯'
        'Napoli' = '那不勒斯'
        'Roma' = '罗马'
        'Atalanta' = '亚特兰大'
        'Lazio' = '拉齐奥'
        'Fiorentina' = '佛罗伦萨'
        'Sporting CP' = '葡萄牙体育'
        'Sporting' = '葡萄牙体育'
        'Benfica' = '本菲卡'
        'Porto' = '波尔图'
        'PSV' = '埃因霍温'
        'PSV Eindhoven' = '埃因霍温'
        'Feyenoord' = '费耶诺德'
        'Ajax' = '阿贾克斯'
        'Celtic' = '凯尔特人'
        'Rangers' = '格拉斯哥流浪者'
        'Club Brugge' = '布鲁日'
        'Shakhtar Donetsk' = '顿涅茨克矿工'
        'Dynamo Kyiv' = '基辅迪纳摩'
        'Galatasaray' = '加拉塔萨雷'
        'Fenerbahçe' = '费内巴切'
        'Fenerbahce' = '费内巴切'
        'Olympiacos' = '奥林匹亚科斯'
        'Slavia Prague' = '布拉格斯拉维亚'
        'Sparta Prague' = '布拉格斯巴达'
        'Red Bull Salzburg' = '萨尔茨堡红牛'
        'Salzburg' = '萨尔茨堡红牛'
        'Young Boys' = '年轻人'
        'Copenhagen' = '哥本哈根'
        'Dinamo Zagreb' = '萨格勒布迪纳摩'
        'Crvena zvezda' = '贝尔格莱德红星'
        'Monaco' = '摩纳哥'
        'Marseille' = '马赛'
        'Lille' = '里尔'
        'Nice' = '尼斯'
    }

    if ($map.ContainsKey($normalized)) {
        return $map[$normalized]
    }

    return $normalized
}

function Convert-FootballPlayerNameToChinese {
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) { return '' }

    $normalized = $Name.Trim()
    $map = @{
        'Tajon Buchanan' = '布坎南'
        'Santiago Mouriño' = '圣地亚哥·穆里尼奥'
        'André Silva' = '安德烈·席尔瓦'
        'Andre Silva' = '安德烈·席尔瓦'
        'Kiko Femenía' = '基科·费梅尼亚'
        'Kiko Femenia' = '基科·费梅尼亚'
        'Martín Satriano' = '马丁·萨特里亚诺'
        'Martin Satriano' = '马丁·萨特里亚诺'
        'Kylian Mbappé' = '姆巴佩'
        'Kylian Mbappe' = '姆巴佩'
        'Erling Haaland' = '哈兰德'
        'Mohamed Salah' = '萨拉赫'
        'Vinícius Júnior' = '维尼修斯'
        'Vinicius Junior' = '维尼修斯'
        'Jude Bellingham' = '贝林厄姆'
        'Robert Lewandowski' = '莱万多夫斯基'
        'Harry Kane' = '凯恩'
        'Lautaro Martínez' = '劳塔罗'
        'Lautaro Martinez' = '劳塔罗'
        'Marcus Rashford' = '拉什福德'
        'Bukayo Saka' = '萨卡'
        'Cole Palmer' = '帕尔默'
        'Son Heung-min' = '孙兴慜'
        'Heung-Min Son' = '孙兴慜'
        'Kevin De Bruyne' = '德布劳内'
        'Bruno Fernandes' = '布鲁诺·费尔南德斯'
        'Pedri' = '佩德里'
        'Gavi' = '加维'
        'Antoine Griezmann' = '格列兹曼'
        'Julián Álvarez' = '阿尔瓦雷斯'
        'Julian Alvarez' = '阿尔瓦雷斯'
        'Lamine Yamal' = '亚马尔'
    }

    if ($map.ContainsKey($normalized)) {
        return $map[$normalized]
    }

    return $normalized
}

function Convert-FootballEventToSummary {
    param([object]$Event)

    $competition = @($Event.competitions)[0]
    if ($null -eq $competition) { return $null }
    if (-not $competition.status.type.completed) { return $null }

    $homeTeam = @($competition.competitors | Where-Object { $_.homeAway -eq 'home' })[0]
    $awayTeam = @($competition.competitors | Where-Object { $_.homeAway -eq 'away' })[0]
    if ($null -eq $homeTeam -or $null -eq $awayTeam) { return $null }

    $kickoffText = ''
    try {
        $kickoffText = Get-ChinaTimeText -DateTimeValue ([datetime]$Event.date)
    }
    catch {
        $kickoffText = ''
    }

    $homeName = Convert-FootballClubNameToChinese -Name ([string]$homeTeam.team.displayName)
    $awayName = Convert-FootballClubNameToChinese -Name ([string]$awayTeam.team.displayName)

    $scoreLine = '{0} {1}-{2} {3}' -f $homeName, $homeTeam.score, $awayTeam.score, $awayName
    if ($kickoffText) {
        $scoreLine = "$kickoffText $scoreLine"
    }

    $goalPlays = @($competition.details | Where-Object { $_.scoringPlay -eq $true })
    if ($goalPlays.Count -eq 0) {
        return $scoreLine
    }

    $goalLines = @()
    foreach ($play in $goalPlays) {
        $teamId = [string]$play.team.id
        $teamName = if ([string]$homeTeam.team.id -eq $teamId) { $homeName } else { $awayName }
        $athlete = @($play.athletesInvolved)[0]
        $scorer = if ($null -ne $athlete -and $athlete.displayName) { Convert-FootballPlayerNameToChinese -Name ([string]$athlete.displayName) } else { '进球' }
        $clock = [string]$play.clock.displayValue
        $goalLines += ('{0}-{1} {2}' -f $teamName, $scorer, $clock)
    }

    return ($scoreLine + '；进球：' + ($goalLines -join '，'))
}

function Get-FootballLeagueSummary {
    param(
        [string]$LeagueKey,
        [datetime]$TargetDate
    )

    $dateToken = $TargetDate.ToString('yyyyMMdd')
    $url = "https://site.api.espn.com/apis/site/v2/sports/soccer/$LeagueKey/scoreboard?dates=$dateToken"
    $data = Invoke-JsonRequest -Url $url -Timeout $TimeoutSec -Headers @{
        'Accept-Language' = 'en-US,en;q=0.9'
    }
    if ($null -eq $data -or $null -eq $data.events) {
        return '暂无可核验更新'
    }

    $events = @($data.events | Where-Object { $_.status.type.completed -eq $true })
    if ($events.Count -eq 0) {
        return '暂无可核验更新'
    }

    $summaries = @()
    foreach ($event in ($events | Sort-Object date | Select-Object -First 2)) {
        $summary = Convert-FootballEventToSummary -Event $event
        if (-not [string]::IsNullOrWhiteSpace($summary)) {
            $summaries += $summary
        }
    }

    if ($summaries.Count -eq 0) {
        return '暂无可核验更新'
    }

    return ($summaries -join '；')
}

$cacheDir = Join-Path $Workspace 'cache\morning-digest'
$memoryDir = Join-Path $Workspace 'memory'
$cacheDate = $AsOf.ToString('yyyy-MM-dd')
$cachePath = Join-Path $cacheDir "$cacheDate.json"
$targetNewsDate = $AsOf.Date.AddDays(-1)

$digest = New-DefaultDigest -Region $Location -RunTime $AsOf
$digest.weather = Get-WeatherDigest -Region $Location -Codes @($WeatherDistrictCode, $WeatherCityCode)
$digest.plan = Parse-PlanFields -Body (Get-PlanCaptureBody -MemoryDir $memoryDir)
$digest.news.valorant = Get-ValorantSummary -TargetDate $targetNewsDate
$digest.news.kpl = Get-KplOfficialSummary -TargetDate $targetNewsDate
$digest.news.football.laliga = Get-FootballLeagueSummary -LeagueKey 'esp.1' -TargetDate $targetNewsDate
$digest.news.football.epl = Get-FootballLeagueSummary -LeagueKey 'eng.1' -TargetDate $targetNewsDate
$digest.news.football.ucl = Get-FootballLeagueSummary -LeagueKey 'uefa.champions' -TargetDate $targetNewsDate
$digest.news.international = Get-InternationalSummary -TargetDate $targetNewsDate

Ensure-Dir -Path $cacheDir

if ($DryRun) {
    Write-Host "[DryRun] Would write cache: $cachePath"
    $digest | ConvertTo-Json -Depth 10
}
else {
    $digest | ConvertTo-Json -Depth 10 | Set-Content -Path $cachePath -Encoding UTF8
    Write-Host "Morning digest cache written: $cachePath"
}
