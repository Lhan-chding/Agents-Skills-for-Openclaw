# Install Guide (Windows + PowerShell)

## 1) Prerequisites

- OpenClaw 已安装并可执行 `openclaw.cmd --version`
- 具备本地写权限：
  - `%USERPROFILE%\.openclaw`
  - `%USERPROFILE%\.openclaw\workspace`

## 2) One-shot install

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
cd "c:\Users\LHan1\Desktop\Paper learning\PDE-Net-PDE-Net"

.\openclaw-capability-pack\scripts\Install-OpenClawCapabilityPack.ps1 -Force
.\openclaw-capability-pack\scripts\Verify-OpenClawCapabilityPack.ps1
```

## 3) Dry run (no mutation)

```powershell
.\openclaw-capability-pack\scripts\Install-OpenClawCapabilityPack.ps1 -Force -DryRun
```

## 4) Update existing setup

```powershell
.\openclaw-capability-pack\scripts\Update-OpenClawCapabilityPack.ps1
.\openclaw-capability-pack\scripts\Verify-OpenClawCapabilityPack.ps1
```

## 5) Optional channels patch

1. 先替换 `config/openclaw.channels.optional.json` 中的占位符。  
2. 再执行：

```powershell
.\openclaw-capability-pack\scripts\Apply-OpenClawPatch.ps1 `
  -PatchPath ".\openclaw-capability-pack\config\openclaw.channels.optional.json"
```

## 6) Rollback

```powershell
.\openclaw-capability-pack\scripts\Rollback-OpenClawConfig.ps1
```

脚本默认从 `%USERPROFILE%\.openclaw\backups\capability-pack` 选最近备份恢复。

## 7) Warning repair shortcut

```powershell
.\openclaw-capability-pack\scripts\Fix-ToolsProfileWarnings.ps1
.\openclaw-capability-pack\scripts\Verify-OpenClawCapabilityPack.ps1
```

## 8) Post-install checks

- 重启 OpenClaw gateway
- `openclaw.cmd skills check`
- `openclaw.cmd sandbox explain --agent dev`
- `openclaw.cmd security audit --json`
