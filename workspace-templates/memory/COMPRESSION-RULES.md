# Memory Compression Rules

Goal: compress daily notes without losing critical facts.

## Cadence

- Run weekly for short-term cleanup.
- Run monthly for archive rollup.

## Source Scope

- `memory/YYYY-MM-DD.md` files older than 7 days.
- Never delete raw notes during first pass.

## Compression Method (Loss-Minimized)

1. Extract only structured fields:
- durable facts candidate
- decisions
- preferences
- open loops
- blockers

2. Deduplicate by semantic key:
- same project + same decision topic + same preference intent

3. Preserve provenance:
- every compressed bullet includes source date reference

4. Promote stable items:
- copy high-confidence durable facts to `MEMORY.md`
- mark copied items in daily file with `promoted: yes`

5. Archive summary:
- write monthly summary to `memory/archive/YYYY-MM.md`
- keep unresolved loops in `MEMORY.md` persistent open loops

6. Resolve conflicts safely:
- if two records disagree, keep both with `conflict: yes`
- request user confirmation before promotion into `MEMORY.md`

## Strict Safety Rules

- Do not store secrets.
- Do not rewrite historical facts without source date reference.
- If uncertain, keep both versions and mark conflict.
- Treat deletion of raw daily memory as high-risk and require explicit approval.
