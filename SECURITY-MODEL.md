# Security Model

本文件区分三类控制，避免把软提示词误当成硬防护。

## 1. `hard-control`（OpenClaw 官方机制）

这些机制由平台运行时强制执行：

- `exec-approvals.json`
- sandbox（`mode/scope/workspaceAccess`）
- tool policy（`tools.profile` + allow/deny）
- `tools.elevated.enabled`
- memory search provider/fallback

## 2. `engineering-control`（本能力包实现）

这些机制建立在官方能力上，由本仓库脚本/配置持续维护：

- `config/openclaw.patch.json` 提供安全基线
- `scripts/*.ps1` 提供安装、更新、验证、回滚、dry-run
- workspace 模板约束 memory 生命周期
- hooks 默认开启 `boot-md`、`bootstrap-extra-files`、`session-memory`

## 3. `prompt-control`（软约束）

这些只在提示词层生效，不等价于平台强制：

- 执行命令前先确认
- 代码或文档大改前先确认
- 论文解释中标注原文与推断边界

## 4. 高风险动作处理

优先级顺序：

1. 先用 `hard-control` 限制能力面。
2. 再用 `engineering-control` 做默认策略和自动化校验。
3. 最后用 `prompt-control` 作为补充提醒。

## 5. 本地 memory 安全要求

- 默认 `provider=local`
- 默认 `fallback=none`
- 禁止把 memory embedding 索引默认回退到云端
- 禁止在 memory 文件中写入 secrets

## 6. 供应链与插件边界

- Feishu/Discord 是当前基线可选插件。
- QQ/微信/企业微信只保留适配蓝图，不默认启用。
- 任何新增插件必须经过最小权限审查与显式启用。
