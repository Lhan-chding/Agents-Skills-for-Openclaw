# Security Policy

## Supported Versions

当前仅维护主分支（main/latest）。

## Reporting a Vulnerability

请不要在公开 issue 直接披露可利用细节。建议：

1. 使用私密渠道联系维护者。
2. 提供复现步骤、影响范围、建议缓解方案。
3. 如涉及凭证，请先自行轮换并脱敏日志。

## Security Baseline

本仓库默认安全基线：

- 默认 agent 更保守（read-only 工作区）
- dev agent 可写但仍受审批与 sandbox 约束
- `exec approvals` 默认 `ask=always`
- local memory provider，`fallback=none`
- 不默认启用高风险第三方插件

## Threat Model Scope

关注范围：

- OpenClaw 配置误配导致权限扩大
- 工具 allowlist/denylist 导致危险动作绕过
- 记忆数据云端回退泄露
- 脚本更新过程缺乏备份和回滚
- 渠道插件权限过宽

不在范围：

- 第三方 IM 平台自身漏洞
- 用户私有部署环境的系统级漏洞

## Hardening Expectations for PRs

涉及配置或脚本的 PR 必须说明：

- 是否改变 hard-control 行为
- 是否新增高风险工具/插件
- 默认权限是否收紧或放宽
- 回滚路径是否仍可用
