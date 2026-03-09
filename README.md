# OpenClaw Capability Pack v2

一个面向 OpenClaw 的本地能力包，目标不是做通用 SDK，而是把一套可直接落地的 `skills + scripts + config + workspace templates` 打包好，让你在自己的电脑上稳定复用。

这套能力包当前覆盖 5 个核心方向：

1. 安全优先的代码协作与 research-first engineering
2. 论文阅读、公式精讲、逐步推导解释
3. 写作改写、结构整理、飞书协作
4. 本地记忆沉淀、压缩归档、长期偏好维护
5. 定时提醒、晨报推送、飞书群管理桥接

## 1. 这套仓库能做什么

安装完成后，你会得到：

1. 5 个可加载 skill
   - `research-first-secure-coding`
   - `paper-reading-formula-tutor`
   - `writing-feishu-copilot`
   - `feishu-chat-admin-bridge`
   - `memory-curator`
2. 一套 OpenClaw 安全基线补丁
   - 默认 agent 更保守
   - `dev` agent 可写，但仍要求审批
   - memory 固定为本地 provider，`fallback = none`
3. 一组安装、更新、验证、回滚脚本
4. 一套本地 memory 模板
5. 一条完整的“晚上提醒提交计划 -> 早上推送天气和晨报”的自动化链路

## 2. 适用场景

这套包适合以下用户：

1. 想把 OpenClaw 用作本地长期助手，而不是一次性聊天工具
2. 需要代码协作、论文阅读、文档整理三类能力并存
3. 希望 Feishu 是主要交互入口之一
4. 希望高风险动作先审批
5. 希望记忆保存在本地，不默认走云端 embedding

如果你只想要一个最轻量的聊天配置，这个仓库会比你需要的更重。

## 3. 安装后会落地哪些内容

目录结构如下：

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

安装脚本会把内容同步到两个位置：

1. `~/.openclaw/skills/...`
   - OpenClaw 管理视角下的技能副本
2. `~/.openclaw/workspace/skills/...`
   - sandbox 可直接读取的技能副本

同时还会同步：

1. `~/.openclaw/workspace/scripts/...`
2. `~/.openclaw/workspace/AGENTS.md`
3. `~/.openclaw/workspace/TOOLS.md`
4. `~/.openclaw/workspace/MEMORY.md`
5. `~/.openclaw/workspace/BOOT.md`
6. `~/.openclaw/workspace/memory/YYYY-MM-DD.template.md`
7. `~/.openclaw/workspace/memory/COMPRESSION-RULES.md`

## 4. 部署前准备

在执行本仓库脚本之前，先确认这几件事：

1. 你已经安装 OpenClaw CLI
   - `openclaw.cmd --version`
2. 你至少装好了一个模型 provider plugin
   - 如果启动 gateway 时看到 `No provider plugins found`，先执行：
   - `openclaw.cmd plugins list`
   - `openclaw.cmd plugins install <YOUR_PROVIDER_PLUGIN>`
   - 具体插件名以你本机 `plugins list` 输出为准
3. 你已经至少跑过一次 OpenClaw 基础配置
   - `openclaw.cmd configure`
4. 如果你要用 sandbox，Docker Desktop 已启动
5. 如果你要用 Feishu，飞书应用的 App ID / App Secret 已经准备好，但不要写进仓库

## 5. 第一次部署：最推荐的顺序

### Step 1. 定义通用路径

```powershell
$RepoRoot = "<YOUR_REPO_PATH>\\openclaw-capability-pack"
$OpenClawHome = "$env:USERPROFILE\\.openclaw"
$Workspace = "$OpenClawHome\\workspace"
```

### Step 2. 安装能力包

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
cd $RepoRoot

.\scripts\Install-OpenClawCapabilityPack.ps1 `
  -OpenClawHome $OpenClawHome `
  -Workspace $Workspace `
  -Force
```

这个步骤会完成：

1. 同步 skills
2. 同步 workspace 模板
3. 同步桥接脚本
4. 应用 `config/openclaw.patch.json`
5. 应用 `config/exec-approvals.recommended.json`
6. 创建当天的本地 daily memory 文件

### Step 3. 验证安装结果

```powershell
cd $RepoRoot

.\scripts\Verify-OpenClawCapabilityPack.ps1 `
  -OpenClawHome $OpenClawHome `
  -Workspace $Workspace

openclaw.cmd skills check
openclaw.cmd cron list
```

你应该重点确认：

1. 5 个 skill 都能被识别
2. `openclaw.json` 已切到本仓库的安全基线
3. `exec-approvals.json` 已启用 `ask=always`
4. workspace 里的模板文件和脚本已经存在

### Step 4. 重启 OpenClaw gateway

补丁生效后，建议重启一次 gateway，再进入 UI 或 Feishu 验证。

## 6. 这套包默认启用了什么

安装完成后默认启用：

1. `boot-md`
2. `bootstrap-extra-files`
3. `session-memory`
4. 本地 memory provider
5. `dev` agent 的安全工具基线
6. cron 功能
7. browser 功能
8. Feishu / Discord 插件入口

这里要特别说明三点：

1. “插件入口已启用”不等于“凭证已配置”
2. “skill 已安装”不等于“所有外部服务都已经可用”
3. 飞书、晨报、群管理都还需要你补充本机环境和目标对象

## 7. 每日提醒与晨报怎么部署

这条链路分成两部分：

1. OpenClaw cron 负责提醒、计划捕获、07:30 发消息
2. Windows 计划任务负责 07:05 本地预抓取

这样做的原因是：

1. 抓数据和发消息分离，避免一条 cron 同时做 `联网抓取 + LLM整理`
2. 07:30 晨报只读本地缓存，稳定性更高
3. 即使个别数据源短时失败，也不会把整条晨报拖超时

### Step 1. 创建 OpenClaw cron

```powershell
cd $RepoRoot

powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Setup-DailyPlanWeatherCron.ps1 `
  -To "<FEISHU_OPEN_ID_OR_CHAT_ID>" `
  -Location "<YOUR_LOCATION>" `
  -Timezone "Asia/Shanghai" `
  -Force
```

创建后会得到 3 个正式任务：

1. `daily-plan-reminder-2200`
2. `daily-plan-capture-2240`
3. `daily-plan-weather-summary-0730`

### Step 2. 安装 07:05 本地预抓取任务

```powershell
cd $RepoRoot

powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-MorningDigestScheduledTask.ps1 `
  -Workspace $Workspace `
  -Location "<YOUR_LOCATION>" `
  -WeatherDistrictCode "<DISTRICT_CODE>" `
  -WeatherCityCode "<CITY_CODE>" `
  -Force
```

默认天气代码是成都双流：

1. 区县代码：`101270106`
2. 城市代码：`101270101`

如果你不是成都双流，请改成你自己的天气代码；否则天气部分会继续按默认城市抓取。

### Step 3. 验证晨报链路

```powershell
cd $RepoRoot

.\scripts\Verify-MorningDigestPipeline.ps1 `
  -OpenClawHome $OpenClawHome `
  -Workspace $Workspace
```

晨报本地缓存路径：

```text
~/.openclaw/workspace/cache/morning-digest/YYYY-MM-DD.json
```

### 这条晨报现在包含什么

1. 昨晚提交的次日计划回放
2. 今天天气和带伞建议
3. 无畏契约官方级赛事结果
4. KPL 官方级赛事结果
5. 西甲 / 英超 / 欧冠赛果
6. 国际新闻摘要

### 这条晨报故意不展示什么

1. 内部抓取日志
2. 读取了哪些 memory 文件
3. 哪个网站抓取成功或失败
4. LLM 的内部推理过程

用户看到的应该只是一份最终可读结果，而不是调试信息。

## 8. 飞书怎么接入

如果你只想让 OpenClaw 在本机 UI 里工作，到这里就够了。

如果你要让它在 Feishu 里收发消息，还需要补以下内容：

1. 在飞书开放平台创建应用
2. 打开本仓库需要的 scope
3. 把 App ID / App Secret 放到 OpenClaw gateway 运行环境
4. 按需应用 `config/openclaw.channels.optional.json`

推荐流程：

1. 先在飞书侧开权限
2. 再配置网关环境变量
3. 再打 channels patch
4. 最后重启 gateway

应用 patch：

```powershell
cd $RepoRoot

.\scripts\Apply-OpenClawPatch.ps1 `
  -OpenClawHome $OpenClawHome `
  -PatchPath ".\\config\\openclaw.channels.optional.json"
```

如果你还要启用敏感文档权限操作，再额外应用：

```powershell
cd $RepoRoot

.\scripts\Apply-OpenClawPatch.ps1 `
  -OpenClawHome $OpenClawHome `
  -PatchPath ".\\config\\openclaw.feishu.perm.optional.json"
```

## 9. 飞书建群 / 拉人怎么用

当前 OpenClaw 内置 `feishu_chat` 更偏查询类操作。建群、拉人、批量处理成员，走的是本仓库提供的桥接脚本。

主入口：

1. `scripts/Run-FeishuGroupFlow.sh`
2. `scripts/Run-FeishuGroupFlow.ps1`
3. `scripts/Invoke-FeishuChatAdmin.sh`
4. `scripts/Invoke-FeishuChatAdmin.ps1`

推荐操作顺序：

1. 先 `DryRun`
2. 检查 owner、chat、member 参数
3. 明确审批
4. 再执行真实变更

实际审批口令：

```text
APPROVE_FEISHU_CHAT_ADMIN
```

更详细的命令示例见：

1. [INSTALL.md](./INSTALL.md)
2. [docs/FEISHU-CHAT-ADMIN.md](./docs/FEISHU-CHAT-ADMIN.md)

## 10. 本地记忆是怎么工作的

这套包默认就是“本地优先”。

配置层已经强制：

1. `memorySearch.provider = local`
2. `memorySearch.fallback = none`

文件层约定：

1. 长期记忆：`MEMORY.md`
2. 每日记忆：`memory/YYYY-MM-DD.md`
3. 压缩规则：`memory/COMPRESSION-RULES.md`

这意味着：

1. 你的偏好、项目上下文、计划摘要默认沉淀在本机 markdown
2. 不会默认回退到云端 embedding provider
3. 记忆压缩和归档走本地脚本与模板

## 11. Docker sandbox 为什么以前会有很多 ID

旧配置使用的是 `sandbox.scope = session`，结果是：

1. 每开一个新会话，OpenClaw 都可能新建一个 Docker sandbox
2. 你在 Docker Desktop 里会看到越来越多容器 ID
3. 容器数量会随着会话数膨胀，看起来很乱

现在这套包已经把默认 sandbox scope 调整为：

```text
agent
```

含义是：

1. `main` agent 复用一个 sandbox
2. `dev` agent 复用一个 sandbox
3. 不再按“每个会话”生成一个新容器

这是一个刻意的折中：

1. 好处：容器数量明显减少，日常使用更稳定
2. 代价：同一个 agent 的多个会话共享同一 sandbox

如果你刚从旧配置切过来，建议执行一次 sandbox 重建，让新 scope 生效：

```powershell
openclaw.cmd sandbox recreate --all --force
```

## 12. 安全边界要怎么理解

请明确区分三层控制：

### Hard Control

平台强制执行：

1. `exec-approvals.json`
2. sandbox 边界
3. tools allow / deny
4. memory provider / fallback

### Engineering Control

本仓库脚本和配置实现：

1. 安装 / 更新 / 验证 / 回滚脚本
2. Dry-run first 流程
3. workspace 模板
4. 晨报本地缓存链路
5. 路径导入脚本 `Sync-WorkspacePath.ps1`

### Prompt Control

提示词层约束，不是硬防护：

1. 高风险动作前先解释风险
2. 大改动前先给 plan
3. 读论文时区分“原文含义”和“解释 / 推断”

## 13. 哪些文件不要提交到你的仓库

如果你把这套包二次改造或长期使用，请不要把这些运行时内容提交到 Git 仓库：

1. `~/.openclaw/openclaw.json`
2. `~/.openclaw/exec-approvals.json`
3. `~/.openclaw/workspace/memory/...`
4. `~/.openclaw/workspace/cache/...`
5. 含有 API key / App Secret 的 `.env` 文件
6. 真实的飞书 open_id / chat_id / 手机号批量名单

这个仓库中的所有凭证示例都应该只保留占位符，不应保存真实值。

## 14. 常见问题

### 1. `No provider plugins found`

说明 OpenClaw 还没有可用模型 provider。

处理顺序：

1. `openclaw.cmd plugins list`
2. `openclaw.cmd plugins install <YOUR_PROVIDER_PLUGIN>`
3. `openclaw.cmd configure`
4. 重启 gateway

### 2. `Path escapes sandbox root`

说明你让 agent 直接访问宿主机路径了。

正确做法：

```powershell
.\scripts\Sync-WorkspacePath.ps1 -SourcePath "C:\path\to\file-or-folder" -DryRun
.\scripts\Sync-WorkspacePath.ps1 -SourcePath "C:\path\to\file-or-folder" -ApprovalText APPROVE_WORKSPACE_IMPORT
```

### 3. `/bin/sh: powershell: not found`

说明你在 Linux sandbox 里直接调用了 PowerShell。

处理方式：

1. sandbox 里优先用 `.sh` 脚本
2. 宿主 Windows 才用 `.ps1`

### 4. 飞书返回 `99991663` 或类似权限错误

优先检查：

1. scope 是否已经开通
2. 应用是否已经发布到目标租户
3. 机器人是否在正确租户和正确群里
4. 凭证是否注入到了当前 gateway 运行环境

### 5. 飞书后台明明开了权限，但机器人还是说“不能拉人 / 不能建群”

这通常不是飞书后台没配好，而是“调用入口”没对上。

优先检查：

1. 你当前用的是不是内置 `feishu_chat`
2. 你要做的是不是“写操作”
3. 当前是否已经切到桥接脚本流程

要点：

1. 内置 `feishu_chat` 更偏查询类操作
2. 建群、拉人、批量成员变更要走：
   - `Run-FeishuGroupFlow.sh`
   - `Run-FeishuGroupFlow.ps1`
3. 先 `DryRun`，确认参数和 scope 都正确，再执行真实变更

### 6. 飞书权限明明开了，但 OpenClaw 仍然提示 `FEISHU_APP_ID` / `FEISHU_APP_SECRET` 未设置

这说明权限已经在飞书后台开了，但凭证没有注入当前 gateway 运行环境。

优先检查：

1. 你是不是只在飞书后台开了 scope，但没有把 App ID / App Secret 配给当前 OpenClaw 进程
2. 你是不是在另一个终端、另一个会话或另一台机器里配过环境变量
3. gateway 重启后，这两个变量是否仍然存在

判断原则：

1. “后台权限已开”不等于“当前进程拿得到凭证”
2. 看到这类报错时，先查 gateway 实际运行环境，不要只看开放平台截图

### 7. 飞书消息收不到，或者机器人没有事件回调

优先检查飞书开放平台里的事件订阅模式。

你需要确认：

1. 已启用事件与回调
2. 已启用长连接模式（WebSocket / persistent connection）
3. 目标消息场景对应的事件已勾选
4. gateway 启动日志里能看到 Feishu WebSocket ready

如果这里没配好，机器人可能能启动，但收不到真实消息事件。

### 8. 机器人在私聊能回复，在群里不工作

优先检查：

1. 机器人是否真的被拉进了目标群
2. 群聊里是否按当前规则触发，例如 `@机器人`
3. 目标群是否和应用所在租户一致
4. 当前群会话有没有被 OpenClaw 正确建立 session

常见误判：

1. 机器人权限是开的，但它根本不在那个群里
2. 机器人在群里，但没有被正确 `@`
3. 群里发消息了，但当前应用不是这个租户里的同一个机器人

### 9. 晨报有任务，但没有内容

优先检查：

1. 07:05 计划任务是否存在
2. 当天缓存 JSON 是否已生成
3. 07:30 cron 是否只读缓存，不再联网
4. 你的目标赛事实在昨天是否真的有官方级结果

## 15. 推荐的日常维护命令

更新：

```powershell
.\scripts\Update-OpenClawCapabilityPack.ps1 `
  -OpenClawHome $OpenClawHome `
  -Workspace $Workspace
```

验证：

```powershell
.\scripts\Verify-OpenClawCapabilityPack.ps1 `
  -OpenClawHome $OpenClawHome `
  -Workspace $Workspace
```

回滚：

```powershell
.\scripts\Rollback-OpenClawConfig.ps1 -OpenClawHome $OpenClawHome
```

修 warning：

```powershell
.\scripts\Fix-ToolsProfileWarnings.ps1 `
  -OpenClawHome $OpenClawHome `
  -Workspace $Workspace
```

## 16. 进一步阅读

1. [INSTALL.md](./INSTALL.md)
2. [SECURITY-MODEL.md](./SECURITY-MODEL.md)
3. [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md)
4. [docs/FEISHU-ENHANCEMENT.md](./docs/FEISHU-ENHANCEMENT.md)
5. [docs/FEISHU-CHAT-ADMIN.md](./docs/FEISHU-CHAT-ADMIN.md)
6. [docs/VALIDATION-AND-RELEASE.md](./docs/VALIDATION-AND-RELEASE.md)

## 17. 许可证

本仓库使用 [Apache-2.0](./LICENSE)。
