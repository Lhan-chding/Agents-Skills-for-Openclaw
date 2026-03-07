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

For create-group / add-members operations:

```powershell
cd $RepoRoot
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-FeishuChatAdmin.ps1 `
  -Action CreateChat `
  -ChatName "Research Group" `
  -OwnerId "ou_xxx" `
  -UserIds "ou_a","ou_b" `
  -DryRun
```

Then execute with approval text:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-FeishuChatAdmin.ps1 `
  -Action CreateChat `
  -ChatName "Research Group" `
  -OwnerId "ou_xxx" `
  -UserIds "ou_a","ou_b" `
  -ApprovalText APPROVE_FEISHU_CHAT_ADMIN
```

## 9) Rollback

```powershell
cd $RepoRoot
.\scripts\Rollback-OpenClawConfig.ps1 -OpenClawHome $OpenClawHome
```

Backups are stored under `%USERPROFILE%\.openclaw\backups\capability-pack`.

## 10) Warning repair shortcut

```powershell
cd $RepoRoot
.\scripts\Fix-ToolsProfileWarnings.ps1 `
  -OpenClawHome $OpenClawHome `
  -Workspace $Workspace
```

## 11) Post-install checks

```powershell
openclaw.cmd skills check
openclaw.cmd sandbox explain --agent dev
openclaw.cmd gateway health
```
