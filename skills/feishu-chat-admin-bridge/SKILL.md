---
name: feishu-chat-admin-bridge
description: Bridge skill for Feishu group administration when built-in OpenClaw Feishu tools are insufficient. Use when user asks to create chat groups, add members to groups, or run chat-admin API actions that are not exposed by `feishu_chat`.
---

# Feishu Chat Admin Bridge

## When to use

Use this skill only when the user explicitly asks for Feishu group admin operations such as:

- create a new group chat
- add users to an existing group chat
- run low-level group admin checks

Do not use this skill for normal Q&A or document editing.

## Capability boundary

1. Built-in `feishu_chat` tool is read-oriented in current OpenClaw release (primarily `info` and `members`).
2. Group mutation operations are executed via local script:
   - `scripts/Invoke-FeishuChatAdmin.ps1`
   - `scripts/Run-FeishuGroupFlow.ps1` (one-click orchestrator)
3. Script uses official Feishu Open API and requires app credentials.

## Security gates

Treat these as mandatory:

1. Run `-DryRun` first and show request target/body.
2. Explain impact and required scopes.
3. Ask user approval before real execution.
4. For mutating actions, require explicit `-ApprovalText APPROVE_FEISHU_CHAT_ADMIN`.

If user does not approve, stop after dry-run.

## Commands

Recommended one-click flow (dry-run first, then execute, then write-back report):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Run-FeishuGroupFlow.ps1 `
  -Flow CreateAndAdd `
  -ChatName "My Research Group" `
  -OwnerId "ou_xxx" `
  -CreateUserIds "ou_a","ou_b" `
  -AddMemberIds "ou_c","ou_d"
```

Execute after approval:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Run-FeishuGroupFlow.ps1 `
  -Flow CreateAndAdd `
  -ChatName "My Research Group" `
  -OwnerId "ou_xxx" `
  -CreateUserIds "ou_a","ou_b" `
  -AddMemberIds "ou_c","ou_d" `
  -Execute `
  -ApprovalText APPROVE_FEISHU_CHAT_ADMIN
```

Dry-run create group:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-FeishuChatAdmin.ps1 `
  -Action CreateChat `
  -ChatName "My Research Group" `
  -OwnerId "ou_xxx" `
  -UserIds "ou_a","ou_b" `
  -MemberIdType open_id `
  -DryRun
```

Execute create group (after approval):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-FeishuChatAdmin.ps1 `
  -Action CreateChat `
  -ChatName "My Research Group" `
  -OwnerId "ou_xxx" `
  -UserIds "ou_a","ou_b" `
  -MemberIdType open_id `
  -ApprovalText APPROVE_FEISHU_CHAT_ADMIN
```

Dry-run add members:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-FeishuChatAdmin.ps1 `
  -Action AddMembers `
  -ChatId "oc_xxx" `
  -MemberIds "ou_c","ou_d" `
  -MemberIdType open_id `
  -DryRun
```

Execute add members (after approval):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-FeishuChatAdmin.ps1 `
  -Action AddMembers `
  -ChatId "oc_xxx" `
  -MemberIds "ou_c","ou_d" `
  -MemberIdType open_id `
  -ApprovalText APPROVE_FEISHU_CHAT_ADMIN
```

## Required credentials

Use one of:

1. parameters `-AppId` and `-AppSecret`
2. env vars `FEISHU_APP_ID` and `FEISHU_APP_SECRET`

Never print or commit secrets.
