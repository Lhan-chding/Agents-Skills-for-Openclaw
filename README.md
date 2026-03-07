# OpenClaw Capability Pack v2

面向 OpenClaw 的本地能力包，目标是：

1. 保留 `research-first-secure-coding` 核心工作流
2. 增强论文阅读与公式精讲
3. 增强写作/飞书协作
4. 在安全优先前提下，支持飞书群管理桥接（建群/拉人）
5. 保持本地 memory，不默认上云

## 1. 能力概览

包含 5 个技能：

1. `research-first-secure-coding`
2. `paper-reading-formula-tutor`
3. `writing-feishu-copilot`
4. `feishu-chat-admin-bridge`
5. `memory-curator`

重点新增：

- 飞书群管理桥接支持 `手机号/邮箱 -> 用户ID -> 拉人`
- Linux sandbox 可执行 `.sh` 脚本（不再依赖 `powershell`）
- 工作区路径镜像脚本，解决 `Path escapes sandbox root`

## 2. 安全分层（请区分）

### 2.1 官方硬机制（平台强制）

1. OpenClaw `approvals.exec`
2. sandbox 根路径隔离（workspace root）
3. tools allowlist / denylist

### 2.2 工程实现（本仓库脚本实现）

1. 飞书桥接脚本默认先 dry-run
2. 变更类动作要求 `APPROVE_FEISHU_CHAT_ADMIN`
3. 外部路径导入要求 `APPROVE_WORKSPACE_IMPORT`
4. 安装脚本自动同步 skills + bridge scripts 到 workspace

### 2.3 软约束（prompt 级，不是硬防护）

1. 执行前解释风险
2. 请求用户确认
3. 失败后给可执行修复建议

## 3. 目录结构

```text
openclaw-capability-pack/
  config/
  docs/
  scripts/
    Install-OpenClawCapabilityPack.ps1
    Update-OpenClawCapabilityPack.ps1
    Verify-OpenClawCapabilityPack.ps1
    Invoke-FeishuChatAdmin.ps1
    Run-FeishuGroupFlow.ps1
    Invoke-FeishuChatAdmin.sh
    Run-FeishuGroupFlow.sh
    Sync-WorkspacePath.ps1
  skills/
    research-first-secure-coding/
    paper-reading-formula-tutor/
    writing-feishu-copilot/
    feishu-chat-admin-bridge/
    memory-curator/
  workspace-templates/
  README.md
  INSTALL.md
  SECURITY-MODEL.md
```

## 4. 快速安装（Windows + PowerShell）

```powershell
$RepoRoot = "<YOUR_CAPABILITY_PACK_PATH>"
$OpenClawHome = "$env:USERPROFILE\.openclaw"
$Workspace = "$OpenClawHome\workspace"

Set-ExecutionPolicy -Scope Process Bypass -Force
cd $RepoRoot

.\scripts\Install-OpenClawCapabilityPack.ps1 `
  -OpenClawHome $OpenClawHome `
  -Workspace $Workspace `
  -Force
```

安装后校验：

```powershell
.\scripts\Verify-OpenClawCapabilityPack.ps1 `
  -OpenClawHome $OpenClawHome `
  -Workspace $Workspace

openclaw.cmd skills check
openclaw.cmd sandbox explain --agent dev
openclaw.cmd gateway health
```

## 5. 飞书群管理桥接（重点）

官方 API 参考（主依据）：

1. tenant access token:
   - https://open.feishu.cn/document/server-docs/authentication-management/access-token/tenant_access_token_internal
2. batch_get_id（手机号/邮箱查 ID）:
   - https://open.feishu.cn/document/server-docs/contact-v3/user/batch_get_id
3. chat create / add members:
   - https://open.feishu.cn/document/server-docs/im-v1/chat/create
   - https://open.feishu.cn/document/server-docs/im-v1/chat-members/create

### 5.1 在 Linux sandbox 中执行（推荐）

Dry-run：

```sh
sh ./scripts/Run-FeishuGroupFlow.sh \
  --flow AddOnly \
  --chat-id "oc_xxx" \
  --add-member-mobiles "18780986576" \
  --member-id-type open_id
```

执行（需审批口令）：

```sh
sh ./scripts/Run-FeishuGroupFlow.sh \
  --flow AddOnly \
  --chat-id "oc_xxx" \
  --add-member-mobiles "18780986576" \
  --member-id-type open_id \
  --execute \
  --approval-text APPROVE_FEISHU_CHAT_ADMIN
```

### 5.2 Windows 主机回退

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Run-FeishuGroupFlow.ps1 `
  -Flow AddOnly `
  -ChatId "oc_xxx" `
  -AddMemberMobiles "18780986576" `
  -Execute `
  -ApprovalText APPROVE_FEISHU_CHAT_ADMIN
```

## 6. 彻底规避 Path Escapes 报错

你看到过的报错：

- `Path escapes sandbox root`

根因：

- sandbox 只能访问 workspace 根路径，不能直接访问 `C:\...` 宿主路径。

正确做法：先导入再使用。

Dry-run 导入：

```powershell
.\scripts\Sync-WorkspacePath.ps1 `
  -SourcePath "C:\path\to\file-or-folder" `
  -DryRun
```

审批后导入：

```powershell
.\scripts\Sync-WorkspacePath.ps1 `
  -SourcePath "C:\path\to\file-or-folder" `
  -ApprovalText APPROVE_WORKSPACE_IMPORT
```

然后让 agent 只使用导入后的 workspace 路径。

## 7. Memory 本地化

通过 `config/openclaw.patch.json` 约束：

1. `memorySearch.provider = local`
2. `memorySearch.fallback = none`
3. `session-memory` / `boot-md` / `bootstrap-extra-files` 启用

日记忆模板：

- `workspace-templates/memory/YYYY-MM-DD.template.md`

压缩规则：

- `workspace-templates/memory/COMPRESSION-RULES.md`

## 8. 常见问题

1. `/bin/sh: powershell: not found`
- 用 `.sh` 脚本，不要在 sandbox 内跑 `powershell -File ...`

2. `Path escapes sandbox root`
- 先运行 `Sync-WorkspacePath.ps1` 把外部路径导入 workspace

3. 飞书返回 `99991663`
- 一般是 scope 不足、应用未完成审批或租户策略限制

4. `tenant_access_token` 失败
- 检查 App ID/App Secret 和应用发布状态

## 9. 参考文档

1. OpenClaw Configuration:
   - https://docs.openclaw.ai/guides/configuration
2. OpenClaw Skills:
   - https://docs.openclaw.ai/guides/skills
3. Feishu Open Platform（见第 5 节链接）

## 10. 许可证

`Apache-2.0`，见 [LICENSE](./LICENSE)。
