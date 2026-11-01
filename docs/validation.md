**English** | [中文](validation.zh-CN.md)

# Validation Experiment: A Complete Code-Change Loop

Purpose: demonstrate that **a worker can change code while the gate still rejects
incorrect implementations**. The audit loop is already validated; this experiment
validates the code-change loop.

The subject is a small but real CFD task:

> Implement the **first-order upwind residual** for 1D linear advection and make
> the **MMS spatial convergence** check report order approximately 1.

The task is about 30 lines of code. It is not a mock.

---

## Why this example

| Requirement | How the example satisfies it |
|---|---|
| Real but inexpensive | One `residual()` function and one unit test; compilation takes about two seconds |
| Objective ground truth | MMS with `u = sin(2π(x−at))`; the residual must converge to `−a·u_x` at first order |
| Distinguishes "implemented" from "correct" | Compilation and unit tests are insufficient; the measured order must be approximately 1 |
| Proves the gate is meaningful | Replacing the scheme with central differences (second order) must fail verification |
| Does not modify the real repository | Everything runs in a temporary directory |

---

## Three validation methods, increasing in cost

### Method A: validate the harness only (no model calls, no cost)

```bash
cd ~/open-research-agents
bash scripts/validate-harness.sh
```

The script runs 27 assertions in about 15 seconds and makes no model calls. It uses
a deterministic stand-in worker and checks the complete control flow:

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

This method validates every mechanism: the three-state gate, scope enforcement,
real numerical verification, integration gating, and rejection of an incorrect
implementation.

### Method B: run a real Pi worker on the same task (small model cost)

```bash
cd /tmp
rm -rf val val-wt
cp -R ~/open-research-agents/examples/validation/target val
cd val
git init -b main
git add -A
git commit -m "validation target"

# Starting point: expected UNVERIFIED, exit 2
agentlab gate spatial

# Run the worker (use --detach when thinking=high)
agentlab run spatial --detach
agentlab status
tail -f /tmp/val-wt/logs/spatial-detached-*.log

# Inspect the result
agentlab gate spatial              # defaults to the worker worktree
agentlab integrate spatial
```

This is the only method that demonstrates that a model can complete the task under
these constraints. Run Method A first; run Method B only after A passes.

### Method C: apply the process to a real repository (after A and B pass)

Follow [`workflow.md`](workflow.md), switch the target from `audit` to `worker`,
and choose the smallest real task. Do not begin with solver-core changes.

---

## Method B: detailed steps and expected output

```bash
cd /tmp/val
agentlab gate spatial
```

Expected: **exit code 2**, not 0:

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

Expected:

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

Expected: a measured convergence order:

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

Expected:

```text
== merge agent/spatial
== build / unit / verification
PASS
----
GATE PASS (mode: integration)
GATE PASS. Review the integration branch, then merge main after human approval.
```

---

## Five points to verify manually

Do not rely on `GATE PASS` alone. Check each item below.

### 1. The worker changed only its scope

```bash
cd /tmp/val-wt/spatial
git diff --stat main...HEAD
```

Expected paths: `modules/spatial/`, `tests/unit/spatial/`, `CMakeLists.txt`,
`.agentlab/reports/`, and `.agentlab/repro/`.

### 2. The report describes the work, not the task

```bash
cat /tmp/val-wt/spatial/.agentlab/reports/spatial.md
```

The report should contain the change summary, gate output, commit SHA, and known
limitations. If it only restates `.agentlab/TASKS.md`, the prompt needs tightening.

### 3. The verification result is measured, not printed

```bash
cd /tmp/val
git checkout integration
./build/adv_mms
```

The output must contain `observed_order=0.9xxx`. A constant read from another file
is not valid evidence.

### 4. The gate rejects an incorrect implementation

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

The gate must fail.

### 5. Out-of-scope edits are rejected

```bash
cd /tmp/val-wt/spatial
echo "// tampered" >> core/field.hpp
git add -A
git commit -m "touch core"
~/open-research-agents/platform/scripts/scope_check.sh spatial main
```

Expected: `OUT OF SCOPE: core/field.hpp`, exit code 1.

---

## Results from the reference run (2026-11-01)

Method A and Method B both passed on the reference machine:

```text
Method A  bash scripts/validate-harness.sh   -> 27 passed, 0 failed
Method B  agentlab run spatial               -> 2m53s, 2 commits, exit 0
          agentlab gate spatial              -> GATE PASS, order 0.9993
          agentlab integrate spatial         -> GATE PASS (mode: integration)
          gate on the base checkout          -> GATE UNVERIFIED (exit 2)
```

The worker report status was `ready` and included gate output, the commit SHA, and
known limitations. It also identified an unspecified `a < 0` case instead of
deciding it silently.

---

## What to record

For each run, retain:

```text
date / platform / compiler
worker model
gate exit codes for each state (2 -> 0)
observed_order
files changed by the worker
whether the report contains need_decision
approximate token use and elapsed time
```

`agentlab status` and `.agentlab/repro/*.json` already record most of this.

---

## Failure attribution

| Symptom | Likely cause | Action |
|---|---|---|
| Gate returns 0 before implementation | Verification is not effective | Check `VERIFY_CMD` and whether `run_all.sh` actually executes |
| Gate returns 2 after implementation | Worker did not change `upwind.cpp`, or changed a different file | Inspect `git diff` and the report |
| `observed_order` is 0 or NaN | Residual is zero, or ghost cells are not filled | Inspect the worker's `residual()` |
| `OUT OF SCOPE: CMakeLists.txt` | Scope is too narrow for the task | Add the build file to scope, or avoid build changes |
| Worker repeatedly reports `need_decision` | Contract is incomplete | Complete `.agentlab/contracts/`; this is human work |
| Worker reports completion without a commit | Commit step was skipped | `run_worker` fails; inspect the log |

---

## Limitations of this experiment

1. It has one workstream. It validates a single-worker loop, not parallel
   workstreams on disjoint code.
2. It has no MPI or multi-rank behavior. `Comm` is a serial no-op.
3. It has no performance gate; it validates correctness only.
4. The task is structured. Ambiguous real requests are more likely to produce
   `need_decision`, which is expected.
5. The stand-in worker in Method A is deterministic. Method A validates the
   harness, not model behavior. Method B is required for that.
