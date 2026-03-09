# OpenClaw Capability Pack v2

一个面向 OpenClaw 的本地能力包，目标是：

1. 安全优先的代码协作（research-first secure coding）
2. 论文阅读与公式精讲
3. 写作与飞书协作
4. 本地记忆沉淀与压缩
5. 飞书群管理桥接（建群/拉人脚本）
6. 定时提醒与自动总结（cron）

本仓库不是通用 SDK，而是可直接用于 OpenClaw 的 skills + scripts + config bundle。

## 1. 能力总览

包含 5 个核心 skill：

1. `research-first-secure-coding`
2. `paper-reading-formula-tutor`
3. `writing-feishu-copilot`
4. `feishu-chat-admin-bridge`
5. `memory-curator`

核心脚本：

1. `scripts/Install-OpenClawCapabilityPack.ps1`
2. `scripts/Update-OpenClawCapabilityPack.ps1`
3. `scripts/Verify-OpenClawCapabilityPack.ps1`
4. `scripts/Build-MorningDigestCache.ps1`
5. `scripts/Install-MorningDigestScheduledTask.ps1`
6. `scripts/Verify-MorningDigestPipeline.ps1`
7. `scripts/Invoke-FeishuChatAdmin.ps1` / `.sh`
8. `scripts/Run-FeishuGroupFlow.ps1` / `.sh`
9. `scripts/Setup-DailyPlanWeatherCron.ps1`
10. `scripts/Sync-WorkspacePath.ps1`

## 2. 目录结构

```text
openclaw-capability-pack/
  config/
  docs/
  scripts/
  skills/
  workspace-templates/
  README.md
  INSTALL.md
  SECURITY-MODEL.md
```

## 3. 快速安装（Windows + PowerShell）

```powershell
$RepoRoot = "<YOUR_PATH>\\openclaw-capability-pack"
$OpenClawHome = "$env:USERPROFILE\\.openclaw"
$Workspace = "$OpenClawHome\\workspace"

Set-ExecutionPolicy -Scope Process Bypass -Force
cd $RepoRoot

.\scripts\Install-OpenClawCapabilityPack.ps1 `
  -OpenClawHome $OpenClawHome `
  -Workspace $Workspace `
  -Force
```

验证：

```powershell
.\scripts\Verify-OpenClawCapabilityPack.ps1 `
  -OpenClawHome $OpenClawHome `
  -Workspace $Workspace

openclaw.cmd skills check
openclaw.cmd cron list
```

## 4. 每日提醒与晨间简报

你要的流程：

1. 每晚 22:00 提醒你提交次日计划
2. 每天 07:05 在 Windows 本机预抓取天气与昨日日报，写入本地缓存
3. 每早 07:30 由 OpenClaw 只读取本地缓存和计划记忆，然后发送“今日安排 + 天气 + 是否带伞 + 昨日日报”

先创建 OpenClaw cron：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Setup-DailyPlanWeatherCron.ps1 `
  -To "<FEISHU_OPEN_ID_OR_CHAT_ID>" `
  -Location "中国·成都市双流区" `
  -Timezone "Asia/Shanghai" `
  -Force
```

再安装本机 07:05 预抓取计划任务：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-MorningDigestScheduledTask.ps1 `
  -Workspace "$env:USERPROFILE\.openclaw\workspace" `
  -Location "中国·成都市双流区" `
  -Force
```

流程说明：

1. 22:00 任务名：`daily-plan-reminder-2200`
2. 22:40 任务名：`daily-plan-capture-2240`
3. 07:05 Windows 计划任务：`OpenClaw-MorningDigestCache-0705`
4. 07:30 任务名：`daily-plan-weather-summary-0730`
5. 本地缓存路径：`~\.openclaw\workspace\cache\morning-digest\YYYY-MM-DD.json`
6. 07:30 不再联网抓取，只读本地缓存，避免把 `agent + web_fetch + LLM` 塞进同一条 cron

数据策略：

1. 天气：`weather.com.cn` 成都 / 双流固定页
2. 国际新闻：`news.cn/world/`
3. 足球：优先 ESPN 公共 scoreboard JSON，直接取西甲 / 英超 / 欧冠赛果；有进球事件时附带进球人和时间
4. 无畏契约 / KPL：使用国内稳定新闻检索页，按“官方级赛事关键词白名单 + 昨日日期”过滤
5. 缺项统一写 `暂无可核验更新`

查看任务：

```powershell
openclaw.cmd cron list
openclaw.cmd cron list --json
```

手动触发测试：

```powershell
openclaw.cmd cron run <JOB_ID>
Get-Content "$env:USERPROFILE\.openclaw\workspace\cache\morning-digest\$(Get-Date -Format 'yyyy-MM-dd').json"
```

## 5. 飞书群管理（建群/拉人）

OpenClaw 当前内置 `feishu_chat` 以查询为主。建群/拉人通过桥接脚本完成：

1. `scripts/Invoke-FeishuChatAdmin.ps1` / `.sh`
2. `scripts/Run-FeishuGroupFlow.ps1` / `.sh`

推荐流程：

1. 先 Dry Run
2. 看请求参数是否正确
3. 再执行变更（需审批文本）

变更审批文本：`APPROVE_FEISHU_CHAT_ADMIN`

## 6. 本地记忆策略

已按本地优先设计：

1. `memorySearch.provider = local`
2. `memorySearch.fallback = none`
3. 日记忆：`memory/YYYY-MM-DD.md`
4. 长期记忆：`MEMORY.md`
5. 压缩规则：`memory/COMPRESSION-RULES.md`

## 7. 安全边界（务必区分）

硬机制（平台强制）：

1. OpenClaw approvals
2. sandbox 隔离
3. tools allow/deny

工程实现（本仓库实现）：

1. dry-run first 脚本流程
2. 风险操作审批文本
3. 安装/验证/回滚脚本

软约束（prompt 级）：

1. 先确认再执行
2. 默认最小改动
3. 风险提示后再继续

## 8. 常见问题

1. `Path escapes sandbox root`
- 先用 `Sync-WorkspacePath.ps1` 导入到 workspace，再操作。

2. `/bin/sh: powershell: not found`
- 在 Linux sandbox 里用 `.sh` 脚本，不要直接调用 PowerShell。

3. 飞书返回 `99991672` / `99991663`
- 通常是应用权限 scope 未开通、未发布，或租户策略限制。

4. cron 看不到任务
- 以宿主机 `openclaw.cmd cron list --json` 为准。

## 9. 相关文档

1. [INSTALL.md](./INSTALL.md)
2. [SECURITY-MODEL.md](./SECURITY-MODEL.md)
3. [docs/FEISHU-ENHANCEMENT.md](./docs/FEISHU-ENHANCEMENT.md)
4. [docs/FEISHU-CHAT-ADMIN.md](./docs/FEISHU-CHAT-ADMIN.md)
5. [docs/VALIDATION-AND-RELEASE.md](./docs/VALIDATION-AND-RELEASE.md)

## 10. 许可证

`Apache-2.0`，见 [LICENSE](./LICENSE)
