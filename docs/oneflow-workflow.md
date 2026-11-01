# Developing OneFLOW with agentlab

Status: v0.1  
Audience: a solo developer who is used to `cd OneFLOW && pi` and typing requests in
natural language.

`agentlab` does not replace Pi. It adds four things around a normal Pi session:
a **task**, an **isolated worktree**, a **gate**, and a **commit + report**.

---

## 1. Three ways to work

| Mode | Command | Use it for | Gate / report |
|---|---|---|---|
| **Native Pi** | `cd ~/OneFLOW && pi` | reading code, exploring, one-off edits, questions | none; you review |
| **Task worker** | `agentlab run <ws>` | a concrete deliverable: code + tests + verification + commit | yes |
| **Interactive worker** | `agentlab pi <ws>` | continue a worker's session in its worktree, debug, ask follow-ups | gate is manual |

Rules of thumb:

- **Explore with native Pi.** Do not pay the task/gate overhead for "where is this
  function" or a one-line comment fix.
- **Use a task worker when you already know the deliverable** and want scope
  enforcement, an isolated worktree, a commit, and a report.
- **Use an interactive worker when a task worker finished or got stuck** and you
  want to continue in the same worktree with the same session.

Natural language still works. For a task worker, put the request in
`.agentlab/TASKS.md`; the worker reads the board, not a free-form chat. You can
append a short clarification:

```bash
agentlab run runtime-io "Keep the serial output byte-identical."
```

For open-ended conversation in the same worktree:

```bash
agentlab pi runtime-io
```

---

## 2. What is already installed in OneFLOW

```text
~/OneFLOW
  branch        dev
  .agentlab/    target pack, committed on dev
  mode          audit          (workers cannot edit code)
  workstreams   runtime-io, numerics
  reports       .agentlab/reports/runtime-io.md, numerics.md
  RFCs          .agentlab/RFC/runtime-io-...md, numerics-...md
```

Check it:

```bash
cd ~/OneFLOW
agentlab status
```

Expected shape:

```text
WORKSTREAM    REPORT          GATE              WORKTREE  BRANCH  AHEAD
runtime-io    need_decision   audit:pass        -         yes     0
numerics      ready           audit:pass        -         yes     0

Pending decisions (RFC status: proposed):
  .agentlab/RFC/runtime-io-2026-11-01-shared-case-runtime-target.md
  .agentlab/RFC/numerics-2026-11-01-boundary-contracts.md
```

---

## 3. Current mode is audit

In `audit` mode a worker may only write:

```text
.agentlab/reports/<workstream>.md
.agentlab/RFC/<workstream>-*
.agentlab/repro/<workstream>-*
```

It does not build, does not run tests, and does not edit code. This is the safe
mode for mapping a codebase you do not fully trust yet.

The two audits are done. The remaining work is human:

1. Answer the two RFCs.
2. Choose the first code workstreams.
3. Narrow their scopes.
4. Fill contracts and register a real verification case.
5. Switch to `worker` mode.

---

## 4. Switch from audit to worker

### 4.1 Answer the RFCs

- `runtime-io`: the proposed shared `oneflow_case_runtime` target is **rejected**.
  The project has decided not to refactor its test architecture in v0.1. Record
  the RFC as rejected and keep the `io_paths.txt` finding as a separate task.
- `numerics`: decide whether dual-time is implemented or explicitly rejected with
  a fail-fast. The recommended first step is "declare unsupported + fail fast",
  because all five regression cases use `idualtime=0`.

Only a human changes an RFC status.

### 4.2 Write one task

Edit `.agentlab/TASKS.md`. The worker reads the first `todo` for its workstream.
A task needs a concrete deliverable and acceptance criteria, not "improve this".

```markdown
## runtime-io

- R1 [todo] Make `io_paths.txt` single-writer in multi-rank runs.

  Scope:
  - `codes/main/src/SimuContextIO.cpp`
  - the existing focused test target (do not create a new build target)

  Acceptance:
  - serial output is unchanged;
  - with `mpirun -np 2`, only one rank opens/truncates `io_paths.txt`;
  - existing related tests pass;
  - no change to the public semantics of `Prj.cpp`.
```

### 4.3 Narrow the scope

`.agentlab/scope/<workstream>.txt` starts as report-only. Replace it with the
exact source and test paths the task needs:

```text
# .agentlab/scope/runtime-io.txt
codes/main/src/SimuContextIO.cpp
tests/main/simu_context_parameter_test.cpp
.agentlab/reports/runtime-io.md
.agentlab/RFC/runtime-io-*
.agentlab/repro/runtime-io-*
```

Do not add whole directories such as `codes/main/` or `codes/ns/`. Scope is the
enforcement mechanism; a broad scope makes the gate decorative.

### 4.4 Contracts and verification

Two files decide whether the gate is meaningful:

| File | What it must contain |
|---|---|
| `.agentlab/contracts/` | OneFLOW's real boundary for this workstream, not the generic starter text. Replace `TODO` / `[CONFIRM]`. |
| `.agentlab/verification/run_all.sh` | A real case: run one existing OneFLOW case with its existing baseline, exit `0` PASS / `1` FAIL / `2` UNVERIFIED. |

Rules:

- Do not loosen tolerances to make a gate pass.
- Do not invent a second numerical baseline. Use `test/` and its existing
  `autotest/` references.
- If verification is still a placeholder, `worker` gates will be `UNVERIFIED`
  and `integration` will refuse them. That is intentional.

### 4.5 Build and test commands

`.agentlab/target.env` holds the candidate commands:

```text
BUILD_CMD   cmake -S . -B build ... && cmake --build build -j2
UNIT_CMD    ctest --test-dir build --output-on-failure
```

Before switching, check them on this machine. OneFLOW has no `unit` CTest label
and currently discovers about 1067 tests; running all of them for every worker is
slow. Narrowing `UNIT_CMD` with `ctest -R <pattern>` is a command change, not a
test-architecture change. Do not add a new label scheme as part of a code task.

### 4.6 Switch the mode

```bash
cd ~/OneFLOW
sed -i '' 's/^AGENTLAB_MODE=audit/AGENTLAB_MODE=worker/' .agentlab/target.env
# Linux: sed -i 's/^AGENTLAB_MODE=audit/AGENTLAB_MODE=worker/' .agentlab/target.env

git add .agentlab
git commit -m "agentlab: enable worker mode for runtime-io"
agentlab preflight runtime-io
```

`preflight` must pass before you spend a worker turn.

---

## 5. Run, review, integrate

```bash
cd ~/OneFLOW

# 1. start a worker in the background
agentlab run runtime-io --detach

# 2. follow it
agentlab status
tail -f ../OneFLOW-wt/logs/runtime-io-detached-*.log

# 3. inspect what it changed
cd ../OneFLOW-wt/runtime-io
git diff --stat main...HEAD
cat .agentlab/reports/runtime-io.md

# 4. continue interactively if needed
agentlab pi runtime-io

# 5. gate the worker branch (default: the worktree)
agentlab gate runtime-io

# 6. integrate and run the integration gate
cd ~/OneFLOW
agentlab integrate runtime-io

# 7. human review, then merge
git checkout dev
git merge --no-ff integration
```

Important:

- `agentlab gate <ws>` defaults to the **worker worktree**. The base checkout
  usually still holds the stub, so gating it would produce a misleading
  `UNVERIFIED`. Use `--here` only when you really mean the current checkout.
- `agentlab integrate` refuses a dirty tree. Untracked `.agentlab/repro/*.json`
  records are the only exception; they are committed with the integration.
- `agentlab status` shows `WORKTREE=repro` when the only uncommitted files are
  gate records.

---

## 6. First recommended task

Start with `runtime-io`, not a solver-wide change.

```text
Task:      io_paths.txt single writer under MPI
Scope:     codes/main/src/SimuContextIO.cpp + one existing test target
Do not:    touch Prj.cpp public semantics, build system, or test architecture
Evidence:  serial unchanged; np=2 shows one writer; existing tests pass
```

Why this one:

- the audit already located the defect;
- the fix is small and reviewable;
- it does not need a build refactor, which the project has rejected;
- it produces a report you can compare against the audit finding.

If the existing test target cannot express the multi-rank behavior, do not
pretend it can. Record the missing coverage in the report and provide the
`mpirun -np 2` command and its output as manual evidence.

The second candidate is a small `numerics` task (for example, make an
unimplemented scheme fail fast instead of silently producing zero flux). Do not
start both at once until the first one has gone through the full loop.

---

## 7. Old workflow vs agentlab

| Your old workflow | agentlab |
|---|---|
| `pi` runs in the OneFLOW checkout and edits the working tree | worker runs in a separate git worktree; the main checkout stays clean |
| one long session accumulates context | one session per workstream |
| you inspect the diff afterwards | the worker must commit, or `run_worker` fails |
| no path restriction | edits outside `scope` fail `scope_check` |
| no verification gate | three-state gate: PASS / FAIL / UNVERIFIED |
| no report | report + commit SHA + repro record are required |
| you run tasks serially | workstreams can run in parallel, each in its own worktree |

Cost: you write the task, scope, contracts, and verification.
Benefit: you review a small diff and a report instead of a long conversation.

---

## 8. When not to use agentlab

- "Where is this function?" — native Pi.
- "Why does this compile fail?" — native Pi.
- A one-line fix or a comment — native Pi.
- You have not decided what the deliverable is — native Pi first.

Use agentlab when the deliverable is known and you need isolation, verification,
or a traceable record.

---

## 9. Where things live

```text
~/OneFLOW/.agentlab/               target pack (committed on dev)
  TASKS.md                         human-owned task board
  scope/<ws>.txt                   human-owned write boundary
  contracts/                       human-owned interfaces and data layout
  verification/                     human-owned numerical gate
  reports/                         worker output
  RFC/                             proposals awaiting a human
  repro/                           gate evidence
  target.env                       mode, base ref, modules, commands

../OneFLOW-wt/<ws>/                worker worktree (not in the repo)
../OneFLOW-wt/logs/                worker logs
../OneFLOW-wt/sessions/            worker Pi sessions
../OneFLOW-wt/run/                 detached-worker pid files
```

The main checkout and your daily `~/.pi/agent` are not used by workers.

---

## 10. Known blockers and decisions

| Item | Status | What to do |
|---|---|---|
| `.agentlab/target.env` mode | `audit` | switch to `worker` after 4.1–4.5 |
| `.agentlab/contracts/` | generic starter | replace with OneFLOW's real boundary |
| `.agentlab/verification/run_all.sh` | placeholder | register one real case before integration |
| `UNIT_CMD` | runs all ~1067 CTest cases | narrow with `ctest -R` before regular use |
| `dev` vs `upstream/hexin` | diverged | decide local fork vs upstream-compatible base |
| Test architecture | frozen for v0.1 | do not refactor; add tests in the existing pattern |
| `PRJ`/test source lists | human-owned | do not copy or rewrite them in a worker task |
