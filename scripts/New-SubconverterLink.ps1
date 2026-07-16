[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot '..\config\subscription.local.psd1'),
    [string]$ThreeXuiSubscriptionUrl,
    [string]$AirportSubscriptionUrl,
    [string]$ClientName,
    [string]$SubscriptionName,
    [string]$RemoteConfigUrl,
    [string]$BackendUrl,
    [string]$ShortUrlEndpoint,
    [string]$RenameRule,
    [Nullable[bool]]$Udp,
    [Nullable[bool]]$Xudp,
    [Nullable[bool]]$Emoji,
    [Nullable[bool]]$ExpandRules,
    [Nullable[bool]]$ClashNewFieldName,
    [string]$UserAgent,
    [switch]$CreateShort,
    [string]$ShortKey
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$bound = $PSBoundParameters
$localConfig = @{}
if (Test-Path -LiteralPath $ConfigPath) {
    $localConfig = Import-PowerShellDataFile -LiteralPath $ConfigPath
}

function Resolve-Setting {
    param(
        [string]$Name,
        $BuiltInDefault
    )

    if ($bound.ContainsKey($Name)) {
        return $bound[$Name]
    }
    if ($localConfig.ContainsKey($Name)) {
        return $localConfig[$Name]
    }
    return $BuiltInDefault
}

function Assert-HttpUrl {
    param(
        [string]$Value,
        [string]$Name
    )

    $parsed = $null
    if (
        [string]::IsNullOrWhiteSpace($Value) -or
        -not [Uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$parsed) -or
        $parsed.Scheme -notin @('http', 'https')
    ) {
        throw "$Name must be an absolute HTTP/HTTPS URL."
    }
    return $Value
}

function ConvertTo-Boolean {
    param(
        $Value,
        [string]$Name
    )

    if ($Value -is [bool]) {
        return $Value
    }

    $parsed = $false
    if ($Value -is [string] -and [bool]::TryParse($Value, [ref]$parsed)) {
        return $parsed
    }

    throw "$Name must be true or false."
}

function ConvertTo-QueryValue {
    param($Value)
    return [Uri]::EscapeDataString([string]$Value)
}

function ConvertTo-LowerBoolean {
    param([bool]$Value)
    return $Value.ToString().ToLowerInvariant()
}

$threeXuiUrl = Assert-HttpUrl (Resolve-Setting 'ThreeXuiSubscriptionUrl' $null) 'ThreeXuiSubscriptionUrl'
$airportUrl = Assert-HttpUrl (Resolve-Setting 'AirportSubscriptionUrl' $null) 'AirportSubscriptionUrl'
$remoteConfig = Assert-HttpUrl (
    Resolve-Setting 'RemoteConfigUrl' 'https://raw.githubusercontent.com/icyyrain/proxy-config/main/subconverter.ini'
) 'RemoteConfigUrl'
$backend = Assert-HttpUrl (Resolve-Setting 'BackendUrl' 'https://api.v1.mk') 'BackendUrl'
$shortEndpoint = Assert-HttpUrl (Resolve-Setting 'ShortUrlEndpoint' 'https://v1.mk/short') 'ShortUrlEndpoint'
$resolvedClientName = [string](Resolve-Setting 'ClientName' '')
$resolvedSubscriptionName = [string](Resolve-Setting 'SubscriptionName' '')
$resolvedRenameRule = [string](Resolve-Setting 'RenameRule' '')
$resolvedUserAgent = [string](Resolve-Setting 'UserAgent' 'ShadowRocket')
$resolvedUdp = ConvertTo-Boolean (Resolve-Setting 'Udp' $true) 'Udp'
$resolvedXudp = ConvertTo-Boolean (Resolve-Setting 'Xudp' $true) 'Xudp'
$resolvedEmoji = ConvertTo-Boolean (Resolve-Setting 'Emoji' $true) 'Emoji'
$resolvedExpand = ConvertTo-Boolean (Resolve-Setting 'ExpandRules' $true) 'ExpandRules'
$resolvedNewName = ConvertTo-Boolean (Resolve-Setting 'ClashNewFieldName' $true) 'ClashNewFieldName'

if ([string]::IsNullOrWhiteSpace($resolvedSubscriptionName)) {
    throw 'SubscriptionName must not be empty.'
}

if ([string]::IsNullOrWhiteSpace($resolvedRenameRule)) {
    if ([string]::IsNullOrWhiteSpace($resolvedClientName)) {
        throw 'ClientName must not be empty when RenameRule is not provided.'
    }
    $resolvedRenameRule = "-$resolvedClientName`$@"
}

if ($ShortKey -match '(?i)http') {
    throw 'ShortKey must be a suffix, not a URL.'
}

$source = "$threeXuiUrl|$airportUrl"
$queryValues = [ordered]@{
    target   = 'clash'
    url      = $source
    insert   = 'false'
    config   = $remoteConfig
    filename = $resolvedSubscriptionName
    rename   = $resolvedRenameRule
    emoji    = ConvertTo-LowerBoolean $resolvedEmoji
    list     = 'false'
    xudp     = ConvertTo-LowerBoolean $resolvedXudp
    udp      = ConvertTo-LowerBoolean $resolvedUdp
    tfo      = 'false'
    expand   = ConvertTo-LowerBoolean $resolvedExpand
    scv      = 'false'
    fdn      = 'false'
    new_name = ConvertTo-LowerBoolean $resolvedNewName
    diyua    = $resolvedUserAgent
}

$query = (
    $queryValues.GetEnumerator() |
        ForEach-Object { '{0}={1}' -f $_.Key, (ConvertTo-QueryValue $_.Value) }
) -join '&'
$longUrl = $backend.TrimEnd('/') + '/sub?' + $query
$shortUrl = $null

if ($CreateShort) {
    Add-Type -AssemblyName System.Net.Http
    $base64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($longUrl))
    $client = [System.Net.Http.HttpClient]::new()
    $form = [System.Net.Http.MultipartFormDataContent]::new()
    $response = $null

    try {
        $form.Add([System.Net.Http.StringContent]::new($base64), 'longUrl')
        if (-not [string]::IsNullOrWhiteSpace($ShortKey)) {
            $form.Add([System.Net.Http.StringContent]::new($ShortKey), 'shortKey')
        }

        $response = $client.PostAsync($shortEndpoint, $form).GetAwaiter().GetResult()
        $responseText = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        if (-not $response.IsSuccessStatusCode) {
            throw "Short-link service returned HTTP $([int]$response.StatusCode)."
        }

        try {
            $payload = $responseText | ConvertFrom-Json
        } catch {
            throw 'Short-link service returned invalid JSON.'
        }

        if ([int]$payload.Code -ne 1 -or [string]::IsNullOrWhiteSpace([string]$payload.ShortUrl)) {
            throw 'Short-link service rejected the request.'
        }
        $shortUrl = [string]$payload.ShortUrl
    } finally {
        if ($null -ne $response) {
            $response.Dispose()
        }
        $form.Dispose()
        $client.Dispose()
    }
}

[pscustomobject]@{
    LongUrl = $longUrl
    ShortUrl = $shortUrl
}
