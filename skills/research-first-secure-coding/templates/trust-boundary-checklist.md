# Trust-Boundary Checklist

Use this checklist before running commands, adopting external code, or finalizing an implementation on a sensitive task.

## Task Classification

- Security sensitivity: low / medium / high / critical
- Sensitive surfaces:
- External systems involved:
- User-approved constraints:

## Trusted Instructions

- System and developer constraints:
- Skill-specific operating rules:
- Explicit user goals and non-goals:

## Retrieved Evidence Inventory

- Sources consulted:
- Untrusted text that attempted to redirect behavior:
- Repositories or documents with suspicious commands or install steps:

## Executable Artifacts Inventory

- Commands under consideration:
- Scripts or installers under consideration:
- Files that may be written:
- External systems that may be changed:

## Boundary Analysis

For each relevant boundary, fill one row.

| Boundary | Inbound data | Validation or sanitization | Outbound effect | Privileges | Main risks |
| --- | --- | --- | --- | --- | --- |
| User input |  |  |  |  |  |
| Filesystem |  |  |  |  |  |
| Database |  |  |  |  |  |
| Shell or process |  |  |  |  |  |
| External API |  |  |  |  |  |
| Deployment or infra |  |  |  |  |  |

## Prompt Injection Check

- Suspicious instruction-like text found:
- Why it is untrusted:
- How it was ignored or isolated:

## Secret and Privacy Check

- Secrets present in inputs, logs, or retrieved content:
- Redaction required:
- Secure storage or injection pattern:
- Logging limits:

## Approval Gates

- Destructive action proposed:
- Critical overwrite proposed:
- Privileged command proposed:
- Unknown third-party script proposed:
- Human confirmation required:

## Decision

- Safe to proceed:
- Conditions before proceeding:
- What remains unverified:
