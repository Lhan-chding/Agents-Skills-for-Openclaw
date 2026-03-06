# Contributing

感谢贡献。此仓库是 OpenClaw capability pack，不是通用 Python 包，请按以下流程提交改动。

## 1. 分支与提交

- 使用功能分支提交 PR。
- 提交信息建议格式：
  - `feat(config): ...`
  - `fix(scripts): ...`
  - `docs(readme): ...`
- 一次 PR 聚焦一个主题（配置、脚本、技能或文档）。

## 2. 必做检查

提交前请至少完成：

1. `scripts\Install-OpenClawCapabilityPack.ps1 -DryRun`
2. `scripts\Verify-OpenClawCapabilityPack.ps1`
3. 手工检查 `config/openclaw.patch.json` 不含 `apply_patch` 相关依赖项
4. 手工检查 memory 配置仍为 `provider=local` 且 `fallback=none`

## 3. 变更原则

- 优先最小改动，不无意义推翻已有可用内容。
- 所有安全相关改动必须在 PR 描述中明确：
  - 哪些是 `hard-control`
  - 哪些是 `engineering-control`
  - 哪些是 `prompt-control`
- 任何新增插件默认关闭，除非有明确最小权限评估。

## 4. 技能改动规范

- 每个 skill 的触发描述必须具体且可执行。
- 不要在 skill 中捏造 OpenClaw 配置键或命令。
- 保持 `SKILL.md` 与 `agents/openai.yaml` 同步。

## 5. 文档语言

- 中文为主，必要处补英文摘要。
- 所有命令必须可在 Windows PowerShell 下执行。

## 6. PR 内容建议

PR 描述建议包含：

1. 变更摘要
2. 风险与兼容性
3. 验证步骤与结果
4. 回滚方式
