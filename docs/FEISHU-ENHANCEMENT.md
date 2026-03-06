# Feishu Enhancement Plan

## 1. Current Landable Capabilities

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

## 4. Security Boundaries

### Hard mechanisms

- OpenClaw approvals + sandbox + tool policy

### Engineering mechanisms

- channel config kept optional
- minimal plugin baseline
- script-based verification

### Soft mechanisms

- ask-before-risky-action behavior
- minimal-change default in writing mode

## 5. Configuration Notes

- Use `config/openclaw.channels.optional.json` as template only.
- Replace placeholders with real credentials locally.
- Do not commit secrets to repo.

## 6. Suggested Rollout

1. Enable Feishu channel with minimal permissions.
2. Verify DM and @mention behavior.
3. Enable scheduled reminders.
4. Add doc/wiki/drive/bitable workflows incrementally.
