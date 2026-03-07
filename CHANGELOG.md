# Changelog

All notable changes to this capability pack are documented here.

## [2.0.5] - 2026-03-07

### Added

- Linux-sandbox-compatible Feishu bridge scripts:
  - `scripts/Invoke-FeishuChatAdmin.sh`
  - `scripts/Run-FeishuGroupFlow.sh`
- New workspace import helper for sandbox path boundary:
  - `scripts/Sync-WorkspacePath.ps1`

### Changed

- Feishu bridge now supports ID resolution workflow (`mobile/email -> user ID`) via `BatchGetIds`:
  - `scripts/Invoke-FeishuChatAdmin.ps1`
  - `scripts/Run-FeishuGroupFlow.ps1`
- Installer now syncs bridge scripts into `~/.openclaw/workspace/scripts` to prevent runtime path-escape issues.
- Verification script now checks workspace bridge scripts and adds advisory check for workspace skill source.
- `Run-FeishuGroupFlow.ps1` and `.sh` now include write-back path fallback when default workspace memory path is unavailable.

### Docs

- Rewrote `README.md` with clearer operator-facing instructions (no GitHub upload steps).
- Expanded `INSTALL.md` with Linux sandbox bridge commands and path-import flow.
- Rewrote `docs/FEISHU-CHAT-ADMIN.md` with official API references and troubleshooting.
- Updated `docs/FEISHU-ENHANCEMENT.md`, `docs/VALIDATION-AND-RELEASE.md`, and `SECURITY-MODEL.md` for sandbox/path boundary rules.

## [2.0.4] - 2026-03-07

### Fixed

- Resolved sandbox skill-read path-escape issue by installing custom skills to `~/.openclaw/workspace/skills` in addition to managed `~/.openclaw/skills`.
- Updated verification logic to require workspace skill copies (sandbox-readable) for all core custom skills.

### Docs

- Added troubleshooting guidance for:
  - `read failed: Path escapes sandbox root ... .openclaw\\skills\\...\\SKILL.md`
- Clarified install behavior: dual skill sync (managed + workspace).

## [2.0.3] - 2026-03-07

### Added

- New one-click flow script: `scripts/Run-FeishuGroupFlow.ps1`
  - auto dry-run
  - approval token gate
  - optional execute
  - write-back reports (`.json` + `.md`)
  - optional append to daily memory

### Changed

- Updated Feishu admin docs and skill instructions to recommend `Run-FeishuGroupFlow.ps1` as the primary workflow.
- Updated install and README examples for one-click group create/member add flow.

## [2.0.2] - 2026-03-07

### Fixed

- Added Feishu plugin tools to `dev` allowlists in `config/openclaw.patch.json` so Feishu skills are actionable instead of prompt-only.
- Switched `agents.list.dev.tools.profile` to `full` with explicit allowlist to avoid tool-injection gaps observed with `minimal`.
- Updated optional channel template to include explicit `channels.feishu.tools` defaults.
- Removed `feishu_perm` from default allowlist to avoid unknown-tool warnings when `perm` is disabled.

### Added

- New script: `scripts/Invoke-FeishuChatAdmin.ps1` for Feishu chat admin API bridge (`GetChatInfo`, `ListMembers`, `CreateChat`, `AddMembers`).
- New skill: `skills/feishu-chat-admin-bridge/SKILL.md` with dry-run first and approval-text gate for mutating actions.
- New optional patch: `config/openclaw.feishu.perm.optional.json` to enable `feishu_perm` intentionally.

### Docs

- Expanded README and `docs/FEISHU-ENHANCEMENT.md` with Feishu group admin boundary notes and bridge workflow.

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
