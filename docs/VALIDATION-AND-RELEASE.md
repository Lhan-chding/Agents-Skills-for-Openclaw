# Validation and Release

## 1. Local Validation Checklist

1. Install dry-run:
   - `scripts\Install-OpenClawCapabilityPack.ps1 -Force -DryRun`
2. Real install:
   - `scripts\Install-OpenClawCapabilityPack.ps1 -Force`
3. Verify:
   - `scripts\Verify-OpenClawCapabilityPack.ps1`
4. Skills:
   - `openclaw.cmd skills check`
5. Security:
   - `openclaw.cmd security audit --json`

## 2. Warning-Cleanup Validation

After restarting gateway, inspect latest logs:

- expected: no `tools.profile (coding) allowlist contains unknown entries ...`
- if still present, run:
  - `scripts\Fix-ToolsProfileWarnings.ps1`
  - restart gateway
  - re-run verification

## 3. Scenario Validation

Validate at least one scenario per capability:

- coding: research-first secure implementation request
- paper: formula derivation and user says "没懂" fallback mode
- writing: "修改建议 + 可直接粘贴版本"
- memory: compression and archive generation

## 4. Feishu Validation

1. DM response works.
2. Group mention policy works.
3. Cron reminder reaches target channel.

## 5. Release Procedure

1. Update `CHANGELOG.md`.
2. Ensure no secrets are committed.
3. Tag release version (e.g. `v2.0.0`).
4. Publish release notes summarizing:
   - warning cleanup
   - security changes
   - scripts and docs changes

## 6. Rollback Procedure

1. Restore config:
   - `scripts\Rollback-OpenClawConfig.ps1`
2. Re-run verification.
3. Restart gateway and confirm behavior.
