[English](validation.md) | **中文**

# 验证实验：完整的代码改动闭环

目的：证明 **worker 能够修改代码，同时门禁能够拒绝错误实现**。审计闭环已经验证；
本实验验证代码改动闭环。

实验对象是一个规模较小但真实的 CFD 任务：

> 实现一维线性对流的**一阶迎风残差**，并使 **MMS 空间收敛阶**检查报告约等于 1。

任务代码约 30 行，不是模拟任务。

---

## 选择该示例的原因

| 要求 | 该示例如何满足 |
|---|---|
| 真实且成本低 | 一个 `residual()` 函数和一个单元测试，编译约两秒 |
| 存在客观真值 | MMS：`u = sin(2π(x−at))`，残差应收敛到 `−a·u_x`，具有一阶精度 |
| 能区分“已实现”和“实现正确” | 编译通过和单元测试通过都不充分；必须测出 order 约等于 1 |
| 能证明门禁有效 | 将格式替换为中心差分（二阶）后，验证必须失败 |
| 不修改真实仓库 | 全部在临时目录中运行 |

---

## 三种验证方式，成本依次增加

### 方式 A：仅验证脚手架（不调用模型，无成本）

```bash
cd ~/open-research-agents
bash scripts/validate-harness.sh
```

该脚本约 15 秒执行 27 项断言，不调用模型。它使用确定性的替身 worker 检查完整链路：

```text
== baseline: contracts, core and verification exist
  ok    preflight PASS

== 1. gate before implementation reports UNVERIFIED
  ok    exit 2 (UNVERIFIED)
  ok    gate label is UNVERIFIED
  ok    verification reports the real reason

== 2. worker run produces a scoped commit
  ok    worker exit 0
  ok    scope check passed
  ok    exactly one commit on agent/spatial

== 3. gate after implementation reports PASS
  ok    exit 0 (PASS)
  ok    verification measured order ~1

== 4. integration gate PASSes with real numbers
  ok    integration gate PASS
  ok    integration label PASS

== 5. a wrong scheme is caught (central difference has order 2)
  ok    gate refused the wrong scheme (exit 1)
  ok    verification FAILs on the wrong scheme (exit 1)
  ok    verification names the violated order

== 6. an out-of-scope edit is caught
  ok    scope_check refused core/ (exit 1)
  ok    names the offending path
```

方式 A 验证全部机制：三态门禁、scope 强制、真实数值验证、集成门禁，以及错误实现会被拒绝。

### 方式 B：使用真实 Pi worker 执行同一任务（少量模型成本）

```bash
cd /tmp
rm -rf val val-wt
cp -R ~/open-research-agents/examples/validation/target val
cd val
git init -b main
git add -A
git commit -m "validation target"

# 起点：预期为 UNVERIFIED，退出码 2
agentlab gate spatial

# 运行 worker（thinking=high 时使用 --detach）
agentlab run spatial --detach
agentlab status
tail -f /tmp/val-wt/logs/spatial-detached-*.log

# 检查结果
agentlab gate spatial              # 默认在 worker 工作树中运行
agentlab integrate spatial
```

方式 B 是唯一能够证明模型可以在这些约束下完成任务的验证。先运行方式 A，通过后再运行方式 B。

### 方式 C：将流程应用于真实仓库（方式 A、B 均通过后）

按照 [`workflow.zh-CN.md`](workflow.zh-CN.md) 将 target 从 `audit` 切换为 `worker`，
并选择最小的真实任务。不要从求解器核心改动开始。

---

## 方式 B：详细步骤与预期输出

```bash
cd /tmp/val
agentlab gate spatial
```

预期：**退出码为 2**，不是 0：

```text
== unit
100% tests passed out of 1
== verification
UNVERIFIED: S1 not implemented: first-order upwind residual
VERIFICATION: UNVERIFIED
----
GATE UNVERIFIED (mode: worker)
```

```bash
agentlab run spatial --detach
```

预期：

```text
preflight: ... mode=worker
  ok   contracts have no TODO/[CONFIRM]
  ok   core/ exists and is non-empty
  ok   CMakeLists.txt exists
  ok   tests/unit has C++ test sources
run_worker: mode=worker workstream=spatial branch=agent/spatial worktree=/tmp/val-wt/spatial
scope: spatial OK (N changed files)
run_worker: exit=0 head=<sha>
```

```bash
agentlab gate spatial
```

预期：输出实测收敛阶：

```text
case=mms-advection-1d
n=40 l2=3.487041e-01
n=80 l2=1.744417e-01
observed_order=0.9993
PASS
----
GATE PASS (mode: worker)
```

```bash
agentlab integrate spatial
```

预期：

```text
== merge agent/spatial
== build / unit / verification
PASS
----
GATE PASS (mode: integration)
GATE PASS. Review the integration branch, then merge main after human approval.
```

---

## 需要人工检查的五项内容

不要仅依赖 `GATE PASS`。逐项检查以下内容。

### 1. worker 只修改了 scope 内的文件

```bash
cd /tmp/val-wt/spatial
git diff --stat main...HEAD
```

预期路径：`modules/spatial/`、`tests/unit/spatial/`、`CMakeLists.txt`、
`.agentlab/reports/` 和 `.agentlab/repro/`。

### 2. 报告描述的是实际工作，不是复述任务

```bash
cat /tmp/val-wt/spatial/.agentlab/reports/spatial.md
```

报告应包含改动摘要、门禁输出、commit SHA 和已知局限。如果只是复述
`.agentlab/TASKS.md`，说明 prompt 需要收紧。

### 3. 验证结果是计算得到的，不是直接打印的

```bash
cd /tmp/val
git checkout integration
./build/adv_mms
```

输出必须包含 `observed_order=0.9xxx`。从其他文件读取的常数不能作为有效证据。

### 4. 门禁会拒绝错误实现

```bash
cd /tmp/val-wt/spatial
python3 - <<'PY'
from pathlib import Path
p = Path('modules/spatial/upwind.cpp')
s = p.read_text()
s = s.replace(
    'const double left = U.data()[static_cast<std::size_t>(i) - 1 + g];',
    'const double left = U.data()[static_cast<std::size_t>(i) - 1 + g];\n'
    '  const double right = U.data()[static_cast<std::size_t>(i) + 1 + g];')
s = s.replace(
    'R.data()[static_cast<std::size_t>(i) + g] = -speed_ * (self - left) / h;',
    'R.data()[static_cast<std::size_t>(i) + g] = -speed_ * (right - left) / (2.0 * h);')
p.write_text(s)
PY
git add -A
git commit -m "wrong scheme"
agentlab gate spatial
```

门禁必须失败。

### 5. 越界修改会被拒绝

```bash
cd /tmp/val-wt/spatial
echo "// tampered" >> core/field.hpp
git add -A
git commit -m "touch core"
~/open-research-agents/platform/scripts/scope_check.sh spatial main
```

预期：`OUT OF SCOPE: core/field.hpp`，退出码 1。

---

## 参考运行结果（2026-11-01）

在参考机器上，方式 A 和方式 B 均已通过：

```text
方式 A  bash scripts/validate-harness.sh   -> 27 passed, 0 failed
方式 B  agentlab run spatial               -> 2m53s, 2 commits, exit 0
        agentlab gate spatial              -> GATE PASS, order 0.9993
        agentlab integrate spatial         -> GATE PASS (mode: integration)
        主检出上的 gate                    -> GATE UNVERIFIED (exit 2)
```

worker 报告状态为 `ready`，包含门禁输出、commit SHA 和已知局限。报告还识别出契约未规定的
`a < 0` 情况，而不是自行做出决定。

---

## 需要记录的内容

每次运行应保留：

```text
日期 / 平台 / 编译器
worker 模型
各状态的门禁退出码（2 -> 0）
observed_order
worker 修改的文件
报告中是否包含 need_decision
大致 token 用量和耗时
```

`agentlab status` 和 `.agentlab/repro/*.json` 已经记录了其中大部分内容。

---

## 失败归因

| 现象 | 可能原因 | 处理 |
|---|---|---|
| 实现前门禁返回 0 | 验证未生效 | 检查 `VERIFY_CMD`，确认 `run_all.sh` 实际执行 |
| 实现后门禁返回 2 | worker 未修改 `upwind.cpp`，或修改了其他文件 | 检查 `git diff` 和报告 |
| `observed_order` 为 0 或 NaN | 残差为零，或 ghost 层未填充 | 检查 worker 的 `residual()` 实现 |
| `OUT OF SCOPE: CMakeLists.txt` | scope 对任务而言过窄 | 将构建文件加入 scope，或避免构建改动 |
| worker 反复报告 `need_decision` | 契约不完整 | 完善 `.agentlab/contracts/`；这是人工工作 |
| worker 报告完成但没有 commit | 提交步骤被跳过 | `run_worker` 会判定失败；检查日志 |

---

## 实验局限

1. 只有一个 workstream。本实验验证单 worker 闭环，不验证多个 workstream 并行修改不相交代码。
2. 不包含 MPI 或多 rank 行为。`Comm` 是串行 no-op。
3. 不包含性能门禁；只验证正确性。
4. 任务结构化。真实的模糊请求更可能产生 `need_decision`，这是预期行为。
5. 方式 A 的替身 worker 是确定性的。方式 A 验证脚手架，不验证模型行为；模型行为需要方式 B。
