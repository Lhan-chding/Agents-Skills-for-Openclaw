# Optional IM Adapter Blueprint

This is a forward-looking design. QQ / WeChat / WeCom are not required for current baseline.

## 1. Design Principles

- keep core capability pack channel-agnostic
- isolate external IM complexity behind adapters
- enforce least privilege and explicit opt-in
- avoid making unstable adapters mandatory dependencies

## 2. Proposed Abstraction

### Channel abstraction

Common message contract:

- inbound event (`channel`, `sender`, `room`, `text`, `attachments`, `timestamp`)
- outbound action (`target`, `text`, `thread`, `metadata`)

### Adapter layer

Each adapter maps platform-specific API/webhook to common contract:

- `adapter-feishu`
- `adapter-qq` (future)
- `adapter-wechat` (future)
- `adapter-wecom` (future)
- `adapter-telegram` / `adapter-discord` (optional existing ecosystems)

### Webhook bridge

- verifies signatures/tokens
- applies rate-limit and replay protection
- forwards normalized events to OpenClaw channel/session routing

## 3. Capability Routing

- skill selection stays inside OpenClaw agent logic
- adapter only handles transport and identity mapping

## 4. Security Risks and Mitigations

- credential leakage: store secrets outside repo
- webhook spoofing: enforce signature verification
- permission sprawl: use minimal scopes per channel
- message injection: sanitize and mark untrusted payloads

## 5. What to Keep in This Repo Now

- architecture docs and config placeholders only
- no default enablement for non-baseline adapters
- no hard runtime dependency on QQ/WeChat/WeCom SDKs
