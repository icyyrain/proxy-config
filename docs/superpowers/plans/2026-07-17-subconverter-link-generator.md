# Subconverter Link Generator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a parameterized PowerShell generator that reproduces the current sub.v1.mk Clash long link and creates a v1.mk short link only when explicitly requested.

**Architecture:** A single script merges command-line overrides, a Git-ignored local PSD1 file, and safe built-in defaults. A standalone PowerShell regression test uses fake URLs plus a loopback HTTP stub, while the real local defaults are recovered from the existing Merlin Clash short link without printing secrets.

**Tech Stack:** Windows PowerShell 5.1, PSD1 data files, System.Net.Http multipart requests, Git, Merlin Clash dbus, Subconverter HTTP API.

## Global Constraints

- Never place real subscription URLs or generated long links in Git-tracked files or command output.
- Default execution generates a long link only; `-CreateShort` is required for a short link.
- Merge precedence is command-line parameter, then local PSD1, then safe built-in default.
- Combine 3x-ui first and airport second with `|`, then URL-encode the complete source value.
- Preserve the webpage defaults: `insert=false`, `emoji=true`, `list=false`, `tfo=false`, `expand=true`, `scv=false`, `fdn=false`, `new_name=true`, and `diyua=ShadowRocket`.
- Tests use only `example.invalid` URLs and a loopback short-link server.

---

### Task 1: Add the failing regression test

**Files:**
- Create: `tests/fixtures/subscription.test.psd1`
- Create: `tests/validate-link-generator.ps1`
- Expected later: `scripts/New-SubconverterLink.ps1`

**Interfaces:**
- Consumes: a PSD1 configuration path and command-line overrides.
- Produces: assertions for query values, encoding, precedence, automatic rename rules, default no-network behavior, and multipart short-link behavior.

- [ ] **Step 1: Create a fake configuration fixture**

```powershell
@{
    ThreeXuiSubscriptionUrl = 'https://example.invalid/3x-ui?client=test'
    AirportSubscriptionUrl  = 'https://airport.example.invalid/sub?token=fake'
    ClientName              = 'icyy'
    SubscriptionName        = '摩卡空港 MochaKuko'
    RemoteConfigUrl         = 'https://raw.githubusercontent.com/icyyrain/proxy-config/main/subconverter.ini'
    BackendUrl              = 'https://api.v1.mk'
    ShortUrlEndpoint        = 'http://127.0.0.1:9/short'
    Udp                     = $true
    Xudp                    = $true
    Emoji                   = $true
    ExpandRules             = $true
    ClashNewFieldName       = $true
    UserAgent               = 'ShadowRocket'
}
```

- [ ] **Step 2: Create the validation script**

The test must:

1. invoke `scripts/New-SubconverterLink.ps1 -ConfigPath <fixture>`;
2. parse the query into a hashtable using `[Uri]::UnescapeDataString()`;
3. assert the exact source join, filename, `-icyy$@`, booleans, config, and UA;
4. rerun with friend overrides and confirm the airport URL remains unchanged;
5. confirm default execution succeeds even though the fixture short endpoint is unreachable;
6. start a loopback `TcpListener`, run with `-CreateShort -ShortKey test-key`, return `{"Code":1,"ShortUrl":"https://v1.mk/test-key"}`, and assert multipart fields contain the Base64 long URL and `shortKey`.

- [ ] **Step 3: Run RED**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\validate-link-generator.ps1
```

Expected: non-zero exit stating that `scripts/New-SubconverterLink.ps1` does not exist.

### Task 2: Implement the generator

**Files:**
- Create: `scripts/New-SubconverterLink.ps1`
- Test: `tests/validate-link-generator.ps1`

**Interfaces:**
- Consumes: the parameters listed in the approved design and an optional PSD1 file.
- Produces: `[pscustomobject]@{ LongUrl = <string>; ShortUrl = <string-or-null> }`.

- [ ] **Step 1: Implement config precedence**

Load `ConfigPath` with `Import-PowerShellDataFile` when it exists. Resolve every value with:

```powershell
if ($bound.ContainsKey($Name)) { $bound[$Name] }
elseif ($localConfig.ContainsKey($Name)) { $localConfig[$Name] }
else { $BuiltInDefault }
```

Use nullable booleans so `-Udp:$false` and `-Xudp:$false` override true defaults.

- [ ] **Step 2: Validate inputs**

Use `[Uri]::TryCreate(..., [UriKind]::Absolute, ...)` and require HTTP/HTTPS for both subscriptions, remote config, backend, and short endpoint. Reject empty client name when no explicit rename rule exists, and reject a `ShortKey` containing `http`.

- [ ] **Step 3: Generate the long link**

Build an ordered query with the exact webpage keys:

```text
target,url,insert,config,filename,rename,emoji,list,xudp,udp,tfo,expand,scv,fdn,new_name,diyua
```

Encode each value with `[Uri]::EscapeDataString()`; lowercase all booleans.

- [ ] **Step 4: Implement opt-in short links**

When `-CreateShort` is present:

```powershell
Add-Type -AssemblyName System.Net.Http
$base64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($longUrl))
$form = [System.Net.Http.MultipartFormDataContent]::new()
$form.Add([System.Net.Http.StringContent]::new($base64), 'longUrl')
```

Add `shortKey` when provided, POST with `HttpClient`, parse JSON, and require `Code -eq 1` plus non-empty `ShortUrl`.

- [ ] **Step 5: Run GREEN**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\validate-link-generator.ps1
```

Expected: `Link generator validation passed` with exit code 0.

- [ ] **Step 6: Commit the tested implementation**

```powershell
git add scripts/New-SubconverterLink.ps1 tests
git commit -m "Add Subconverter link generator"
```

### Task 3: Add safe defaults and documentation

**Files:**
- Create: `.gitignore`
- Create: `config/subscription.example.psd1`
- Create locally only: `config/subscription.local.psd1`
- Modify: `README.md`

**Interfaces:**
- Consumes: the generator from Task 2 and the router's current converted subscription.
- Produces: a one-command personal workflow without committing secrets.

- [ ] **Step 1: Ignore the private file before creating it**

```gitignore
config/subscription.local.psd1
```

Run `git check-ignore config/subscription.local.psd1`; expected: the path is ignored.

- [ ] **Step 2: Add the public example**

Use the same keys as the test fixture, but only `example.invalid` source URLs.

- [ ] **Step 3: Recover real defaults without printing them**

Read `merlinclash_links` over SSH, Base64-decode the stored v1.mk short URL, follow its single redirect, and parse the final `api.v1.mk/sub` query. Require:

- target `clash`;
- exactly two source URLs;
- one source hosted at the configured 3x-ui VPS domain;
- one remaining airport source;
- non-empty filename, rename, config, UDP, and XUDP fields.

Write only those parsed values to `config/subscription.local.psd1` after the ignore check.

- [ ] **Step 4: Document usage**

Add README examples for:

```powershell
.\scripts\New-SubconverterLink.ps1
.\scripts\New-SubconverterLink.ps1 -CreateShort
.\scripts\New-SubconverterLink.ps1 -ThreeXuiSubscriptionUrl '朋友地址' -ClientName 'friend' -SubscriptionName '朋友订阅'
```

State that returned long links and short links are credentials.

- [ ] **Step 5: Verify and commit public files only**

Run:

```powershell
git status --short --ignored
git diff --check
git ls-files config/subscription.local.psd1
```

Expected: local PSD1 is ignored and absent from `git ls-files`.

Commit:

```powershell
git add .gitignore config/subscription.example.psd1 README.md docs
git commit -m "Document local link generator defaults"
```

### Task 4: Verify the real workflow and publish

**Files:**
- Verify: `scripts/New-SubconverterLink.ps1`
- Verify locally: `config/subscription.local.psd1`

**Interfaces:**
- Consumes: the real ignored local defaults.
- Produces: evidence that the generated link works without exposing it.

- [ ] **Step 1: Generate the real long link**

Invoke the script without parameters. Assert `LongUrl` is non-empty and `ShortUrl` is empty. Do not print the object.

- [ ] **Step 2: Test the generated Subconverter URL**

Request the generated long URL and report only HTTP status and presence of expected policy group names. Expected: HTTP 200 and both self-hosted groups present.

- [ ] **Step 3: Run security and regression checks**

Run both validation scripts, scan tracked files and `origin/main..HEAD` for known credentials, UUIDs, proxy URIs, and real subscription hosts. Expected: zero findings.

- [ ] **Step 4: Push main and verify clean state**

```powershell
git push origin main
git status --short --branch
```

Expected: `## main...origin/main` with the ignored local PSD1 omitted from normal status.
