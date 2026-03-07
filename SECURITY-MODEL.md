# Security Model

本文明确区分三层控制，避免把软提示词误当硬防护。

## 1. Hard Control（OpenClaw 官方硬机制）

这些是平台强制执行：

1. `exec-approvals.json`
2. sandbox（`mode` / `scope` / `workspaceAccess`）
3. tools policy（`tools.profile` + `allow/deny`）
4. `tools.elevated.enabled`
5. memory search provider/fallback

## 2. Engineering Control（本 capability pack 工程实现）

这些基于官方机制，由仓库脚本与配置落地：

1. `config/openclaw.patch.json` 提供安全基线
2. `scripts/*.ps1` 提供安装/更新/验证/回滚/dry-run
3. `scripts/*.sh` 提供 Linux sandbox 兼容执行路径
4. `scripts/Sync-WorkspacePath.ps1` 处理外部路径导入，规避 path-escape
5. workspace 模板约束 memory 生命周期与压缩规则
6. hooks 默认启用：`boot-md` / `bootstrap-extra-files` / `session-memory`

## 3. Prompt Control（软约束）

这些只在提示词层生效，不等价于平台硬防护：

1. 高风险动作前解释风险并请求确认
2. 大规模改动前给出 plan-first / dry-run
3. 论文解释时标注“原文含义”与“推断解释”边界

## 4. 高风险动作处置顺序

1. 先用 hard control 限权
2. 再用 engineering control 固化流程
3. 最后用 prompt control 做行为提醒

## 5. Sandbox 路径边界（重点）

- sandbox 默认不能直接读取宿主 `C:\...` 路径。
- 正确流程：先导入到 workspace，再在 sandbox 中读写。
- 导入脚本：`scripts/Sync-WorkspacePath.ps1`
- 导入执行口令：`APPROVE_WORKSPACE_IMPORT`

## 6. 本地 memory 要求

1. 默认 `provider=local`
2. 默认 `fallback=none`
3. 不默认回退到云端 embedding
4. memory 文件中禁止写入 secrets

## 7. 插件与扩展边界

1. Feishu/Discord 为当前可选基线
2. QQ/微信/企业微信仅做扩展蓝图，不默认启用
3. 新插件必须经过最小权限审查并显式开启
