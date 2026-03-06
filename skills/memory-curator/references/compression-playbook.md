# Compression Playbook

## Goal

Compress memory for long-term usability without losing factual fidelity.

## Compression Steps

1. Collect candidate files in date range.
2. Extract structured sections only.
3. Group by semantic key (project + topic + decision/preference type).
4. Deduplicate statements while preserving source dates.
5. Flag conflicting statements and keep both versions.
6. Generate monthly archive summary.
7. Promote only high-confidence stable facts to `MEMORY.md`.

## Promotion Checklist

- repeated signal in at least two sessions, or explicit user confirmation
- future utility expected
- scope is clear and non-ambiguous
- does not expose secrets

## Conflict Handling

When two records conflict:

- keep both with source dates
- add `conflict: yes`
- request user decision before promotion

## Output Labeling

Use labels in summary:

- `promoted`
- `candidate`
- `conflict`
- `dropped-transient`
