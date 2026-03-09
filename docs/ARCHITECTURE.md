# Architecture Overview

## 1. Capability Layers

1. Config layer (`config/`):
   - secure defaults
   - approval policy
   - optional channels and cron templates
2. Automation layer (`scripts/`):
   - install/update/apply/verify/rollback
   - memory compression
3. Skill layer (`skills/`):
   - coding / paper / writing / memory
4. Workspace layer (`workspace-templates/`):
   - AGENTS / TOOLS / BOOT / MEMORY scaffolding

## 2. Agent Strategy

- Default agent: conservative, read-only workspace.
- `dev` agent: writable workspace, explicit tool allowlist, approvals required.
- Sandbox scope: `agent` by default, so one agent reuses one sandbox instead of creating one container per session.

## 3. Security Strategy

- `hard-control`: OpenClaw policy and approvals.
- `engineering-control`: scripts and templates enforce repeatable safe operations.
- `prompt-control`: conversational confirmation and behavior constraints.

## 4. Memory Strategy

- local-only memory search configuration
- daily markdown memory files
- periodic compression into monthly archive
- promotion of durable facts to `MEMORY.md`

## 5. Channel Strategy

- Current baseline: Feishu + Discord support
- Optional future adapters: QQ/WeChat/WeCom/Telegram bridge
- No hard dependency on unstable external adapters
