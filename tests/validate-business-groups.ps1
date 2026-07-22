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
    '🚀 手动切换',
    '🏠 自建节点',
    '🛟 备用自建节点',
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

$requiredReferences = @('🏠 自建节点', '🛟 备用自建节点')

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
    } else {
        '🚀 节点选择'
    }

    $anchorIndex = [Array]::IndexOf($groups[$name], $anchor)
    if (
        $anchorIndex -lt 0 -or
        $anchorIndex + 2 -ge $groups[$name].Count -or
        $groups[$name][$anchorIndex + 1] -ne '🏠 自建节点' -or
        $groups[$name][$anchorIndex + 2] -ne '🛟 备用自建节点'
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
