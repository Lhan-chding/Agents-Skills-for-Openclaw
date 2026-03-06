---
name: memory-curator
description: Local memory curation workflow for OpenClaw workspaces. Use when the user asks to maintain MEMORY.md, summarize daily memory files, compress historical notes, promote durable facts, deduplicate repeated preferences, track open loops, or build weekly/monthly memory digests without losing provenance.
---

# Memory Curator

## Core Goal

Maintain high-signal local memory over long usage cycles while avoiding distortion and data loss.

## Operating Sequence

### 1. Confirm memory scope first

Capture:

- workspace root
- date range (`memory/YYYY-MM-DD.md`)
- whether output is daily, weekly, or monthly
- whether promotion to `MEMORY.md` is requested

Never assume cloud memory providers. Work from local markdown files only.

### 2. Parse structured sections only

Prioritize structured fields from daily notes:

- durable facts candidate
- preferences
- decisions
- open loops
- risks/blockers

Keep source date for every promoted item.

### 3. Compress with provenance

For each compressed bullet, keep:

- canonical statement
- source date(s)
- confidence level
- conflict marker (if competing versions exist)

Do not collapse conflicting records into one statement without an explicit conflict note.

### 4. Promotion rules for MEMORY.md

Promote only if all conditions hold:

- appears repeatedly or has explicit user confirmation
- high utility across sessions
- not a transient task state
- not a secret

When uncertain, keep in monthly archive and mark as pending promotion.

### 5. Output contract

Default output:

- A. Compression scope and source files
- B. Promoted durable facts (with dates)
- C. Pending items requiring user confirmation
- D. Open loops to carry forward
- E. Risks and stale-memory warnings

## Safety Rules

- Never store secrets, credentials, or tokens.
- Never delete source daily files by default.
- Treat deletion as a high-risk action requiring explicit user approval.

## Resource Map

- [references/compression-playbook.md](references/compression-playbook.md): compression and promotion playbook
