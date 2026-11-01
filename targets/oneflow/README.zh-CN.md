[English](README.md) | **中文**

# OneFLOW target

该 target 将 agent-lab 协作包安装到 OneFLOW 检出中。它**不会修改求解器代码**。

## 先审计的原因

starter 的 `spatial`/`temporal` 划分是一个简化模型。OneFLOW 是 runtime/task 代码库：
`codes/main`、`codes/io`、`codes/ns`、`codes/residual`、`codes/grad`、`codes/solver`、
`codes/time`、`codes/unsteady` 和 `codes/update` 共享状态和 CMake 目标。如果两个 worker
立即修改代码，会产生重叠 scope 和冲突。

因此 v0.1 从两个**只读审计**开始：

| Workstream | 读取 | 产出 |
|---|---|---|
| `runtime-io` | `codes/main/`、`codes/io/`、`tests/main/`、`tests/io/`、`doc/AI_CONTEXT.md` | 边界图、R1 缺口、共享文件、建议 scope、一个待决问题 |
| `numerics` | `codes/ns/`、`codes/residual/`、`codes/grad/`、`codes/solver/`、`codes/lhs/`、`codes/time/`、`codes/unsteady/`、`codes/update/`、相关测试 | spatial/temporal/shared 责任图、测试缺口、建议 scope、一个待决问题 |

## 安装

```bash
export AGENTLAB=~/open-research-agents
"$AGENTLAB/platform/scripts/install_target.sh" cfd oneflow ~/OneFLOW
cd ~/OneFLOW
git add .agentlab
git commit -m "agentlab: add OneFLOW target pack"
```

安装过程不会提交任何内容。worker 启动前，`.agentlab` 必须提交到 `dev`，因为
`scope_check` 从 base ref 读取 scope。

## 运行审计

```bash
cd ~/OneFLOW
"$AGENTLAB/platform/scripts/preflight.sh" runtime-io
"$AGENTLAB/platform/scripts/run_worker.sh" runtime-io
"$AGENTLAB/platform/scripts/run_worker.sh" numerics
```

审计门禁：

```bash
GATE_MODE=audit "$AGENTLAB/platform/scripts/gate.sh" runtime-io
```

审计 worker 只提交 reports/RFC/repro。不构建、不运行 ctest、不修改代码。

## 合并审计报告

```bash
cd ~/OneFLOW
"$AGENTLAB/platform/scripts/integrate_audit.sh" runtime-io numerics
# 审查 .agentlab/reports/*.md 和 .agentlab/RFC/*.md
git checkout dev
git merge --no-ff audit-integration
```

`integrate_audit.sh` 拒绝 `.agentlab/reports`、`.agentlab/RFC` 和 `.agentlab/repro`
之外的任何改动。它不构建、不运行测试。

## 首次审计（2026-11-01）

两个审计均已运行，报告已合入 `dev`：

- `.agentlab/reports/runtime-io.md`
- `.agentlab/RFC/runtime-io-2026-11-01-shared-case-runtime-target.md`
- `.agentlab/reports/numerics.md`
- `.agentlab/RFC/numerics-2026-11-01-boundary-contracts.md`

### 已决定：不重构测试架构

runtime-io RFC 曾提议新增共享 `oneflow_case_runtime` 目标，使测试可以链接
`TeardownCase`。**v0.1 已拒绝该提议。** OneFLOW 保留现有测试架构；`TeardownCase`
作为已记录缺口保留。参见
`platform/docs/decisions/0002-no-test-architecture-refactor.md`。

worker 只能按现有模式新增测试：一个测试目标列出所需生产源。不得重构构建系统或新增
第二个测试入口。

### 仍待人工决定

1. numerics：补齐双时间，还是声明不支持并 fail-fast？
2. 在不允许构建重构的前提下，先开哪两个不相交的代码 workstream？

## 审计之后

1. 阅读 `.agentlab/reports/runtime-io.md` 和 `.agentlab/reports/numerics.md`。
2. 批准不相交的代码 scope，并填写 OneFLOW 专用契约。
3. 在 `.agentlab/target.env` 中设置 `AGENTLAB_MODE=worker`。
4. 在本机验证 `BUILD_CMD`/`UNIT_CMD`。
5. 在集成前注册一个真实验证算例。

## 分支规则

- 当前本地检出使用 `BASE_REF=dev`。
- 不要在 `master` 上开发或向 `master` push。
- 如需上游兼容，设置 `BASE_REF=upstream/hexin`。
- worker 不 push、不 merge；由人工完成集成和合并。

## 工作流指南

- [Developing OneFLOW with agentlab](WORKFLOW.md)（English）
- [用 agentlab 开发 OneFLOW](WORKFLOW.zh-CN.md)（中文）
- [通用 agentlab 工作流](../../docs/workflow.zh-CN.md)
