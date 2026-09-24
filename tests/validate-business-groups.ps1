param(
    [string]$IniPath = (Join-Path $PSScriptRoot '..\subconverter.ini')
)

$ErrorActionPreference = 'Stop'

$targetGroups = @(
    '📲 电报消息',
    '💬 Ai平台',
    '📹 油管视频',
    '🎥 奈飞视频',
    '🏰 Disney+',
    '📺 巴哈姆特',
    '📺 哔哩哔哩',
    '🇯🇵 日本服务',
    '🎬 小宝影院',
    '🌍 国外媒体',
    '🌏 国内媒体',
    '📢 谷歌FCM',
    'Ⓜ️ 微软Bing',
    'Ⓜ️ 微软云盘',
    'Ⓜ️ 微软服务',
    '🍎 苹果服务',
    '🎮 游戏平台',
    '🎶 网易音乐',
    '🐟 漏网之鱼'
)

$excludedGroups = @(
    '☑️ 手动切换',
    '🏠 自建节点',
    '🛟 备用自建',
    '🎯 全球直连',
    '🛑 广告拦截',
    '🍃 应用净化',
    '🇭🇰 香港节点',
    '🇯🇵 日本节点',
    '🇺🇲 美国节点',
    '🇸🇬 狮城节点',
    '🇹🇼 台湾节点',
    '🇰🇷 韩国节点',
    '🎥 奈飞节点'
)

$lines = Get-Content -Encoding utf8 -LiteralPath $IniPath
$groups = @{}

foreach ($line in ($lines | Where-Object { $_ -like 'custom_proxy_group=*' })) {
    $parts = $line -split [char]96
    $name = $parts[0].Substring('custom_proxy_group='.Length)
    $references = @()

    if ($parts.Count -gt 2) {
        foreach ($part in $parts[2..($parts.Count - 1)]) {
            if ($part.StartsWith('[]')) {
                $references += $part.Substring(2)
            }
        }
    }

    $groups[$name] = $references
}

$requiredReferences = @('🏠 自建节点', '🛟 备用自建')

foreach ($name in $targetGroups) {
    if (-not $groups.ContainsKey($name)) {
        throw "Target group not found: $name"
    }

    foreach ($reference in $requiredReferences) {
        if ($groups[$name] -notcontains $reference) {
            throw "Target group missing self-hosted options: $name"
        }
    }

    $anchor = if ($name -eq '📺 哔哩哔哩') {
        '🎯 全球直连'
    } elseif ($name -eq '🌏 国内媒体') {
        'DIRECT'
    } elseif ($name -eq '🇯🇵 日本服务') {
        '🚀 节点选择'
    } else {
        '🚀 节点选择'
    }

    $anchorIndex = [Array]::IndexOf($groups[$name], $anchor)
    if (
        $anchorIndex -lt 0 -or
        $anchorIndex + 2 -ge $groups[$name].Count -or
        $groups[$name][$anchorIndex + 1] -ne '🏠 自建节点' -or
        $groups[$name][$anchorIndex + 2] -ne '🛟 备用自建'
    ) {
        throw "Self-hosted option order is incorrect: $name"
    }
}

foreach ($name in $excludedGroups) {
    if (-not $groups.ContainsKey($name)) {
        throw "Excluded group not found: $name"
    }

    foreach ($reference in $requiredReferences) {
        if ($groups[$name] -contains $reference) {
            throw "Excluded group contains self-hosted option: $name"
        }
    }
}

if ($groups['🎬 小宝影院'][0] -ne '🇭🇰 香港节点') {
    throw 'Xiaobao Cinema must default to the Hong Kong group'
}

$expectedJapanOptions = @(
    '🇯🇵 日本节点',
    '🚀 节点选择',
    '🏠 自建节点',
    '🛟 备用自建',
    '🇭🇰 香港节点',
    '🇹🇼 台湾节点',
    '🇸🇬 狮城节点',
    '🇺🇲 美国节点',
    '🇰🇷 韩国节点',
    '☑️ 手动切换',
    'DIRECT'
)

if (Compare-Object -ReferenceObject $expectedJapanOptions -DifferenceObject $groups['🇯🇵 日本服务'] -SyncWindow 0) {
    throw 'Japan Services group options or option order are incorrect'
}

$requiredJapanRules = @(
    'ruleset=🇯🇵 日本服务,https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/DMM/DMM.list',
    'ruleset=🇯🇵 日本服务,https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/Niconico/Niconico.list',
    'ruleset=🇯🇵 日本服务,https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/AbemaTV/AbemaTV.list',
    'ruleset=🇯🇵 日本服务,[]DOMAIN-SUFFIX,pia.jp',
    'ruleset=🇯🇵 日本服务,[]DOMAIN-SUFFIX,dlsite.com',
    'ruleset=🇯🇵 日本服务,[]DOMAIN-SUFFIX,melonbooks.co.jp',
    'ruleset=🇯🇵 日本服务,[]DOMAIN-SUFFIX,tver.jp'
)

foreach ($rule in $requiredJapanRules) {
    if ($lines -notcontains $rule) {
        throw "Required Japan Services rule not found: $rule"
    }
}

if ($lines -contains 'ruleset=🇯🇵 日本服务,[]DOMAIN-SUFFIX,jp') {
    throw 'Japan Services must not match the entire .jp TLD'
}

$pixivRuleIndex = [Array]::IndexOf($lines, 'ruleset=🎨 Pixiv,[]DOMAIN-SUFFIX,pixiv.net')
$japanRuleIndex = [Array]::IndexOf($lines, $requiredJapanRules[0])

if ($pixivRuleIndex -lt 0 -or $japanRuleIndex -lt 0 -or $pixivRuleIndex -ge $japanRuleIndex) {
    throw 'Pixiv rules must take precedence over Japan Services rules'
}

$requiredXiaobaoRules = @(
    'ruleset=🎬 小宝影院,[]DOMAIN-SUFFIX,xiaobaotv.com',
    'ruleset=🎬 小宝影院,[]DOMAIN-KEYWORD,dytt-',
    'ruleset=🎬 小宝影院,[]DOMAIN-SUFFIX,dyttimage.com'
)

foreach ($rule in $requiredXiaobaoRules) {
    if ($lines -notcontains $rule) {
        throw "Required Xiaobao Cinema rule not found: $rule"
    }
}

$expectedPs5Options = @(
    '🚀 节点选择',
    '🏠 自建节点',
    '🇭🇰 香港节点',
    '🇯🇵 日本节点',
    '🇺🇲 美国节点',
    'DIRECT'
)

if (-not $groups.ContainsKey('🎮 PS5节点')) {
    throw 'PS5 group not found'
}

if (Compare-Object -ReferenceObject $expectedPs5Options -DifferenceObject $groups['🎮 PS5节点'] -SyncWindow 0) {
    throw 'PS5 group options or option order are incorrect'
}

$visiting = [System.Collections.Generic.HashSet[string]]::new()
$visited = [System.Collections.Generic.HashSet[string]]::new()

function Visit-Group([string]$Name) {
    if ($visiting.Contains($Name)) {
        throw "Policy group cycle detected at: $Name"
    }

    if ($visited.Contains($Name)) {
        return
    }

    [void]$visiting.Add($Name)
    foreach ($reference in $groups[$Name]) {
        if ($groups.ContainsKey($reference)) {
            Visit-Group $reference
        }
    }
    [void]$visiting.Remove($Name)
    [void]$visited.Add($Name)
}

foreach ($name in @($groups.Keys)) {
    Visit-Group $name
}

Write-Output "$($targetGroups.Count) target groups validated; exclusions clean; graph acyclic"
