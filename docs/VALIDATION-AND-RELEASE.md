# Validation and Release

## 1. Local validation

1. Install dry-run:
   - `scripts\Install-OpenClawCapabilityPack.ps1 -Force -DryRun`
2. Real install:
   - `scripts\Install-OpenClawCapabilityPack.ps1 -Force`
3. Verify:
   - `scripts\Verify-OpenClawCapabilityPack.ps1`
4. Skills:
   - `openclaw.cmd skills check`
5. Security audit (optional):
   - `openclaw.cmd security audit --json`

## 2. Warning cleanup validation

After gateway restart, check latest logs:

- expected: no `tools.profile (coding) allowlist contains unknown entries ...`
- if still present:
  1. run `scripts\Fix-ToolsProfileWarnings.ps1`
  2. restart gateway
  3. run verify script again

## 3. Scenario validation

Run at least one scenario for each capability:

1. Coding: research-first secure implementation request
2. Paper: formula derivation + user says `没懂` fallback mode
3. Writing: `修改建议 + 可直接粘贴版本`
4. Memory: compression + archive generation

## 4. Feishu bridge validation

1. `BatchGetIds` dry-run:
   - `powershell -File .\scripts\Invoke-FeishuChatAdmin.ps1 -Action BatchGetIds -Mobiles "<PHONE>" -DryRun`
2. Flow dry-run (PowerShell):
   - `powershell -File .\scripts\Run-FeishuGroupFlow.ps1 -Flow AddOnly -ChatId "oc_xxx" -AddMemberMobiles "<PHONE>"`
3. Flow dry-run (Linux sandbox command style):
   - `sh ./scripts/Run-FeishuGroupFlow.sh --flow AddOnly --chat-id "oc_xxx" --add-member-mobiles "<PHONE>"`
4. Execute flow only after explicit approval token:
   - `APPROVE_FEISHU_CHAT_ADMIN`

## 5. Sandbox path-escape validation

1. Verify direct host path access is blocked in sandbox (expected).
2. Import host path first:
   - `scripts\Sync-WorkspacePath.ps1 -SourcePath "C:\path\to\file" -DryRun`
   - `scripts\Sync-WorkspacePath.ps1 -SourcePath "C:\path\to\file" -ApprovalText APPROVE_WORKSPACE_IMPORT`
3. Verify imported workspace path can be read/executed by agent.

## 6. Release procedure

1. Update `CHANGELOG.md`
2. Ensure no secrets are committed
3. Tag release (example: `v2.0.1`)
4. Publish release notes covering:
   - warning cleanup
   - security controls
   - sandbox/path fixes
   - Feishu bridge enhancements

## 7. Rollback

1. Restore config:
   - `scripts\Rollback-OpenClawConfig.ps1`
2. Re-run verify script
3. Restart gateway
4. Confirm runtime behavior returns to previous baseline
