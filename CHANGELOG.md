# Changelog

All notable changes to this capability pack are documented here.

## [2.0.1] - 2026-03-07

### Fixed

- `workspace-templates/BOOT.md` now explicitly requires the literal template path `memory/YYYY-MM-DD.template.md`.
- Added a hard note to avoid deriving `memory/<today>.template.md`, which caused `read` ENOENT errors in startup checks.
- Clarified startup step ordering so memory initialization behavior is deterministic in Feishu-driven sessions.

## [2.0.0] - 2026-03-07

### Added

- New skill: `memory-curator` for local memory maintenance and compression workflow.
- New scripts:
  - `Update-OpenClawCapabilityPack.ps1`
  - `Rollback-OpenClawConfig.ps1`
  - `Fix-ToolsProfileWarnings.ps1`
- GitHub governance files:
  - `LICENSE` (Apache-2.0)
  - `CONTRIBUTING.md`
  - `SECURITY.md`
  - `CODE_OF_CONDUCT.md`
  - `CITATION.cff`
  - issue / PR templates
- Docs set under `docs/` for architecture, Feishu enhancement, IM adapter roadmap, and release validation.

### Changed

- `config/openclaw.patch.json`:
  - dev agent moved from `tools.profile=coding` to `tools.profile=minimal + explicit allow`.
  - removed dependency on route-specific `apply_patch` style assumptions.
  - strengthened hooks, approvals, and local-memory defaults.
- `config/cron-jobs.examples.md` updated to OpenClaw 2026.3.x CLI syntax.
- `scripts/Install-OpenClawCapabilityPack.ps1` now supports `-DryRun` and safer overwrite behavior.
- `scripts/Apply-OpenClawPatch.ps1` now supports:
  - backup manifest
  - dry-run
  - `agents.list` merge by `id`
- `scripts/Set-ExecApprovals.ps1` now supports template-based update and optional CLI sync.
- `scripts/Verify-OpenClawCapabilityPack.ps1` now includes config policy checks + advisory warning scan.
- Upgraded all core skills and workspace templates for clearer trigger boundaries and control-layer labeling.

### Security

- Warning root cause cleanup: avoid `coding` profile unknown allowlist entries (`apply_patch/image/cron`) in default capability baseline.
- Reinforced local memory policy (`provider=local`, `fallback=none`).
- Kept approval-first execution model with allowlist defaults.
