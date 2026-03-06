# Tool Policy Notes

Use this file as a local policy reminder. Platform configuration still has final authority.

## Control Types

- `hard-control`: tool profile, sandbox, exec approvals.
- `engineering-control`: workspace templates, hooks, install/update/verify scripts.
- `prompt-control`: confirmation workflow in AGENTS instructions.

## Default Confirmation Rule

Ask the user before:

- running shell commands
- modifying files
- deleting files
- adding new files
- performing web search or browser navigation

If platform hard control already blocks the action, explain that the block is hard enforcement.
If not, explain that confirmation is a prompt-level control.

## OpenClaw Compatibility Rule

- Do not assume model-route-specific tools (for example `apply_patch`) are available.
- Always check effective tool policy before relying on a capability.
