[English](AGENTS.md) | **中文**

# Open Research Agents — 平台仓库

本仓库是**平台**，不是 CFD 求解器。

修改任何内容之前：

1. 阅读 `platform/AGENTS.md`。
2. 阅读 `IMPLEMENTATION_PLAN.md`。
3. 除非你是人类所有者，否则不要修改 `domains/cfd/contracts/`；agent 必须提交 RFC。
4. 未同步更新 `platform/docs/governance.md` 和测试时，不要改变 `platform/scripts/` 的语义。

目标仓库是独立的 git 仓库。`examples/validation/target/` 是模板；运行 worker 前应将其
复制出去并执行 `git init`。
