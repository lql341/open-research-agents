# 验证实验：一次完整的代码改动闭环

目的：证明 **"worker 能改代码，而且门禁不会骗人"**。
这是整个平台唯一还没被验证的部分（审计跑通了，代码改动没跑通）。

实验对象是一个 30 行规模的真实 CFD 任务，不是假任务：

> 实现一维线性对流的**一阶迎风残差**，并让 **MMS 空间收敛阶** 报告 ≈ 1。

---

## 为什么是这个例子

| 要求 | 这个例子怎么满足 |
|---|---|
| 真实但不昂贵 | 一个 `residual()` 函数 + 一个单元测试，编译 2 秒 |
| 有客观真值 | MMS：`u = sin(2π(x−at))`，残差应收敛到 `−a·u_x`，一阶精度 |
| 能区分"做了"和"做对" | 编译通过、单测通过都不够；必须算出 order ≈ 1 |
| 能证明门禁不是摆设 | 换个**中心差分**（二阶）→ 验证必须失败 |
| 不碰你的真实仓库 | 全部在临时目录里 |

---

## 三种验证，成本递增

### 方式 A：只验证脚手架（**零成本，不调模型**）

```bash
cd ~/Downloads/agent/repo/open-research-agents
bash scripts/validate-harness.sh
```

16 项断言，约 15 秒，不花一个 token。它用一个确定性的"假 worker"
走完整条链路，并按顺序检查：

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

**这一步已经证明了全部机制**：三态门禁、scope 强制、真实数值验证、集成门禁、
以及"错误实现会被抓住"。

### 方式 B：让真实 Pi worker 做同一件事（**花很少 token**）

```bash
# 准备
cd /tmp
rm -rf val val-wt
cp -R ~/Downloads/agent/repo/open-research-agents/examples/validation/target val
cd val
git init -b main && git add -A && git commit -m "validation target"

# 确认起点是 UNVERIFIED
agentlab gate spatial        # 期望 exit 2

# 让 worker 干活
agentlab run spatial

# 看结果
agentlab status
agentlab gate spatial        # 期望 exit 0，输出 observed_order≈1
agentlab integrate spatial   # 期望 GATE PASS (mode: integration)
```

这就是**唯一能证明"模型能在这个约束下完成任务"的实验**。
建议先跑方式 A，跑通后再跑方式 B。

### 方式 C：接到你的真实仓库（**等 A、B 都通过后**）

按 [`install-manual.md`](install-manual.md) 第 8 节，把 OneFLOW 的
`AGENTLAB_MODE` 从 `audit` 改成 `worker`，然后选一个**范围最小**的真任务：
例如把 `HybridRoe()` 的空实现改成显式 fail-fast。

不要一上来就让 worker 改求解器核心。

---

## 方式 B 的详细步骤与期望输出

```bash
cd /tmp/val
agentlab gate spatial
```

期望（**关键**：退出码 2，不是 0）：

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
agentlab run spatial
```

期望：

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

期望（**关键**：真实测出来的 order）：

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

期望：

```text
== merge agent/spatial
== build / unit / verification
PASS
----
GATE PASS (mode: integration)
GATE PASS. Review the integration branch, then merge main after human approval.
```

---

## 你要亲眼检查的五件事

跑完之后，不要只看 `GATE PASS`。逐项确认：

### 1. worker 真的只改了自己该改的

```bash
cd /tmp/val-wt/spatial
git diff --stat main...HEAD
```

应该只有 `modules/spatial/`、`tests/unit/spatial/`、`CMakeLists.txt`、
`.agentlab/reports/`、`.agentlab/repro/`。

### 2. 报告是真的，不是复述任务

```bash
cat /tmp/val-wt/spatial/.agentlab/reports/spatial.md
```

看它有没有写：改了什么、gate 输出、commit SHA、已知局限。
如果只是抄了一遍 `.agentlab/TASKS.md`，说明 prompt 需要收紧。

### 3. 验证是算出来的，不是打印出来的

```bash
cd /tmp/val && git checkout integration && ./build/adv_mms
```

它必须打印 `observed_order=0.9xxx`。如果打印的是从别处读来的常数，
说明验证算例写坏了。

### 4. 门禁真的会拒绝

```bash
# 故意改错：把一阶迎风换成中心差分
cd /tmp/val-wt/spatial
python3 - <<'PY'
from pathlib import Path
p = Path('modules/spatial/upwind.cpp')
s = p.read_text()
s = s.replace('const double left = U.data()[static_cast<std::size_t>(i) - 1 + g];',
  'const double left = U.data()[static_cast<std::size_t>(i) - 1 + g];\n'
  '  const double right = U.data()[static_cast<std::size_t>(i) + 1 + g];')
s = s.replace('R.data()[static_cast<std::size_t>(i) + g] = -speed_ * (self - left) / h;',
  'R.data()[static_cast<std::size_t>(i) + g] = -speed_ * (right - left) / (2.0 * h);')
p.write_text(s)
PY
git add -A && git commit -m "wrong scheme"
agentlab gate spatial        # 必须失败
```

### 5. 越界真的会被拦住

```bash
cd /tmp/val-wt/spatial
echo "// tampered" >> core/field.hpp
git add -A && git commit -m "touch core"
~/Downloads/agent/repo/open-research-agents/platform/scripts/scope_check.sh spatial main
# 期望：OUT OF SCOPE: core/field.hpp，exit 1
```

---

## 实测记录（2026-11-01，本机）

方式 A 与方式 B 都已跑通，下面是真实结果：

```text
方式 A  bash scripts/validate-harness.sh   → 16 passed, 0 failed
方式 B  agentlab run spatial                → 2m53s，2 个 commit，exit 0
        agentlab gate spatial               → GATE PASS，order 0.9993
        agentlab integrate spatial          → GATE PASS (mode: integration)
        主检出 gate（仍是桩）                → GATE UNVERIFIED (exit 2)
```

worker 的报告状态 `ready`，报告里写了 gate 输出、commit SHA、已知局限，
并且**主动指出**契约里没规定 `a < 0` 时该用哪一侧模板 —— 标为观察，没有擅自改。

## 记录什么

每跑一次，把下面这些保存下来（这是以后"平台是否可靠"的基线）：

```text
日期 / 平台 / 编译器
worker 模型
gate 三态的实际退出码（2 -> 0）
observed_order 的实际值
worker 改了哪些文件
报告里有没有 need_decision
token / 耗时（大概）
```

`agentlab status` 和 `.agentlab/repro/*.json` 已经自动记了大部分。

---

## 失败时怎么判断是谁的问题

| 现象 | 大概率是 | 处理 |
|---|---|---|
| gate 在实现前返回 0 | 验证算例没生效 | 检查 `VERIFY_CMD`、`run_all.sh` 是否真的执行 |
| gate 在实现后返回 2 | worker 没改 `upwind.cpp`，或改了别处 | 看 `git diff` 和报告 |
| `observed_order` 一直是 0 或 NaN | 残差恒为 0，或 ghost 层没填 | 看 worker 的 `residual` 实现 |
| `OUT OF SCOPE: CMakeLists.txt` | 目标仓库 scope 太窄 | 这是设计选择：允许改构建就加进 scope |
| worker 反复 `need_decision` | 契约不清楚 | 补 `.agentlab/contracts/`，这是人的活 |
| worker 说完成了但没有 commit | worker 忘了提交 | `run_worker` 会判失败；看日志里的原因 |

---

## 已知的实验局限

诚实说明，避免过度解读：

1. **只有一个 workstream**。这个例子验证的是"单 worker 闭环"，不是"两个 worker 并行不冲突"。
2. **没有多 rank / MPI**。`Comm` 是串行 no-op。
3. **没有性能门禁**。只有正确性。
4. **任务是结构化的**。真实的模糊需求会更多触发 `need_decision`，那才是常态。
5. **假 worker 是确定性的**。方式 A 通过不代表模型也会通过，所以方式 B 必须跑。

方式 A 证明的是**脚手架**，方式 B 证明的是**模型在这个脚手架里能不能干活**。
两者都通过，才说明这套东西能用。
