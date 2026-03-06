# OpenClaw Integration Notes

Use this note when the skill runs inside OpenClaw.

## Hard Controls (Platform-Enforced)

- Terminal execution approval is enforced by OpenClaw `exec-approvals.json`.
- Runtime isolation is enforced by OpenClaw sandbox settings.
- Tool availability is enforced by tool profiles and allow/deny policy.

Treat these as hard controls, not optional behavior.

## Soft Controls (Prompt-Level)

When hard control is unavailable for an action, require explicit user confirmation before:

- writing or deleting files
- applying large patches
- launching web search or browser crawling
- changing dependency versions
- running migrations or deployment workflows

State clearly that this is a prompt-level gate, not a platform-enforced approval.

## Execution Order in OpenClaw

1. Plan and diff first.
2. Ask for confirmation before risky actions.
3. Execute the minimal scoped change.
4. Report exact files and commands used.
5. Record unresolved risk and verification gaps.
