# Install Guide (Windows + PowerShell)

## 1) Prerequisites

1. OpenClaw CLI is installed and available:
   - `openclaw.cmd --version`
2. You can write to:
   - `%USERPROFILE%\.openclaw`
   - `%USERPROFILE%\.openclaw\workspace`

## 2) Define common paths

```powershell
$RepoRoot = "<YOUR_REPO_PATH>\\openclaw-capability-pack"
$OpenClawHome = "$env:USERPROFILE\\.openclaw"
$Workspace = "$OpenClawHome\\workspace"
```

## 3) One-shot install

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
cd $RepoRoot

.\scripts\Install-OpenClawCapabilityPack.ps1 `
  -OpenClawHome $OpenClawHome `
  -Workspace $Workspace `
  -Force
```

The installer syncs custom skills to both:

- `%USERPROFILE%\.openclaw\skills\...` (managed copy)
- `%USERPROFILE%\.openclaw\workspace\skills\...` (sandbox-readable copy, preferred by OpenClaw)

It also syncs bridge scripts to:

- `%USERPROFILE%\.openclaw\workspace\scripts\...`

## 4) Verify

```powershell
cd $RepoRoot
.\scripts\Verify-OpenClawCapabilityPack.ps1 `
  -OpenClawHome $OpenClawHome `
  -Workspace $Workspace
```

## 5) Dry-run (no mutation)

```powershell
cd $RepoRoot
.\scripts\Install-OpenClawCapabilityPack.ps1 `
  -OpenClawHome $OpenClawHome `
  -Workspace $Workspace `
  -Force `
  -DryRun
```

## 6) Update existing setup

```powershell
cd $RepoRoot
.\scripts\Update-OpenClawCapabilityPack.ps1 `
  -OpenClawHome $OpenClawHome `
  -Workspace $Workspace
```

## 7) Optional channels patch

1. Edit `config/openclaw.channels.optional.json` placeholders.
2. Apply:

```powershell
cd $RepoRoot
.\scripts\Apply-OpenClawPatch.ps1 `
  -OpenClawHome $OpenClawHome `
  -PatchPath ".\\config\\openclaw.channels.optional.json"
```

Enable sensitive `feishu_perm` only when needed:

```powershell
cd $RepoRoot
.\scripts\Apply-OpenClawPatch.ps1 `
  -OpenClawHome $OpenClawHome `
  -PatchPath ".\\config\\openclaw.feishu.perm.optional.json"
```

## 8) Feishu group admin bridge (optional)

Inside OpenClaw Linux sandbox, prefer `sh` scripts (avoid `powershell not found`):

```sh
sh ./scripts/Run-FeishuGroupFlow.sh \
  --flow CreateAndAdd \
  --chat-name "Research Group" \
  --owner-id "ou_xxx" \
  --create-user-ids "ou_a,ou_b" \
  --add-member-ids "ou_c,ou_d"
```

Execute after approval:

```sh
sh ./scripts/Run-FeishuGroupFlow.sh \
  --flow CreateAndAdd \
  --chat-name "Research Group" \
  --owner-id "ou_xxx" \
  --create-user-ids "ou_a,ou_b" \
  --add-member-ids "ou_c,ou_d" \
  --execute \
  --approval-text APPROVE_FEISHU_CHAT_ADMIN
```

Add member by phone (ID resolve + add flow):

```sh
sh ./scripts/Run-FeishuGroupFlow.sh \
  --flow AddOnly \
  --chat-id "oc_xxx" \
  --add-member-mobiles "********" \
  --member-id-type open_id
```

Windows host fallback:

```powershell
cd $RepoRoot
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Run-FeishuGroupFlow.ps1 `
  -Flow CreateAndAdd `
  -ChatName "Research Group" `
  -OwnerId "ou_xxx" `
  -CreateUserIds "ou_a","ou_b" `
  -AddMemberIds "ou_c","ou_d" `
  -DryRun
```

Then execute with approval text:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Run-FeishuGroupFlow.ps1 `
  -Flow CreateAndAdd `
  -ChatName "Research Group" `
  -OwnerId "ou_xxx" `
  -CreateUserIds "ou_a","ou_b" `
  -AddMemberIds "ou_c","ou_d" `
  -Execute `
  -ApprovalText APPROVE_FEISHU_CHAT_ADMIN
```

## 9) Daily 22:00 reminder + 07:05 cache prefetch + 07:30 morning digest (optional)

Step 1: create/update the OpenClaw cron jobs:

```powershell
cd $RepoRoot
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Setup-DailyPlanWeatherCron.ps1 `
  -To "REPLACE_WITH_FEISHU_CHAT_ID_OR_OPEN_ID" `
  -Location "中国·成都市双流区" `
  -Timezone "Asia/Shanghai" `
  -Force
```

Step 2: install the Windows scheduled task that pre-builds the local cache:

```powershell
cd $RepoRoot
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-MorningDigestScheduledTask.ps1 `
  -Workspace "$env:USERPROFILE\.openclaw\workspace" `
  -Location "中国·成都市双流区" `
  -WeatherDistrictCode "101270106" `
  -WeatherCityCode "101270101" `
  -Force
```

Step 3: verify the pipeline:

```powershell
cd $RepoRoot
.\scripts\Verify-MorningDigestPipeline.ps1 `
  -OpenClawHome $OpenClawHome `
  -Workspace $Workspace
```

Default behavior:

1. 22:00: remind you to send tomorrow's plan.
2. 22:40: capture your latest plan into `memory/YYYY-MM-DD.md`.
3. 07:05: build `cache\morning-digest\YYYY-MM-DD.json` locally on Windows.
4. 07:30: read only the local cache + plan memory, then send the morning digest.

Weather note:

1. The default weather codes above are for Chengdu Shuangliu.
2. If you deploy to another city, replace `-WeatherDistrictCode` and `-WeatherCityCode`.

Default digest sources:

1. Weather: `weather.com.cn` fixed Chengdu / Shuangliu pages.
2. Football: ESPN scoreboard JSON for La Liga / Premier League / Champions League.
3. International: Xinhua world page.
4. VALORANT / KPL: domestic search results filtered by exact date + tournament whitelist.

## 10) Fix host-path access (`Path escapes sandbox root`)

When user gives `C:\...` paths, import into workspace first:

```powershell
cd $RepoRoot
.\scripts\Sync-WorkspacePath.ps1 `
  -SourcePath "C:\path\to\file-or-folder" `
  -DryRun
```

After approval:

```powershell
.\scripts\Sync-WorkspacePath.ps1 `
  -SourcePath "C:\path\to\file-or-folder" `
  -ApprovalText APPROVE_WORKSPACE_IMPORT
```

## 11) Rollback

```powershell
cd $RepoRoot
.\scripts\Rollback-OpenClawConfig.ps1 -OpenClawHome $OpenClawHome
```

Backups are stored under `%USERPROFILE%\.openclaw\backups\capability-pack`.

## 12) Warning repair shortcut

```powershell
cd $RepoRoot
.\scripts\Fix-ToolsProfileWarnings.ps1 `
  -OpenClawHome $OpenClawHome `
  -Workspace $Workspace
```

## 13) Post-install checks

```powershell
openclaw.cmd skills check
openclaw.cmd sandbox explain --agent dev
openclaw.cmd gateway health
```
