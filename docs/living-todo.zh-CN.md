[English](living-todo.md) | **中文**

# Living TODO

更新：2026-11-02

本页是平台仓库的短期交接。长期计划见
[`IMPLEMENTATION_PLAN.zh-CN.md`](../IMPLEMENTATION_PLAN.zh-CN.md)。本页记录当前在做什么、
接下来做什么，以及哪些决定尚未确定。

## 基线

```text
平台        main，92 项 smoke / 27 项 harness
目标        OneFLOW（本地 dev），已安装 .agentlab
Source 身份 lql341-agent，通过 gh-agent
真人身份    lql341（请求者与审批者）
```

## 现在 — v0.4.1 Source 与收件箱硬化

目标：在增加对外通信之前，让注意力闭环达到可日常使用的可靠度。

- [ ] Source 分页与限流：超过 100 条通知、HTTP 403/429、部分失败。保留上一次成功轮询状态。
- [ ] 候选详情：尽可能解析 actor，保留 thread/subject 标识，避免轻微更新产生新候选。
- [ ] Source 健康：在 `sources/github.json` 记录最近错误、连续失败次数和上次成功轮询；
      在 `source status` 中显示。
- [ ] 收件箱过滤：`--category`、`--since`，`--json` 输出包含 decision 和 ticket id。
      `fyi` 仍默认隐藏。
- [ ] 决策审计：只读的 `agentlab decisions` 视图，读取 `.agentlab/decisions/`；不新增状态。
- [ ] 测试：分页、429、候选更新、decision 列表。

验收：连续两次轮询不产生重复候选；限流轮询保留上次状态并报告错误；inbox 过滤结果与
`--json` 一致。

## 下一步 — v0.5 Outbox 与 Channel

- [ ] 持久化 outbox，位于 `.agentlab/outbox/`（如果量级需要再考虑 SQLite）。
- [ ] 第一个 Channel：通过 `GITHUB_CLI` 发送 GitHub issue/PR 评论。
- [ ] Receipt：sent、failed、retrying、withdrawn；退避重试。
- [ ] 每个 ticket/thread 默认只回复一次，除非新 decision 明确要求再次回复。
- [ ] 不自动合并、不主动评论、不以真人身份发言。

验收：回复只发送一次；重试不产生重复评论；发送失败在 `inbox`/`status` 中可见。

## 然后 — v0.6 Ticket 执行

- [ ] `agentlab run <ws> --ticket <id>` 校验 ticket，置为 `running`，并把 ticket id 传给 worker。
- [ ] worker 退出后，成功置 `review`，失败置 `blocked`；记录 commit、report 和 session。
- [ ] 每 ticket 一个 session/工作区（替代每 workstream），支持 follow-up 恢复。
- [ ] 恢复前做 policy revalidation；stale ticket 不能启动。
- [ ] 测试：未授权拒绝、stale 拒绝、成功/失败状态转换。

验收：未授权 ticket 不能运行；stale ticket 拒绝启动；重启和 follow-up 恢复保留 ticket。

## 后续

- v0.7：多 target/workspace 注册表，以及跨 target 的统一收件箱。
- v0.8：Campaign、预算，以及只对 observe 模式精确度经人测量并接受的规则开放 auto-accept。

## 待决问题

1. **Outbox 范围**：只发结果和问题，还是也发确认？当前默认应是结果和问题。
2. **run 是否强制 ticket**：v0.6 默认 `TICKET_REQUIRED=0`，由 target 选择开启，不破坏现有手动 workstream 流程。
3. **候选 actor**：GitHub notifications 不提供 actor。仅在 issue/comment API 可用时解析；否则保持 `unknown`。
4. **Source 准入**：保持 `observe` 到 v0.6；不自动创建 ticket。
5. **多 target 状态**：统一收件箱需要 workspace registry，不能用全局扫描伪造。

## 如何接手

```bash
cd ~/open-research-agents
git pull --ff-only
agentlab doctor
bash tests/platform_smoke.sh
bash scripts/validate-harness.sh
```

按顺序阅读：

1. `docs/workflow.zh-CN.md` — 当前流程。
2. `IMPLEMENTATION_PLAN.zh-CN.md` 第 8 节 — 路线图。
3. `platform/docs/target-pack-spec.zh-CN.md` — target 配置。
4. `targets/oneflow/README.zh-CN.md` — 当前 target。

然后选择 **现在** 下第一个未勾选项，先写测试，再实现，并更新本页。
v0.4.1 验收前不要开始 v0.5。

## 最近完成

- v0.1 手动 worker、gate、report、repro。
- v0.2 Attention Inbox。
- v0.3 Ticket 账本。
- v0.4 GitHub Source observe 模式；agent 账号通过 `gh-agent`。
- 安装器创建 `tickets/candidates/sources/decisions`；`update` 补充缺失 env key，不覆盖已有值。
- 一条命令的注意力演示（`scripts/demo-attention.sh`）。
