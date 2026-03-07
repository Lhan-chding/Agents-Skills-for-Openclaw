# OpenClaw Workspace Agent Policy

This workspace is optimized for five assistant capabilities:

- coding and secure engineering: `research-first-secure-coding`
- paper reading and formula tutoring: `paper-reading-formula-tutor`
- writing and Feishu collaboration: `writing-feishu-copilot`
- Feishu group administration bridge: `feishu-chat-admin-bridge`
- local memory maintenance: `memory-curator`

## Skill Routing

Use one primary skill by default. Mix only when user intent clearly requires it.

1. Coding/implementation/refactor/review/security analysis: `research-first-secure-coding`
2. Paper explanation/derivation/discretization/loss/experiment interpretation: `paper-reading-formula-tutor`
3. Doc rewrite/terminology normalization/Feishu collaboration: `writing-feishu-copilot`
4. Feishu group create/member add operations: `feishu-chat-admin-bridge`
5. MEMORY.md maintenance/daily-memory compression/archive promotion: `memory-curator`

## Control Layers

### Hard control (platform enforced)

- exec approvals (`exec-approvals.json`)
- sandbox workspace boundary
- tools profile and allow/deny policy
- local memory provider/fallback settings

### Engineering control (configured implementation)

- default agent is conservative
- dev agent is writable but constrained
- boot/md and session-memory hooks enabled
- scripts provide dry-run, backup, rollback, verification

### Prompt control (soft policy, not hard enforcement)

Before tool actions, request explicit user confirmation for:

- file search/list/read
- file create/edit/delete
- source code modifications
- shell/terminal commands
- web search/browser/external fetch
- dependency install/update
- database/deployment/infrastructure actions

Approval workflow:

1. State intended action in one sentence.
2. State impact (files/commands/network).
3. Ask for explicit approval.
4. Execute only after approval.

## Sandbox Path Rule

- Do not directly access host absolute paths (for example `C:\...`) inside sandbox.
- Import to workspace first using:
  - `scripts/Sync-WorkspacePath.ps1 -DryRun`
  - `scripts/Sync-WorkspacePath.ps1 -ApprovalText APPROVE_WORKSPACE_IMPORT`
- After import, use workspace path only.

## Delivery Rules

- Use plan-first for substantial changes.
- Keep claims traceable to code/log/source.
- Distinguish verified facts from assumptions.
- In review tasks: findings first, sorted by severity.
- In writing tasks: default to "修改建议 + 可直接粘贴版本".

## Memory Rules

- Long-term memory: `MEMORY.md`
- Daily memory: `memory/YYYY-MM-DD.md`
- Compression rules: `memory/COMPRESSION-RULES.md`
- Never store secrets in memory files.
