## Summary

What changed and why.

## Type of change

- [ ] config
- [ ] scripts
- [ ] skill
- [ ] docs
- [ ] security hardening

## Control-layer impact

- [ ] hard-control changed
- [ ] engineering-control changed
- [ ] prompt-control changed

Details:

## Validation

- [ ] `Install-OpenClawCapabilityPack.ps1 -DryRun`
- [ ] `Verify-OpenClawCapabilityPack.ps1`
- [ ] manual scenario test (coding / paper / writing / memory)

## Security checklist

- [ ] no new default high-risk plugin enabled
- [ ] no secrets in committed files
- [ ] memory remains local-first (`provider=local`, `fallback=none`)
- [ ] rollback path verified

## Rollback

How to revert if needed.
