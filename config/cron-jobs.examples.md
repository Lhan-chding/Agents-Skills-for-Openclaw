# Cron Job Examples (OpenClaw 2026.3.x)

Use these as templates. Replace IDs/placeholders before running.

## Daily "Top 3 Priorities" Push (Feishu)

```powershell
openclaw.cmd cron add `
  --name "daily-top3-priorities" `
  --cron "0 9 * * *" `
  --tz "Asia/Shanghai" `
  --agent "dev" `
  --message "请生成今日重点三件事，按可执行动作输出，并给出晚间复盘提示。" `
  --announce `
  --channel "feishu" `
  --to "REPLACE_WITH_FEISHU_CHAT_ID"
```

## Weekly Memory Compression Reminder (Feishu)

```powershell
openclaw.cmd cron add `
  --name "weekly-memory-compression" `
  --cron "0 20 * * 5" `
  --tz "Asia/Shanghai" `
  --agent "dev" `
  --message "提醒：请执行 Compress-Memory.ps1，并将稳定偏好写入 MEMORY.md。" `
  --announce `
  --channel "feishu" `
  --to "REPLACE_WITH_FEISHU_CHAT_ID"
```

## Weekly Project Digest (Discord)

```powershell
openclaw.cmd cron add `
  --name "weekly-project-digest" `
  --cron "0 10 * * 1" `
  --tz "Asia/Shanghai" `
  --agent "dev" `
  --message "请汇总上周项目进展：变更说明、风险点、回滚建议、下周里程碑。" `
  --announce `
  --channel "discord" `
  --to "REPLACE_WITH_DISCORD_CHANNEL_ID"
```

## One-Shot Reminder in 30 Minutes

```powershell
openclaw.cmd cron add `
  --name "oneshot-follow-up" `
  --at "+30m" `
  --agent "dev" `
  --message "请提醒我检查论文阅读计划与今日 TODO 完成度。" `
  --announce `
  --channel "feishu" `
  --to "REPLACE_WITH_FEISHU_CHAT_ID" `
  --delete-after-run
```

## Inspect / Run / Remove

```powershell
openclaw.cmd cron list
openclaw.cmd cron status
openclaw.cmd cron run --name "daily-top3-priorities"
openclaw.cmd cron rm --name "oneshot-follow-up"
```
