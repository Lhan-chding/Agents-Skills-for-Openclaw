# Feishu Chat Admin (Create Group + Add Members)

This document explains how to run Feishu group admin operations in this capability pack.

## 1) Why this document exists

In current OpenClaw Feishu extension builds, `feishu_chat` is read-oriented in practice (`info`, `members`), and `feishu_perm` is for doc/drive permissions.

If you need chat mutations (create group, add members), use:

- `scripts/Invoke-FeishuChatAdmin.ps1`
- `skills/feishu-chat-admin-bridge/SKILL.md`

## 2) Security model

### Hard mechanism

- `exec` approvals in OpenClaw config
- sandbox isolation and tool allowlist

### Engineering mechanism

- bridge script supports `-DryRun`
- mutating actions require `-ApprovalText APPROVE_FEISHU_CHAT_ADMIN`

### Soft mechanism

- agent prompt asks user before execution

## 3) Prerequisites

1. Feishu app has required IM scopes for chat create/member add.
2. `FEISHU_APP_ID` and `FEISHU_APP_SECRET` available locally.
3. OpenClaw `dev` agent can run `exec` (subject to approvals).

## 4) Commands

Set env once:

```powershell
$env:FEISHU_APP_ID = "<APP_ID>"
$env:FEISHU_APP_SECRET = "<APP_SECRET>"
```

Dry-run create chat:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-FeishuChatAdmin.ps1 `
  -Action CreateChat `
  -ChatName "Research Group" `
  -OwnerId "ou_xxx" `
  -UserIds "ou_a","ou_b" `
  -MemberIdType open_id `
  -DryRun
```

Execute create chat:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-FeishuChatAdmin.ps1 `
  -Action CreateChat `
  -ChatName "Research Group" `
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

Execute add members:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-FeishuChatAdmin.ps1 `
  -Action AddMembers `
  -ChatId "oc_xxx" `
  -MemberIds "ou_c","ou_d" `
  -MemberIdType open_id `
  -ApprovalText APPROVE_FEISHU_CHAT_ADMIN
```

## 4.1 One-click flow (recommended)

Use `Run-FeishuGroupFlow.ps1` to run a full chain:

1. auto dry-run
2. approval gate check
3. execute (optional)
4. write-back report (`.json` + `.md`)

Dry-run only:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Run-FeishuGroupFlow.ps1 `
  -Flow CreateAndAdd `
  -ChatName "Research Group" `
  -OwnerId "ou_xxx" `
  -CreateUserIds "ou_a","ou_b" `
  -AddMemberIds "ou_c","ou_d"
```

Execute after approval:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Run-FeishuGroupFlow.ps1 `
  -Flow CreateAndAdd `
  -ChatName "Research Group" `
  -OwnerId "ou_xxx" `
  -CreateUserIds "ou_a","ou_b" `
  -AddMemberIds "ou_c","ou_d" `
  -Execute `
  -ApprovalText APPROVE_FEISHU_CHAT_ADMIN
```

The script writes reports by default to:

- `%USERPROFILE%\.openclaw\workspace\memory\feishu-group-flow\`

## 5) Troubleshooting

1. `99991663` / permission errors: check app scopes and app approval status in Feishu Open Platform.
2. `chat_id` invalid: confirm chat ID starts with `oc_...` and belongs to the same tenant.
3. Tool not visible in agent: apply `config/openclaw.patch.json` and restart gateway.
