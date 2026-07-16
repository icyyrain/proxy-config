# Business Groups Self-Hosted Options Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `🏠 自建节点` and `🛟 备用自建节点` as direct choices in the 16 approved business and media policy groups.

**Architecture:** Keep the existing ACL4SSR INI structure and insert the two references into selected `custom_proxy_group` lines only. A focused PowerShell regression test parses group references, enforces the include/exclude scope, and detects reference cycles; a live Subconverter request verifies generated Clash output after publication.

**Tech Stack:** Subconverter INI, PowerShell 5.1, Git, GitHub Raw, sub.v1.mk Subconverter API.

## Global Constraints

- Modify exactly the 16 groups listed in `docs/2026-07-16-business-groups-self-hosted-options-design.md`.
- Put `[]🏠 自建节点` and then `[]🛟 备用自建节点` immediately after `[]🚀 节点选择` where present.
- For `📺 哔哩哔哩`, put both options after `[]🎯 全球直连`; for `🌏 国内媒体`, put them after `[]DIRECT`.
- Do not modify direct, reject, node-filter, region, manual-selection, or self-hosted groups.
- Do not introduce subscription URLs, proxy URIs, UUIDs, passwords, or server credentials.

---

### Task 1: Add a failing scope regression test

**Files:**
- Create: `tests/validate-business-groups.ps1`
- Read: `subconverter.ini`

**Interfaces:**
- Consumes: `subconverter.ini` lines beginning with `custom_proxy_group=`.
- Produces: exit code 0 only when every target group contains both self-hosted references, every excluded group omits them, and the policy-group graph is acyclic.

- [ ] **Step 1: Create the validation script**

Define `$targetGroups` as the 16 approved group names and `$excludedGroups` as `🎯 全球直连`, `🛑 广告拦截`, `🍃 应用净化`, all region groups, `🎥 奈飞节点`, `🚀 手动切换`, and both self-hosted groups. Parse backtick-delimited `[]` references and throw when any assertion fails.

- [ ] **Step 2: Run the test to verify RED**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/validate-business-groups.ps1
```

Expected: non-zero exit with `Target group missing self-hosted options`, because the existing 16 business groups do not yet contain both references.

### Task 2: Update the selected policy groups

**Files:**
- Modify: `subconverter.ini:60-78`
- Test: `tests/validate-business-groups.ps1`

**Interfaces:**
- Consumes: the target and exclusion lists enforced by Task 1.
- Produces: 16 business/media group definitions containing both self-hosted references without creating cycles.

- [ ] **Step 1: Insert both references into the 14 target groups that contain Node Selection**

For each target line containing `[]🚀 节点选择`, replace that segment with:

```text
[]🚀 节点选择`[]🏠 自建节点`[]🛟 备用自建节点
```

- [ ] **Step 2: Update Bilibili and Domestic Media separately**

Change the start of the Bilibili options to:

```text
custom_proxy_group=📺 哔哩哔哩`select`[]🎯 全球直连`[]🏠 自建节点`[]🛟 备用自建节点
```

Keep its Taiwan and Hong Kong options unchanged after these additions.

Change the start of the Domestic Media options to:

```text
custom_proxy_group=🌏 国内媒体`select`[]DIRECT`[]🏠 自建节点`[]🛟 备用自建节点
```

Keep its region and manual-selection options unchanged after these additions.

- [ ] **Step 3: Run the regression test to verify GREEN**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/validate-business-groups.ps1
```

Expected: exit 0 with `16 target groups validated; exclusions clean; graph acyclic`.

- [ ] **Step 4: Commit the tested configuration**

```powershell
git add subconverter.ini tests/validate-business-groups.ps1
git commit -m "Add self-hosted choices to business groups"
```

### Task 3: Update documentation and publish

**Files:**
- Modify: `README.md`
- Existing: `docs/2026-07-16-business-groups-self-hosted-options-design.md`
- Existing: `docs/superpowers/plans/2026-07-16-business-groups-self-hosted-options.md`

**Interfaces:**
- Consumes: the verified INI and design.
- Produces: published `main` whose stable Raw URL serves the updated content.

- [ ] **Step 1: Document business-group behavior**

Add one README bullet stating that the 16 business/media groups can directly select either self-hosted group.

- [ ] **Step 2: Commit documentation**

```powershell
git add README.md docs
git commit -m "Document business group self-hosted choices"
```

- [ ] **Step 3: Run local verification**

Run the regression test, `git diff --check origin/main...HEAD`, and a credential scan. Expected: test passes, no whitespace errors, and zero credential/proxy-URI matches.

- [ ] **Step 4: Push main**

```powershell
git push origin main
```

Expected: remote `main` advances to the local HEAD.

### Task 4: Verify Raw and live Subconverter output

**Files:**
- Verify: `subconverter.ini`
- Verify URL: `https://raw.githubusercontent.com/icyyrain/proxy-config/main/subconverter.ini`

**Interfaces:**
- Consumes: published Raw INI and two non-secret synthetic Shadowsocks nodes named `MochaKK-US-main` and `MochaKK-US-hysteria`.
- Produces: evidence that publication and generated Clash behavior match the approved design.

- [ ] **Step 1: Compare Raw bytes with the local file**

Download the Raw URL with a cache-busting query parameter and compare SHA-256 hashes. Expected: identical hashes.

- [ ] **Step 2: Generate a synthetic Clash subscription**

Call the sub.v1.mk API with the two fake nodes and the stable Raw INI URL. Expected: HTTP 200.

- [ ] **Step 3: Inspect generated groups and rules**

Assert:

- both self-hosted groups contain both fake nodes;
- all 16 target groups contain `🏠 自建节点` and `🛟 备用自建节点`;
- excluded groups do not contain either reference;
- Pixiv still has 11 expected options and all four Pixiv domain rules.

- [ ] **Step 4: Confirm repository state**

Run `git status --short --branch`. Expected: `main` tracks `origin/main` with no uncommitted or unpushed changes.
