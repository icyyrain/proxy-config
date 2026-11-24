$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$scriptPath = Join-Path $PSScriptRoot '..\scripts\New-SubconverterLink.ps1'
$fixturePath = Join-Path $PSScriptRoot 'fixtures\subscription.test.psd1'
$assertions = 0

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
    $script:assertions++
}

function Assert-Equal {
    param(
        $Expected,
        $Actual,
        [string]$Message
    )

    if ($Expected -cne $Actual) {
        throw "$Message (expected '$Expected', actual '$Actual')"
    }
    $script:assertions++
}

function ConvertFrom-QueryString {
    param([string]$Query)

    $result = @{}
    foreach ($pair in $Query.TrimStart('?').Split('&')) {
        $separator = $pair.IndexOf('=')
        $key = if ($separator -ge 0) {
            [Uri]::UnescapeDataString($pair.Substring(0, $separator))
        } else {
            [Uri]::UnescapeDataString($pair)
        }
        $value = if ($separator -ge 0) {
            [Uri]::UnescapeDataString($pair.Substring($separator + 1))
        } else {
            ''
        }
        $result[$key] = $value
    }
    return $result
}

if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Generator script not found: $scriptPath"
}

$defaultResult = & $scriptPath -ConfigPath $fixturePath
$defaultUri = [Uri]$defaultResult.LongUrl
$defaultQuery = ConvertFrom-QueryString $defaultUri.Query

Assert-Equal 'api.v1.mk' $defaultUri.Host 'Backend host mismatch'
Assert-Equal '/sub' $defaultUri.AbsolutePath 'Backend path mismatch'
Assert-Equal 'clash' $defaultQuery.target 'Target mismatch'
Assert-Equal 'https://example.invalid/3x-ui?client=test|https://airport.example.invalid/sub?token=fake' $defaultQuery.url 'Source join mismatch'
Assert-Equal 'false' $defaultQuery.insert 'Insert mismatch'
Assert-Equal 'https://raw.githubusercontent.com/icyyrain/proxy-config/main/subconverter.ini?v=selfhost-v1' $defaultQuery.config 'Remote config mismatch'
Assert-Equal '摩卡空港 MochaKuko' $defaultQuery.filename 'Subscription name mismatch'
Assert-Equal '-icyy$@' $defaultQuery.rename 'Automatic rename mismatch'
Assert-Equal 'true' $defaultQuery.emoji 'Emoji mismatch'
Assert-Equal 'false' $defaultQuery.list 'Node list mismatch'
Assert-Equal 'true' $defaultQuery.xudp 'XUDP mismatch'
Assert-Equal 'true' $defaultQuery.udp 'UDP mismatch'
Assert-Equal 'false' $defaultQuery.tfo 'TFO mismatch'
Assert-Equal 'true' $defaultQuery.expand 'Expand mismatch'
Assert-Equal 'false' $defaultQuery.scv 'SCV mismatch'
Assert-Equal 'false' $defaultQuery.fdn 'FDN mismatch'
Assert-Equal 'true' $defaultQuery.new_name 'Clash field-name mismatch'
Assert-Equal 'ShadowRocket' $defaultQuery.diyua 'User-Agent mismatch'
Assert-Equal '(?:MochaKK)' $defaultQuery.selfhost 'Default self-hosted prefixes mismatch'
Assert-True ([string]::IsNullOrEmpty($defaultResult.ShortUrl)) 'Default execution unexpectedly created a short link'

$friendResult = & $scriptPath `
    -ConfigPath $fixturePath `
    -ThreeXuiSubscriptionUrl 'https://friend.example.invalid/sub?client=friend' `
    -ClientName 'friend' `
    -SubscriptionName 'Friend Port'
$friendQuery = ConvertFrom-QueryString ([Uri]$friendResult.LongUrl).Query

Assert-Equal 'https://friend.example.invalid/sub?client=friend|https://airport.example.invalid/sub?token=fake' $friendQuery.url 'Friend override lost the default airport source'
Assert-Equal '-friend$@' $friendQuery.rename 'Friend rename mismatch'
Assert-Equal 'Friend Port' $friendQuery.filename 'Friend subscription name mismatch'

$prefixResult = & $scriptPath -ConfigPath $fixturePath -SelfHostedPrefixes @('MochaKK', 'FriendVPS')
$prefixQuery = ConvertFrom-QueryString ([Uri]$prefixResult.LongUrl).Query
Assert-Equal '(?:MochaKK|FriendVPS)' $prefixQuery.selfhost 'Multiple prefix encoding mismatch'
Assert-Equal $defaultQuery.url $prefixQuery.url 'Prefix filtering changed subscription sources'
Assert-Equal $defaultQuery.rename $prefixQuery.rename 'Prefix filtering changed rename behavior'

$literalResult = & $scriptPath -ConfigPath $fixturePath -SelfHostedPrefixes @(' C++ ', 'Lab.(A)', 'Pipe|Home', 'Back`Tick', 'C++')
$literalQuery = ConvertFrom-QueryString ([Uri]$literalResult.LongUrl).Query
Assert-Equal '(?:C\+\+|Lab\.\(A\)|Pipe\|Home|Back\x60Tick)' $literalQuery.selfhost 'Literal prefix escaping or deduplication mismatch'
foreach ($name in @('🇺🇸 C++-main', 'Lab.(A)-main', 'Pipe|Home-main', 'Back`Tick-main')) {
    Assert-True ([regex]::IsMatch($name, $literalQuery.selfhost)) 'A literal prefix did not match its node'
}
foreach ($name in @('Cxxxx-main', 'LabXA-main', 'Pipe-main', 'Home-main')) {
    Assert-True (-not [regex]::IsMatch($name, $literalQuery.selfhost)) 'A prefix was interpreted as a regular expression'
}

foreach ($badPrefixes in @(
    @{Value = @()},
    @{Value = @('')},
    @{Value = @('Good', ' ')},
    @{Value = @("Bad`nNode")},
    @{Value = @("Good`n")}
)) {
    $failed = $false
    try { $null = & $scriptPath -ConfigPath $fixturePath -SelfHostedPrefixes $badPrefixes.Value }
    catch { $failed = $true }
    Assert-True $failed 'Invalid prefix input was accepted'
}

$tempConfig = [IO.Path]::GetTempFileName() + '.psd1'
try {
    $fixtureText = Get-Content -LiteralPath $fixturePath -Raw -Encoding utf8
    $fixtureText = $fixtureText.Replace('@{', "@{`n    SelfHostedPrefixes = @('ConfiguredHome', 'LocalBackup')")
    [IO.File]::WriteAllText($tempConfig, $fixtureText, [Text.UTF8Encoding]::new($true))
    $fromFile = & $scriptPath -ConfigPath $tempConfig
    Assert-Equal '(?:ConfiguredHome|LocalBackup)' (ConvertFrom-QueryString ([Uri]$fromFile.LongUrl).Query).selfhost 'Local configuration prefix list was ignored'
    $overridden = & $scriptPath -ConfigPath $tempConfig -SelfHostedPrefixes @('CliHome')
    Assert-Equal '(?:CliHome)' (ConvertFrom-QueryString ([Uri]$overridden.LongUrl).Query).selfhost 'Command line did not override local prefixes'
} finally {
    Remove-Item -LiteralPath $tempConfig -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath ($tempConfig -replace '\.psd1$', '') -Force -ErrorAction SilentlyContinue
}

$customConfig = & $scriptPath -ConfigPath $fixturePath -RemoteConfigUrl 'https://config.example.invalid/custom.ini?revision=2'
Assert-Equal 'https://config.example.invalid/custom.ini?revision=2' (ConvertFrom-QueryString ([Uri]$customConfig.LongUrl).Query).config 'Custom remote configuration URL was changed'

$probe = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$probe.Start()
$port = ([Net.IPEndPoint]$probe.LocalEndpoint).Port
$probe.Stop()

$listenerJob = Start-Job -ArgumentList $port -ScriptBlock {
    param([int]$Port)

    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $Port)
    $listener.Start()
    try {
        $client = $listener.AcceptTcpClient()
        $stream = $client.GetStream()
        $stream.ReadTimeout = 10000
        $memory = [IO.MemoryStream]::new()
        $buffer = New-Object byte[] 4096
        $headerEnd = -1
        $contentLength = -1

        while ($true) {
            $read = $stream.Read($buffer, 0, $buffer.Length)
            if ($read -le 0) {
                break
            }
            $memory.Write($buffer, 0, $read)
            $bytes = $memory.ToArray()
            $text = [Text.Encoding]::ASCII.GetString($bytes)

            if ($headerEnd -lt 0) {
                $headerEnd = $text.IndexOf("`r`n`r`n", [StringComparison]::Ordinal)
                if ($headerEnd -ge 0) {
                    $headerText = $text.Substring(0, $headerEnd)
                    $match = [regex]::Match($headerText, '(?im)^Content-Length:\s*(\d+)\s*$')
                    if (-not $match.Success) {
                        throw 'Content-Length header missing'
                    }
                    $contentLength = [int]$match.Groups[1].Value
                }
            }

            if ($headerEnd -ge 0 -and $memory.Length -ge ($headerEnd + 4 + $contentLength)) {
                break
            }
        }

        $allBytes = $memory.ToArray()
        $bodyOffset = $headerEnd + 4
        $body = [Text.Encoding]::UTF8.GetString($allBytes, $bodyOffset, $contentLength)
        $responseBody = '{"Code":1,"ShortUrl":"https://v1.mk/test-key"}'
        $responseBytes = [Text.Encoding]::UTF8.GetBytes($responseBody)
        $headers = "HTTP/1.1 200 OK`r`nContent-Type: application/json`r`nContent-Length: $($responseBytes.Length)`r`nConnection: close`r`n`r`n"
        $headerBytes = [Text.Encoding]::ASCII.GetBytes($headers)
        $stream.Write($headerBytes, 0, $headerBytes.Length)
        $stream.Write($responseBytes, 0, $responseBytes.Length)
        $stream.Flush()
        $client.Close()
        Write-Output $body
    } finally {
        $listener.Stop()
    }
}

Start-Sleep -Milliseconds 500
try {
    $shortResult = & $scriptPath `
        -ConfigPath $fixturePath `
        -ShortUrlEndpoint "http://127.0.0.1:$port/short" `
        -CreateShort `
        -ShortKey 'test-key'
    $listenerJob | Wait-Job -Timeout 15 | Out-Null
    $multipartBody = $listenerJob | Receive-Job
} finally {
    $listenerJob | Remove-Job -Force -ErrorAction SilentlyContinue
}

Assert-Equal 'https://v1.mk/test-key' $shortResult.ShortUrl 'Short URL mismatch'
Assert-True $multipartBody.Contains('name=longUrl') 'Multipart longUrl field missing'
Assert-True $multipartBody.Contains('name=shortKey') 'Multipart shortKey field missing'
Assert-True $multipartBody.Contains('test-key') 'Multipart shortKey value missing'
$expectedBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($shortResult.LongUrl))
Assert-True $multipartBody.Contains($expectedBase64) 'Multipart longUrl Base64 mismatch'

Write-Output "Link generator validation passed ($assertions assertions)"
