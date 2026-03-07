# OpenClaw Capability Pack v2

一个面向长期使用的 OpenClaw 本地能力包，目标是让 assistant 在真实工作流里做到：

1. 安全优先
2. 研究优先
3. 本地优先
4. 可维护、可回滚

核心能力：

1. 代码协作（research-first secure coding）
2. 论文阅读与公式精讲（paper tutor）
3. 写作与飞书协作（writing copilot）
4. 本地记忆压缩与归档（memory curator）
5. 定时提醒与渠道推送（cron + channels）

English summary: A local-first OpenClaw capability bundle with hardened config, production-oriented skills, PowerShell automation, and clear validation/rollback workflows.

## 1. v2 解决的问题

1. 清理了当前模型路线下常见 warning（尤其是 `coding` profile 中 `apply_patch/image/cron` unknown entries）。
2. 保留“默认保守、dev 可写但审慎”的安全分层。
3. 固化本地 memory 策略：`provider=local`、`fallback=none`。
4. 提供一键安装、更新、验证、回滚脚本，不依赖手工改 JSON。
5. 补齐开源仓库治理文件和 docs。

## 2. 快速开始（推荐）

### 2.1 前置条件

1. 已安装 OpenClaw CLI（可运行 `openclaw.cmd --version`）。
2. 在 Windows PowerShell 执行。
3. 本地有本仓库目录。

### 2.2 设定通用路径变量

```powershell
$RepoRoot = "<YOUR_REPO_PATH>\\openclaw-capability-pack"
$OpenClawHome = "$env:USERPROFILE\\.openclaw"
$Workspace = "$OpenClawHome\\workspace"
```

### 2.3 安装

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
cd $RepoRoot

.\scripts\Install-OpenClawCapabilityPack.ps1 `
  -OpenClawHome $OpenClawHome `
  -Workspace $Workspace `
  -Force
```

### 2.4 验证

```powershell
.\scripts\Verify-OpenClawCapabilityPack.ps1 `
  -OpenClawHome $OpenClawHome `
  -Workspace $Workspace

openclaw.cmd config validate
openclaw.cmd skills check
```

### 2.5 仅预演（不落盘）

```powershell
.\scripts\Install-OpenClawCapabilityPack.ps1 `
  -OpenClawHome $OpenClawHome `
  -Workspace $Workspace `
  -Force `
  -DryRun
```

## 3. 控制分层（必须区分）

### `hard-control`（官方强制机制）

1. `exec-approvals.json`
2. sandbox（`workspaceAccess` / `mode` / `scope`）
3. tools policy（`profile + allow/deny`）
4. memory search provider/fallback

### `engineering-control`（本仓库工程实现）

1. `config/openclaw.patch.json` 安全基线
2. PowerShell 自动化脚本（安装/更新/验证/回滚）
3. workspace 模板（`AGENTS.md`/`TOOLS.md`/`MEMORY.md`/`BOOT.md`）
4. hooks 组合（`boot-md`、`bootstrap-extra-files`、`session-memory`）

### `prompt-control`（软约束，不是硬防护）

1. 高风险动作前先确认
2. 任何代码文件修改前先申请并等待批准
3. 写作默认“修改建议 + 可直接粘贴版本”
4. 论文解释显式标注“原文/解释/推断”

## 4. 五个 Skills

| Skill | 作用 | 典型触发 |
| --- | --- | --- |
| `research-first-secure-coding` | 研究优先 + 安全工程 | 设计/实现/重构/审查 + auth/secrets/shell/db/deploy |
| `paper-reading-formula-tutor` | 论文精读 + 推导教学 | 章节总结、逐符号解释、逐步推导、离散化/loss/边界条件 |
| `writing-feishu-copilot` | 文档协作与改写 | “修改建议 + 可直接粘贴版本”、术语统一、结构整理 |
| `feishu-chat-admin-bridge` | 飞书群管理桥接 | 建群/拉人等需要调用飞书 Open API 的场景 |
| `memory-curator` | 本地记忆维护 | 日记忆压缩、长期记忆升格、冲突标注 |

## 5. 常用命令（按场景）

### 5.1 升级（覆盖安装）

```powershell
cd $RepoRoot
.\scripts\Update-OpenClawCapabilityPack.ps1 `
  -OpenClawHome $OpenClawHome `
  -Workspace $Workspace
```

### 5.2 快速修复 warning（配置+审批）

```powershell
cd $RepoRoot
.\scripts\Fix-ToolsProfileWarnings.ps1 `
  -OpenClawHome $OpenClawHome `
  -Workspace $Workspace
```

### 5.3 回滚

```powershell
cd $RepoRoot
.\scripts\Rollback-OpenClawConfig.ps1 -OpenClawHome $OpenClawHome
```

### 5.4 记忆压缩

```powershell
cd $RepoRoot
.\scripts\Compress-Memory.ps1 -Workspace $Workspace -OlderThanDays 7
```

## 6. Feishu / Discord / Cron（可选）

默认能力包不强制你立即启用所有渠道。

启用可选渠道时：

1. 先编辑 `config/openclaw.channels.optional.json` 的占位符。
2. 再应用补丁：

```powershell
cd $RepoRoot
.\scripts\Apply-OpenClawPatch.ps1 `
  -OpenClawHome $OpenClawHome `
  -PatchPath ".\\config\\openclaw.channels.optional.json"
```

Cron 示例见：`config/cron-jobs.examples.md`。

### 6.1 Feishu 群管理（建群/拉人）注意事项

1. OpenClaw 当前内置 `feishu_chat` 工具是读操作边界（群信息、群成员查询），不是完整群管理工具。
2. 如果你需要“建群/拉人”，请使用：
   - `scripts/Invoke-FeishuChatAdmin.ps1`
   - `skills/feishu-chat-admin-bridge/SKILL.md`
3. 安全流程：
   - 先 `-DryRun` 预演
   - 再显式审批执行（`-ApprovalText APPROVE_FEISHU_CHAT_ADMIN`）
4. 需要有效的 `FEISHU_APP_ID` / `FEISHU_APP_SECRET`，并在飞书开放平台授予对应 IM scopes。
5. `feishu_perm` 属于敏感权限工具，默认不启用；需要时再应用 `config/openclaw.feishu.perm.optional.json`。

## 7. 验收标准（建议逐条检查）

1. 验证脚本显示 `All required checks passed.`  
2. `openclaw.cmd config validate` 成功。  
3. `openclaw.cmd skills check` 中 4 个目标 skill 都可用。  
4. `openclaw.cmd sandbox explain --agent dev` 显示 dev 可写且受限。  
5. 新日志时间窗口内不再出现 `tools.profile (coding) allowlist contains unknown entries ...`。  

## 8. 目录结构

```text
openclaw-capability-pack/
  config/
  scripts/
  skills/
  workspace-templates/
  docs/
  README.md
  INSTALL.md
  SECURITY-MODEL.md
  LICENSE
  CONTRIBUTING.md
  SECURITY.md
  CHANGELOG.md
  CODE_OF_CONDUCT.md
  CITATION.cff
```

## 9. 故障排查（简版）

### Q1: 安装后 skill 没加载

```powershell
openclaw.cmd skills check
```

确认 `research-first-secure-coding / paper-reading-formula-tutor / writing-feishu-copilot / memory-curator` 在可用列表。

### Q2: 仍看到历史 warning

先重启 gateway，再看“最近时间窗口”的日志。历史旧日志不代表当前配置仍有问题。

### Q3: 想先确保不改动再执行

所有主脚本支持 `-DryRun`，先预演再落盘。

### Q4: 飞书里提示“无法访问技能文件 / 无法执行 feishu-perm 建群拉人”

先区分三件事：

1. `feishu-perm` 是文档/云盘权限工具，不是群管理工具。
2. 内置 `feishu_chat` 默认是读操作（群信息、成员查询），不是建群/拉人全功能。
3. 建群/拉人要走桥接脚本：`scripts/Invoke-FeishuChatAdmin.ps1`（先 `-DryRun`，后审批执行）。

再检查配置是否生效：

```powershell
openclaw.cmd sandbox explain --agent dev
openclaw.cmd skills check
```

确认 `dev` allowlist 包含 `feishu_chat`、`feishu_doc`、`feishu_app_scopes` 等工具。
若你要启用 `feishu_perm`，再额外应用：

```powershell
.\scripts\Apply-OpenClawPatch.ps1 `
  -PatchPath ".\\config\\openclaw.feishu.perm.optional.json"
```

## 10. 许可证

Apache-2.0，见 [LICENSE](./LICENSE)。
