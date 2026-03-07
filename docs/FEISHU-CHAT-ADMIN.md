# Feishu Chat Admin (Create Group + Add Members)

This document explains how to run Feishu group admin operations in this capability pack.

## 1) Why this document exists

In current OpenClaw Feishu extension builds, `feishu_chat` is read-oriented in practice (`info`, `members`), and `feishu_perm` is for doc/drive permissions.

If you need chat mutations (create group, add members), use the bridge scripts:

- `scripts/Invoke-FeishuChatAdmin.sh` (Linux sandbox default)
- `scripts/Run-FeishuGroupFlow.sh` (one-click flow)
- `scripts/Invoke-FeishuChatAdmin.ps1` / `scripts/Run-FeishuGroupFlow.ps1` (Windows host fallback)

## 2) Official API references (must-read)

Primary references used by this pack:

1. Tenant access token (Feishu):
   - https://open.feishu.cn/document/server-docs/authentication-management/access-token/tenant_access_token_internal
2. Batch get user IDs from mobile/email:
   - https://open.feishu.cn/document/server-docs/contact-v3/user/batch_get_id
3. IM create chat and add chat members:
   - https://open.feishu.cn/document/server-docs/im-v1/chat/create
   - https://open.feishu.cn/document/server-docs/im-v1/chat-members/create
4. OpenClaw sandbox + tool + approvals (hard controls):
   - https://docs.openclaw.ai/guides/configuration
   - https://docs.openclaw.ai/guides/skills

## 3) Security model

### Hard mechanism (platform-enforced)

- OpenClaw `exec` approvals
- sandbox isolation + workspace root boundary
- tool allowlist

### Engineering mechanism (this capability pack)

- dry-run first by default
- explicit approval token for mutation: `APPROVE_FEISHU_CHAT_ADMIN`
- workspace mirror import script to avoid path-escape failures

### Soft mechanism (prompt-level only)

- assistant confirms impact and asks user before actual mutation

## 4) Prerequisites

1. Feishu app has required IM scopes for create/add-member.
2. `FEISHU_APP_ID` and `FEISHU_APP_SECRET` available.
3. OpenClaw `dev` agent can run `exec` and approval flow is enabled.
4. Scripts are synced into `~/.openclaw/workspace/scripts`.

## 5) Commands

### 5.1 Linux sandbox commands (recommended for OpenClaw exec)

Set env once (if needed):

```sh
export FEISHU_APP_ID="<APP_ID>"
export FEISHU_APP_SECRET="<APP_SECRET>"
```

Dry-run create + add:

```sh
sh ./scripts/Run-FeishuGroupFlow.sh \
  --flow CreateAndAdd \
  --chat-name "Research Group" \
  --owner-id "ou_xxx" \
  --create-user-ids "ou_a,ou_b" \
  --add-member-ids "ou_c,ou_d"
```

Execute after explicit approval:

```sh
sh ./scripts/Run-FeishuGroupFlow.sh \
  --flow CreateAndAdd \
  --chat-name "Research Group" \
  --owner-id "ou_xxx" \
  --create-user-ids "ou_a,ou_b" \
  --add-member-ids "ou_c,ou_d" \
  --execute \
  --approval-text APPROVE_FEISHU_CHAT_ADMIN
```

Add members by mobile (auto resolve IDs):

```sh
sh ./scripts/Run-FeishuGroupFlow.sh \
  --flow AddOnly \
  --chat-id "oc_xxx" \
  --add-member-mobiles "18780986576" \
  --member-id-type open_id
```

### 5.2 Windows host fallback

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Run-FeishuGroupFlow.ps1 `
  -Flow AddOnly `
  -ChatId "oc_xxx" `
  -AddMemberMobiles "18780986576"
```

Execute:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Run-FeishuGroupFlow.ps1 `
  -Flow AddOnly `
  -ChatId "oc_xxx" `
  -AddMemberMobiles "18780986576" `
  -Execute `
  -ApprovalText APPROVE_FEISHU_CHAT_ADMIN
```

## 6) Path-escape hard fix (`C:\...` cannot be read in sandbox)

### Root cause

Sandbox can only access workspace root, usually `~/.openclaw/workspace`.

### Correct pattern

1. Import host path into workspace first (dry-run):

```powershell
.\scripts\Sync-WorkspacePath.ps1 `
  -SourcePath "C:\path\to\file-or-folder" `
  -DryRun
```

2. Execute import after approval:

```powershell
.\scripts\Sync-WorkspacePath.ps1 `
  -SourcePath "C:\path\to\file-or-folder" `
  -ApprovalText APPROVE_WORKSPACE_IMPORT
```

3. Use imported workspace path only.

## 7) Reports and memory write-back

`Run-FeishuGroupFlow` writes:

- JSON report: `~/.openclaw/workspace/memory/feishu-group-flow/*.json`
- Markdown report: `~/.openclaw/workspace/memory/feishu-group-flow/*.md`

Optional daily memory append:

- shell: `--writeback-daily-memory`
- PowerShell: `-WriteBackDailyMemory`

## 8) Troubleshooting

1. `powershell: not found` in `/bin/sh`:
   - Use `.sh` scripts in sandbox, not `powershell -File ...`
2. `Path escapes sandbox root`:
   - Import first with `Sync-WorkspacePath.ps1`, then use workspace path.
3. `99991663`:
   - Usually missing scope, app not approved, or tenant policy restriction.
4. `tenant_access_token` fails:
   - Check App ID/Secret and app deployment status.
5. `chat_id` invalid:
   - Verify same tenant and correct `oc_...` chat ID.
