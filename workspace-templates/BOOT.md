# Startup Checklist

On each startup:

1. Read `AGENTS.md`.
2. Read `MEMORY.md`.
3. Read `memory/YYYY-MM-DD.md` for today if it exists.
4. If today's memory file does not exist, create it from the literal template file `memory/YYYY-MM-DD.template.md`.
5. Do NOT derive or read `memory/<today>.template.md`; that path is invalid by design.
6. Classify controls before risky actions:
   - `hard-control` (platform enforced)
   - `engineering-control` (script/config pattern)
   - `prompt-control` (soft confirmation)
7. Follow confirmation gates defined in `AGENTS.md` before risky actions.

If user says memory is stale, run compaction policy from `memory/COMPRESSION-RULES.md` or activate `memory-curator`.
