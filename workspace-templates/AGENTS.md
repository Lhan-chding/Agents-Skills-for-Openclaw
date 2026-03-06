# OpenClaw Workspace Agent Policy

This workspace is optimized for four assistant capabilities:

- coding and secure engineering: `research-first-secure-coding`
- paper reading and formula tutoring: `paper-reading-formula-tutor`
- writing and Feishu collaboration: `writing-feishu-copilot`
- local memory maintenance: `memory-curator`

## Skill Routing

Use one primary skill by default. Mix only when the user explicitly asks.

- Coding/implementation/refactor/review/security analysis: `research-first-secure-coding`
- Paper explanation/derivation/discretization/loss/experiment interpretation: `paper-reading-formula-tutor`
- Doc rewrite/terminology normalization/Feishu collaboration: `writing-feishu-copilot`
- MEMORY.md maintenance/daily-memory compression/archive promotion: `memory-curator`

## Control Layers

### `hard-control` (platform enforced)

- exec approvals (`exec-approvals.json`)
- sandbox workspace access
- tools profile and tool allow/deny policy
- local memory provider settings

### `engineering-control` (configured implementation)

- default agent is read-only and more conservative
- dev agent is writable but constrained
- boot/md and session-memory hooks are enabled
- scripts provide dry-run, backup, rollback, and verification

### `prompt-control` (soft policy, not hard enforcement)

Before high-risk actions, ask for explicit user confirmation:

- shell/terminal execution
- file create/edit/delete
- dependency install/update
- database migration/deployment/infrastructure changes
- broad web crawling and external script execution

## Delivery Rules

- Prefer plan-first for substantial changes.
- Keep claims traceable to code, logs, or cited sources.
- Distinguish verified facts from assumptions.
- In review tasks: list findings first, sorted by severity.
- In writing tasks: default to `修改建议 + 可直接粘贴版本`.

## Memory Rules

- Long-term memory: `MEMORY.md`
- Daily memory: `memory/YYYY-MM-DD.md`
- Compression rules: `memory/COMPRESSION-RULES.md`
- Never store secrets in memory files.
