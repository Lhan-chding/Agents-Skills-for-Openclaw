---
name: feishu-chat-admin-bridge
description: Bridge skill for Feishu group administration when built-in OpenClaw Feishu tools are insufficient. Use when user asks to create chat groups, add members to groups, or run chat-admin API actions that are not exposed by `feishu_chat`.
---

# Feishu Chat Admin Bridge

## When to use

Use this skill only when the user explicitly asks for Feishu group admin operations such as:

- create a new group chat
- add users to an existing group chat
- resolve user IDs from mobile/email before member add

Do not use this skill for normal Q&A or document editing.

## Capability boundary

1. Built-in `feishu_chat` is read-oriented in current OpenClaw release.
2. Group mutation operations are executed via local bridge scripts:
   - `scripts/Invoke-FeishuChatAdmin.sh` (Linux sandbox default)
   - `scripts/Run-FeishuGroupFlow.sh` (one-click orchestrator)
   - `scripts/Invoke-FeishuChatAdmin.ps1` and `scripts/Run-FeishuGroupFlow.ps1` (Windows host fallback)
3. Script uses official Feishu Open API and requires app credentials.

## Security gates

Treat these as mandatory:

1. Run dry-run first and show request target/body.
2. Explain impact and required scopes.
3. Ask user approval before real execution.
4. For mutating actions, require explicit approval text:
   - `APPROVE_FEISHU_CHAT_ADMIN`

If user does not approve, stop after dry-run.

## Sandbox path rule (mandatory)

1. Never read or execute host absolute paths directly in sandbox (e.g. `C:\...`).
2. If user asks to use host files, import first to workspace path with:
   - `scripts/Sync-WorkspacePath.ps1 -DryRun`
   - after approval: `scripts/Sync-WorkspacePath.ps1 -ApprovalText APPROVE_WORKSPACE_IMPORT`
3. Execute only workspace paths after import.

## Commands

Preferred in OpenClaw Linux sandbox:

```sh
sh ./scripts/Run-FeishuGroupFlow.sh \
  --flow CreateAndAdd \
  --chat-name "My Research Group" \
  --owner-id "ou_xxx" \
  --create-user-ids "ou_a,ou_b" \
  --add-member-ids "ou_c,ou_d"
```

Execute after approval:

```sh
sh ./scripts/Run-FeishuGroupFlow.sh \
  --flow CreateAndAdd \
  --chat-name "My Research Group" \
  --owner-id "ou_xxx" \
  --create-user-ids "ou_a,ou_b" \
  --add-member-ids "ou_c,ou_d" \
  --execute \
  --approval-text APPROVE_FEISHU_CHAT_ADMIN
```

Add by mobile (resolve IDs first):

```sh
sh ./scripts/Run-FeishuGroupFlow.sh \
  --flow AddOnly \
  --chat-id "oc_xxx" \
  --add-member-mobiles "18780986576" \
  --member-id-type open_id
```

Windows host fallback:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Run-FeishuGroupFlow.ps1 `
  -Flow CreateAndAdd `
  -ChatName "My Research Group" `
  -OwnerId "ou_xxx" `
  -CreateUserIds "ou_a","ou_b" `
  -AddMemberIds "ou_c","ou_d"
```

## Required credentials

Use one of:

1. script parameters (`--app-id/--app-secret` or `-AppId/-AppSecret`)
2. env vars `FEISHU_APP_ID` and `FEISHU_APP_SECRET`

Never print or commit secrets.
