# Feishu Enhancement Plan

## 1. Current Landable Capabilities

### Tool boundary (important)

- built-in OpenClaw `feishu_chat` is currently read-oriented (`info`, `members`)
- built-in `feishu_perm` is for doc/drive permissions, not group member admin
- group create/member add should use the bridge script:
  - `scripts/Run-FeishuGroupFlow.sh` (Linux sandbox default)
  - `scripts/Invoke-FeishuChatAdmin.sh`
  - `scripts/Run-FeishuGroupFlow.ps1` (Windows host fallback)
  - `scripts/Invoke-FeishuChatAdmin.ps1`
  - `skills/feishu-chat-admin-bridge/SKILL.md`

### Private chat QA

- user asks directly in DM
- assistant handles coding/paper/writing/memory workflows

### Group mention workflow

- trigger by `@assistant`
- recommend allowlist group policy

### Doc collaboration

- rewrite suggestions + paste-ready content
- terminology normalization
- structure cleanup
- action-item extraction from provided snippets

### Regular reminders and digests

- cron-driven daily/weekly messages
- examples in `config/cron-jobs.examples.md`

## 2. Feishu Product-Side Scenarios

- Docs: polishing, rewrite variants, TODO extraction
- Wiki: chapter summaries and progress snapshots
- Drive: file-level summary and metadata notes (when content is provided)
- Bitable: action item normalization and status formatting (when rows are provided)

## 3. Interaction Modes

- DM: deep explanation and one-on-one planning
- Group @: concise, context-aware response
- Scheduled push: reminders, daily top-3 priorities, weekly digest

## 3.1 Daily plan coach schedule (22:00 + 07:30)

You can enable a two-step daily coach flow:

1. 22:00 reminder:
   - ask user to send tomorrow plan (top 3 priorities, schedule blocks, risks)
2. 07:30 morning brief:
   - summarize today tasks from latest plan
   - include weather and umbrella recommendation

Use:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Setup-DailyPlanWeatherCron.ps1 `
  -To "REPLACE_WITH_FEISHU_CHAT_ID_OR_OPEN_ID" `
  -Location "Chengdu" `
  -Timezone "Asia/Shanghai" `
  -Force
```

## 4. Security Boundaries

### Hard mechanisms

- OpenClaw approvals + sandbox + tool policy

### Engineering mechanisms

- channel config kept optional
- minimal plugin baseline
- script-based verification
- host-path import helper for sandbox compatibility (`scripts/Sync-WorkspacePath.ps1`)

### Soft mechanisms

- ask-before-risky-action behavior
- minimal-change default in writing mode

## 5. Configuration Notes

- Use `config/openclaw.channels.optional.json` as template only.
- Replace placeholders with real credentials locally.
- Do not commit secrets to repo.
- Ensure dev allowlist includes Feishu plugin tools (`feishu_chat`, `feishu_doc`, `feishu_drive`, `feishu_wiki`, `feishu_app_scopes`, `feishu_bitable_*`).
- If you need `feishu_perm`, apply `config/openclaw.feishu.perm.optional.json` intentionally (sensitive operation).

## 6. Suggested Rollout

1. Enable Feishu channel with minimal permissions.
2. Verify DM and @mention behavior.
3. Enable scheduled reminders.
4. Add doc/wiki/drive/bitable workflows incrementally.
5. For group admin automation, run bridge script in dry-run first, then execute with explicit approval text.
6. For host absolute paths (`C:\...`), import to workspace first, then operate on workspace paths only.
