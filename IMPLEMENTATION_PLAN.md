**English** | [中文](IMPLEMENTATION_PLAN.zh-CN.md)

# Open Research Agents — Consolidated Implementation Plan

> **Living plan.** v0.1 records the initial implementation and its design
> rationale; the roadmap below is the current direction. The repository uses
> `examples/validation/target`, `tests/fixtures/mini-target`, and
> `targets/oneflow`; the current process is in
> [`docs/workflow.md`](docs/workflow.md).

**Status:** Draft v1.0 (consolidated)
**Sources:**
- `cfd-agents-starter.zip`: single-repository CFD scaffold, AGENTS, contracts, scope/gate/integrate scripts
- `agent-lab_1.zip`: `platform/` + `domains/` layering, install_domain, repro_snapshot, governance documents
- Previous `IMPLEMENTATION_PLAN.md` draft: v0.1–v0.5 roadmap
- Review feedback: commit discipline, preflight, core API contract, strict verification, command/push guard, session policy

**First domain:** CFD
**Preferred agent runtime:** Pi
**v0.1 implementation language:** Bash + Markdown (executable specification)
**From v0.2:** TypeScript (orchestrator and task engine)
**Long-term goal:** an open, verifiable, human-governed multi-agent research platform for scientific computing and AI4S

---

## 0. Summary

> **v0.1 = the agent-lab platform/domain split + the starter's CFD contracts and tasks + a real compilable target repository + a stricter gate. Single worker first, then two workers; the TypeScript platform is deferred to v0.2.**

---

## 1. Consolidated decisions

### 1.1 What to adopt

1. **Adopt the `agent-lab` platform/domain split.**
   `platform/` holds generic rules, scripts, and templates; `domains/<domain>/` holds contracts, scope, tasks, verification, and repro fields; `install_domain.sh` installs a domain into a target repository under `.agentlab/`.
   Rationale: platform scripts live outside the target repository, so a worker cannot modify the gate; the same platform can serve OneFLOW, KylinFlow, and other repositories.

2. **Keep the CFD-specific content from `cfd-agents-starter`.**
   The AGENTS rules, `interfaces.md`, `data_layout.md`, `TASKS.md`, scope model, and mock-ODE/MMS decoupled tests are merged into `domains/cfd/`.

3. **Do not write a TypeScript platform in v0.1.**
   Bash scripts are the executable specification. Validate scope → build → unit → verification → integration first, then codify the semantics in a TypeScript orchestrator.
   Rationale: the missing piece is a real C++ project, real verification, and real permission checks, not more platform code.

4. **Add a real target repository.**
   Neither ZIP contains compilable solver code, so a worker cannot run a real task. v0.1 must provide a minimal CFD project in the form of an independent Git repository: `Field/Mesh/Comm + CMake + CTest + one MMS case`.
   It is a fixture for the target repository, not a subdirectory of the platform repository.

5. **Add hard gates.**
   - `preflight.sh`: refuse to start a worker when contracts still contain TODO/[CONFIRM], or core/CMake/unit tests are missing;
   - `gate.sh` has three states: `PASS / FAIL / UNVERIFIED`;
   - the integration gate requires `G3 numerical = PASS`; the worker gate may allow `UNVERIFIED`, but the report must state it;
   - the worker must commit to `agent/<module>` and record the commit SHA in the report;
   - `guard.ts` + `pre-push`: block `sbatch/srun`, `git push`, and `gh pr merge`;
   - session policy: choose `--session-id` or `--no-session` explicitly; do not accumulate unbounded sessions.

### 1.2 Out of scope

v0.1 does not include:

- an implicit time integrator (T3 remains `blocked`; write an RFC first);
- MPI/GPU parallel performance optimization (a separate serial task after correctness is green);
- a TypeScript task engine / SQLite / approval queue;
- multiple projects, multi-tenancy, or a web panel;
- automatic merging of critical solver code;
- automatic submission of HPC cluster jobs;
- cross-project long-term memory;
- agent approval of other agents.

---

## 1A. v0.1 target adaptation: OneFLOW instead of cfd-mini

- The real target repository is OneFLOW; `tests/fixtures/mini-target` is only a platform smoke-test fixture.
- OneFLOW is a runtime/task codebase, not the starter's clean spatial/temporal split. Letting two workers edit code immediately would create overlapping scopes.
- v0.1 starts with two read-only audit workers:
  - `runtime-io`: `codes/main/`, `codes/io/`, `tests/main/`, `tests/io/`, `doc/AI_CONTEXT.md`
  - `numerics`: `codes/ns/`, `codes/residual/`, `codes/grad/`, `codes/solver/`, `codes/lhs/`, `codes/time/`, `codes/unsteady/`, `codes/update/`, relevant tests
- Audit outputs: entry points and callers, state and resource ownership, shared files, test coverage, missing contracts, risks, a proposal for disjoint scopes, and one question for the human.
- After the human confirms scopes and contracts, change `AGENTLAB_MODE` in `target.env` from `audit` to `worker`, then start code tasks.
- This avoids premature parallel editing in a tightly coupled codebase such as OneFLOW.

### 1A.1 First audit record (2026-11-01)

- OneFLOW `.agentlab/` is installed and committed on `dev` (`7328dc504`).
- Both read-only audits ran and were merged into `dev` (merge commits `883640c07`, `94a7161b8`):
  - `runtime-io`: a 369-line report + RFC; found the missing multi-rank writer filter for `io_paths.txt`, no test for `TeardownCase`, and duplicated test source lists.
  - `numerics`: a 449-line report + RFC; found the empty `HybridRoe()` implementation, bounds regression in `linearTwoStepMethods`, `SolverState::Converge()` returning true unconditionally, no instantiated numerical-loop tests, and no explicit-RK baseline.
- Both reports remain at `need_decision`/`ready`; neither claims that an unexecuted test passed.
- **Decision (2026-11-01): do not refactor the target repository's test architecture.**
  The shared `oneflow_case_runtime` target proposed by runtime-io is rejected.
  The `TeardownCase` coverage gap is recorded as a known issue for a human to
  prioritize. Rationale: this is a build refactor of a large repository with no
  independent performance or correctness benefit, and with high risk in compile
  definition propagation. It is human-owned work. See
  `platform/docs/decisions/0002-no-test-architecture-refactor.md`.
- Workers may add tests only in the existing pattern: one test target lists the
  production sources it needs; no new test entry point and no build-system change.
- Next step: the human confirms two disjoint code workstreams and switches
  `AGENTLAB_MODE` to `worker`. This execution work can proceed in parallel with
  the next product milestone, the v0.2 Attention Inbox.

## 2. Overall architecture

```text
Human Principal
      │ authorization, approval, priorities
      ▼
Lead / Reviewer (v0.1 = human-operated Pi main session, read-only capable)
      │
      ▼
Platform (outside the target repository; workers cannot modify it)
  - scope_check / preflight / gate / integrate
  - run_worker / repro_snapshot / guard
  - templates and governance documents
      │
      ▼
Target Repo
  .agentlab/            ← installed by install_domain.sh
    AGENTS.md
    contracts/
    scope/
    TASKS.md
    verification/
    reports/
    RFC/
    repro/
    sessions/
  core/                 ← CFD numerical foundation, human-owned, worker read-only
  modules/spatial/      ← Worker A
  modules/temporal/     ← Worker B
  tests/
      │
      ▼
Gates
  G0 scope → G1 build → G2 unit → G3 numerical → G4 integration → G5 performance
      │
      ▼
Integration branch → Human approval → main
```

### 2.1 Repository layout

```text
open-research-agents/
├── platform/
│   ├── AGENTS.md
│   ├── scripts/
│   │   ├── preflight.sh
│   │   ├── scope_check.sh
│   │   ├── gate.sh
│   │   ├── run_worker.sh
│   │   ├── integrate.sh
│   │   ├── repro_snapshot.sh
│   │   └── install_domain.sh
│   ├── extensions/
│   │   └── guard.ts
│   ├── templates/
│   │   ├── report.md
│   │   ├── rfc.md
│   │   └── decision.md
│   └── docs/
│       ├── domain-pack-spec.md
│       ├── governance.md
│       └── verification.md
│
├── domains/
│   └── cfd/
│       ├── domain.env
│       ├── AGENTS.domain.md
│       ├── contracts/
│       │   ├── interfaces.md
│       │   ├── data_layout.md
│       │   └── core_api.md
│       ├── scope/
│       │   ├── spatial.txt
│       │   └── temporal.txt
│       ├── TASKS.md
│       ├── verification/
│       │   ├── README.md
│       │   ├── run_all.sh
│       │   └── cases/
│       └── repro_fields.yaml
│
├── examples/
│   └── cfd-mini/          # standalone Git repository skeleton for demo/CI
│       ├── CMakeLists.txt
│       ├── core/
│       ├── modules/
│       ├── tests/
│       └── .gitignore
│
├── tests/                 # platform script tests
├── docs/
├── AGENTS.md
├── README.md
└── IMPLEMENTATION_PLAN.md
```

**Naming clarification:**

- `platform/`: platform kernel (scripts, rules, templates), not the CFD numerical core;
- `domains/cfd/`: CFD domain pack;
- `core/` inside the target repository: CFD `Field / Mesh / Comm`, human-owned, agent read-only;
- `.agentlab/` inside the target repository: installed domain pack location; workers read contracts and verification but cannot modify them.

---

## 3. Roles and permissions

| Role | v0.1 owner | Responsibility | Prohibited |
|---|---|---|---|
| Human Principal | You | Fill contracts, confirm interfaces, register verification, approve merges | — |
| Lead / Reviewer | Your Pi main session | Decompose tasks, review diffs, run the integration gate, recommend approvals | Do not edit module code directly; do not approve on behalf of a human |
| Worker Spatial | `pi -p` / `pi --session-id` | Implement spatial discretization, tests, report, commit | Do not modify core/contracts/scripts/verification; do not push/merge |
| Worker Temporal | Same | Implement time integration, mock-ODE tests, report, commit | Same |
| Platform | Bash scripts | Deterministic scope/gate/integrate/repro execution | No technical judgment |

**Separation of duties:**

- Workers write code;
- the Lead/Reviewer reviews;
- the human approves contracts, verification baselines, and merges to main;
- no agent approval is equivalent to human approval.

---

## 4. CFD v0.1 contracts

### 4.1 Data layout (human-owned)

`domains/cfd/contracts/data_layout.md` keeps the TODO list, but v0.1 must make these minimum decisions first:

- structured 1D mesh;
- fixed conserved-variable order;
- fixed ghost width;
- AoS (simpler for v0.1; SoA requires a later RFC);
- `double`;
- MPI disabled initially; `Comm` provides a serial no-op and an interface placeholder for `mpirun -np 4`.

**A worker must not start before `data_layout.md` is complete.**

### 4.2 Core API (new `contracts/core_api.md`)

The two ZIPs provide only class names (`Field/Mesh/Comm`), not methods. A worker would guess, and spatial/temporal would each invent a different surface. v0.1 must fix the minimum API:

```cpp
namespace cfd {

class Field {
public:
  double* data();
  const double* data() const;
  std::size_t size() const;

  Field like() const;                    // same layout, uninitialized
  void copy(const Field& other);
  void axpy(double a, const Field& x);   // this += a*x
  double norm2() const;
};

class Mesh {
public:
  int dim() const;
  int nx() const;
  int ny() const;
  int nz() const;
  double dx() const;
  double dy() const;
  double dz() const;
  bool periodic(int axis) const;
  std::size_t cellCount() const;
  std::size_t ghostWidth() const;
};

class Comm {
public:
  void haloExchange(Field& field) const;
  double allreduceMin(double value) const;
  double allreduceSum(double value) const;
};

} // namespace cfd
```

Rules:

- `Field::like/copy/axpy/norm2` are required in v0.1; temporal RK must not invent its own;
- `Mesh` is read-only; for structured 1D, 2D/3D methods may return 1;
- `Comm` is a no-op in serial mode; MPI implementation is deferred to v0.2;
- workers must not modify `core/`.

### 4.3 Module interfaces (corrected)

```cpp
namespace cfd {

class ISpatialOperator {
public:
  virtual ~ISpatialOperator() = default;

  // Compute residual R; U is read-only.
  // Halo exchange is performed by spatial inside residual; the caller does not pre-exchange.
  virtual void residual(const Field& U, double t, Field& R) const = 0;

  // Local stability time-step limit (CFL=1).
  // The global minimum is reduced by the time integrator through Comm.
  virtual double max_stable_dt(const Field& U, double t) const = 0;
};

class ITimeIntegrator {
public:
  virtual ~ITimeIntegrator() = default;

  // Advance U in place; update t; dt is provided by the caller.
  // comm is used for the global reduction of max_stable_dt.
  virtual void advance(Field& U, double& t, double dt,
                       const ISpatialOperator& L, Comm& comm) = 0;

  virtual int order() const = 0;
};

} // namespace cfd
```

Conventions that must be confirmed:

- `dU/dt = R(U,t)`, and `R` includes the sign and cell-volume normalization;
- `U` is read-only; `R` is output;
- halo exchange is spatial's responsibility;
- boundary conditions are represented by spatial through `residual()`;
- `max_stable_dt` is a spatial stability suggestion, not the final dt;
- time-step clipping is temporal's responsibility;
- RK work arrays are allocated by temporal with `Field::like()`.

**Before confirmation, a worker may only write `need_decision`; it must not guess.**

### 4.4 Decoupled tests

- Temporal: `tests/mocks` provides linear/nonlinear ODE operators that implement `ISpatialOperator`, verifying time order;
- Spatial: MMS manufactured solutions compare `residual()` with the analytic time derivative, verifying spatial order;
- Integration is performed only on the integration branch with real verification cases.

---

## 5. Gates and verification

### 5.1 Gate layers

| Gate | Content | Result |
|---|---|---|
| G0 | Scope check: added/deleted/renamed/untracked files | PASS / FAIL |
| G1 | Compilation and static checks | PASS / FAIL |
| G2 | Unit tests (`ctest -L unit`) | PASS / FAIL |
| G3 | Numerical verification (MMS/ODE/conservation) | PASS / FAIL / **UNVERIFIED** |
| G4 | Integration regression | PASS / FAIL |
| G5 | Performance benchmark | PASS / FAIL / N/A |

**Key rules:**

- When no verification case is registered, G3 must be `UNVERIFIED`, never `PASS`;
- the worker gate may allow `UNVERIFIED`, but the report must state it and must not claim numerical correctness;
- the integration gate requires `G3 = PASS`; integration must fail without a real case;
- only when `G0–G4` all pass may the change enter human approval.

### 5.2 `gate.sh` three states

```bash
# worker: allow G3 UNVERIFIED
scripts/gate.sh spatial

# integration: require G3 PASS
GATE_MODE=integration scripts/gate.sh
```

Implementation guidance:

- `GATE_MODE=worker|integration|release`;
- `run_all.sh` returns `exit 1` when `GATE_MODE=integration` and no case is registered;
- at the end, the gate writes `.agentlab/repro/last-gate.json`: `{mode, status, module, at}`;
- `repro_snapshot.sh` reads that file and writes the complete repro record.

### 5.3 Repro records

Every numerical or performance conclusion must write `.agentlab/repro/<label>-<timestamp>.json`, containing at least:

```json
{
  "label": "spatial-S1",
  "gate_mode": "worker",
  "gate_status": "unverified",
  "git_commit": "<sha>",
  "git_branch": "agent/spatial",
  "git_dirty": false,
  "pi_version": "<version>",
  "model": "<provider/model>",
  "host": "<host>",
  "compiler": "<c++ --version>",
  "cmake": "<cmake --version>",
  "mpi": "<mpirun --version or none>",
  "commands": ["..."],
  "case": { "name": "mms-1d", "input_hash": "<sha256>" },
  "metrics": { "error_l2": null, "observed_order": null, "elapsed_seconds": null },
  "result": "unverified"
}
```

The field template is in `domains/cfd/repro_fields.yaml`; verification cases write `*.case.json`.

### 5.4 Report template

`platform/templates/report.md` includes:

```text
status: ready | blocked | need_decision
commit:
branch:
model:
pi_version:
gate_mode:
gate_status:
gate tail:
repro files:
```

`ready` means "ready for integration review"; it does not mean "numerically verified".

---

## 6. Collaboration and workflow

### 6.1 Worker single-turn flow

```text
preflight → read AGENTS/contracts/scope/TASKS
  → do only the first todo for this module
  → write tests first
  → implement
  → gate (worker mode)
  → git add scoped files + commit to agent/<module>
  → write report (with commit SHA)
  → stop
```

**A commit is mandatory.** Otherwise `integrate.sh` has no change to merge.

**Pushing is prohibited.** A `pre-push` hook or command guard blocks it.

### 6.2 Scope check

`scope_check.sh` must cover:

- committed diff: `git diff --name-only "$BASE"...HEAD`;
- working-tree diff: `git diff --name-only`;
- untracked files: `git ls-files --others --exclude-standard`;
- deletions and renames: Git reports them; test cases must cover them;
- `BASE` must be fetched first to avoid a stale main;
- the scope file is read from `BASE`, so the worker cannot modify it;
- restrict RFC/repro paths to `.agentlab/RFC/<module>-*` and `.agentlab/repro/<module>-*` to avoid cross-module overwrites.

### 6.3 Integration

`integrate.sh`:

1. checks that the working tree is clean;
2. runs `git fetch`;
3. runs `git checkout -B integration main`;
4. merges `agent/<module>` in `MODULES` order;
5. aborts on conflict and asks the worker to rebase on the latest main;
6. runs `GATE_MODE=integration scripts/gate.sh`;
7. leaves the result on `integration` for human review;
8. the human merges to `main` after approval.

**v0.1 does not allow automatic merging to main.**

### 6.4 Periodic interaction

v0.1 collaboration is **asynchronous**: workers interact through `TASKS.md`, `contracts/`, `RFC/`, and `reports/`; they do not chat freely.

If periodic synchronization is required, add `scripts/sync.sh` (v0.1.1):

```text
You are the spatial responsible agent. Do not modify code.
Read .agentlab/reports/temporal.md, contracts/, and git log integration..agent/temporal.
Output:
1. Whether you are affected
2. Whether an RFC is needed
3. Recommended next step
Write to .agentlab/reports/sync-<date>-spatial.md
```

Run it once per worker; a human or a read-only lead summarizes the decisions.

---

## 7. Security and permissions

### 7.1 Enforcement points

| Stage | Enforcement |
|---|---|
| Before worker start | `preflight.sh` validates contracts/scope/core/CMake/unit tests |
| Tool call | `guard.ts` blocks `sbatch/srun`, `git push`, `gh pr merge` |
| Before commit | `scope_check.sh` validates the file scope |
| Before integration | `gate.sh` validates build/unit/verification |
| Before merge/release | Human approval |

### 7.2 Boundaries

- Git path checks are **necessary but not sufficient**;
- `guard.ts` is a **convention-level guard**, not a sandbox; a worker with Bash access can still bypass it;
- real isolation requires a container, a dedicated OS user, or an execution gateway;
- high-risk projects (chip code, production repositories) must use a dedicated account or container and restricted credentials;
- do not submit HPC jobs; write large-case commands in the report for a human to execute.

### 7.3 Pi-specific protections

- `run_worker.sh` loads `-e "$PLATFORM/extensions/guard.ts"`;
- the target repository installs a `pre-push` hook that allows only `agent/*` branches;
- workers use `--session-id "agentlab-$MODULE"` or `--no-session`;
- workers do not load unnecessary MCP servers or extensions; the default tool set is sufficient;
- record `pi --version` and the model in the repro record.

---

## 8. Roadmap

The direction is **attention governance first**. The execution layer already
exists: a Pi worker, an isolated worktree, scope enforcement, a three-state gate,
and a report. The remaining work is the control plane that decides what deserves
human attention and what work is authorized.

Absorb dsh-superagent in layers. Do not adopt DSH as the runtime. Each phase
ships independently and leaves the previous one usable.

### v0.1 — manual task harness (done)

- Pi worker in a worktree, independent session, scope, gate, report, repro.
- OneFLOW target in audit mode; two read-only audits completed.
- Platform and target packs; 48 smoke checks and 27 harness checks.

Limitation: the human still decides what enters attention. There is no Source,
Mandate, Ticket, Outbox, or attention view.

### v0.2 — Attention Inbox (next)

Goal: reduce attention cost before adding autonomy.

- `agentlab inbox`: classify items as `pending`, `review`, or `fyi`.
- Sources of items:
  - `reports/*.md` with `status: need_decision`;
  - `RFC/*.md` with `Status: proposed`;
  - gate `FAIL` or `UNVERIFIED`;
  - worker failures and interrupted runs.
- `agentlab decide <id>`: record a decision and return it to the task board.
- Attention policy: per type, choose `never`, `digest`, or `immediate`; cap the
  number of questions per task.

Acceptance: one command shows only what needs a human; classification is
deterministic; no model calls; no new Source or autonomous action.

### v0.3 — Mandate-lite and Ticket-lite

Goal: make authorization explicit without importing the full dsh domain.

- A task becomes a ticket with `source`, `sender`, `strength`
  (`explicit`/`inferred`), `rule`, `policy_version`, `scope`, `status`, and
  `assignments`.
- Policy version hash; revalidate before resuming an ended ticket.
- Ticket lifecycle: `proposed → authorized → running → review/blocked → ended`;
  resume and stop are explicit commands.
- Keep scope and gate as the enforcement layer.

Acceptance: every ticket records why it is allowed; resume revalidates the
mandate; no ticket can widen its own scope.

### v0.4 — Source and Trigger (GitHub first)

Goal: let work enter from an event stream without losing control.

- One Source: GitHub notifications (read-only intake).
- Trigger deduplication and Thread grouping; store the source payload.
- Admission starts in `observe` mode: events become candidates in the Inbox, not
  tickets. A human approves before work starts.
- `agentlab source` configuration and health.

Acceptance: a GitHub mention creates one candidate with sender, strength, and
policy version; duplicate events are ignored; no automatic ticket creation.

### v0.5 — Outbox and Channel

Goal: make external communication durable and idempotent.

- Outbox: write before send, retry with backoff, receipts.
- One Channel: GitHub comments/replies.
- No auto-merge; replies are limited to the ticket's source thread.

Acceptance: a reply is sent once, retries do not duplicate comments, and a failed
send is visible in `status`.

### v0.6 — Ticket execution parity

Goal: match dsh-superagent's execution semantics where they matter for solo work.

- Per-ticket session and workspace, instead of per-workstream.
- Subscriptions and follow-ups: a human message on the ticket thread resumes it.
- Stop, retry, restart, and policy revalidation.
- Background work and long-running job limits.

Acceptance: a ticket survives restart, a follow-up resumes it, and a stopped
ticket receives no automatic input.

### v0.7 — Multi-target and attention view

Goal: manage more than one repository without multiplying attention.

- Multiple targets under one workspace.
- One Inbox across targets, grouped by target and attention type.
- Optional terminal or web attention view; no full activity dashboard.

Acceptance: two targets share one Inbox; a worker in target A cannot write to
target B.

### v0.8 — Bounded autonomy

Goal: allow proactive work only after the attention and authorization layers are
proven.

- Campaign: a long-term objective across tickets.
- Budgets: workers, model cost, GPU hours.
- Task permissions are a subset of campaign permissions.
- Auto-accept only for rules whose observe-mode precision is measured and
  accepted by a human.
- High-risk actions still require human approval.

Acceptance: budgets are enforced; auto-accept is limited to allowlisted rules;
every decision is auditable.

## 8A. What to reuse from dsh-superagent

dsh-superagent is a reference implementation of the control plane. Reuse its
concepts and selected core code under the MIT license; do not adopt DSH as the
runtime.

| dsh-superagent | agentlab phase | Reuse | Do not reuse |
|---|---|---|---|
| Attention philosophy (`docs/000`) | all | Principles: act only when asked or allowed, speak only when a person must act, one question at a time, honest reporting | — |
| Domain model (`docs/001`) | v0.3, v0.6 | Trigger, Thread, Ticket, Mandate, Subscription, Assignment | Full multi-user admission model for solo use |
| Execution model (`docs/003`) | v0.6 | Per-ticket session/workspace, resume, stop, revalidation | DSH presets, DSH job/subagent services |
| `src/core` | v0.3, v0.6 | Domain types and pure rules | DSH-specific glue |
| `src/policy.ts` | v0.3 | Gate, policy version, revalidation | Multi-user allowed lists as-is |
| Outbox / Effects patterns | v0.5 | Write-before-send, receipts, retry, idempotency | DSH channel implementations |
| Panel / attention routing | v0.2, v0.7 | Order by "needs a person"; hide healthy state | DSH Web client |
| DSH executor and presets | — | — | Do not port |
| DSH Source plugins | v0.4 | Event shape and deduplication ideas | Do not depend on DSH plugins |

Rules:

- Keep `platform/`, `domains/`, and `targets/` free of DSH types.
- Reuse code only when it has no DSH dependency; otherwise reimplement the
  concept.
- Preserve the MIT copyright notice for copied code.
- Do not add DSH as a dependency of the platform.
- If a phase cannot ship without DSH, stop and record the reason; do not silently
  couple the runtimes.

## 9. Sprint plan

> Sprints 0–4 record the original v0.1 implementation. The roadmap in Section 8
> supersedes them for future work.

### Sprint 0: review and foundation (1–2 days)

- review all scripts and documents in the two ZIPs;
- create the `open-research-agents/` repository skeleton;
- create `examples/cfd-mini` as an independent Git repository;
- merge `domains/cfd/`;
- implement `install_domain.sh` for `cfd-mini`;
- add `preflight.sh`;
- add a root `AGENTS.md` pointer (Pi loads the root `AGENTS.md` automatically; it does not load `.agentlab/AGENTS.md` automatically).

**Deliverable:** `cfd-mini` compiles, `.agentlab` is installed, and preflight rejects empty contracts.

### Sprint 1: single-worker vertical slice (3–5 days)

- fill `data_layout.md`;
- confirm every `[CONFIRM]` in `interfaces.md`;
- write `core_api.md` and implement the minimum `Field/Mesh/Comm`;
- root `CMakeLists.txt` and `ctest -L unit` labels;
- register one real MMS spatial convergence case;
- run Spatial S1;
- inspect scope/gate/report/commit/repro;
- fix script issues.

**Deliverable:** a single worker completes a real development task and produces a credible report that explicitly states the `G3` status.

### Sprint 2: two workers and integration (3–5 days)

- Temporal T1 (mock ODE, Forward Euler + SSPRK3);
- two worktrees in parallel;
- merge with `integrate.sh`;
- run G0–G4 with `GATE_MODE=integration`;
- human review;
- merge to main.

**Deliverable:** a reproducible two-agent CFD demo.

### Sprint 3: hardening and v0.1 release (1–2 weeks)

- `guard.ts` + `pre-push`;
- `sync.sh`;
- scope covers deletions/renames/untracked files;
- platform script tests;
- quickstart, governance documentation, known limitations;
- open-source license and dependency review.

### Sprint 4: v0.2 task engine (2–3 weeks)

- TypeScript platform;
- SQLite;
- task state machine;
- message protocol;
- RFC/approval;
- recovery and idempotency.

---

## 10. v0.1 acceptance criteria

- [ ] `examples/cfd-mini` builds and runs `ctest` independently;
- [ ] `install_domain.sh cfd <repo>` installs `.agentlab/` without overwriting edited files;
- [ ] `preflight.sh` fails when contracts contain TODO/[CONFIRM] or core/CMake/unit tests are missing;
- [ ] Spatial S1 is completed in an independent worktree and passes scope checks;
- [ ] Temporal T1 is verified independently with mock ODE operators, without spatial;
- [ ] two workers run concurrently without shared-file write conflicts;
- [ ] out-of-scope changes (add/delete/rename/untracked) are rejected by `scope_check`;
- [ ] `guard.ts` blocks `sbatch/srun`, `git push`, and `gh pr merge`;
- [ ] the worker must commit; the report contains the commit SHA;
- [ ] the worker gate may allow `G3=UNVERIFIED`, but the report states it explicitly;
- [ ] the integration gate fails without a real verification case;
- [ ] after G0–G4 pass on integration, human approval is required before merging to main;
- [ ] the repro record contains commit, compiler, hardware, model, Pi version, and commands;
- [ ] the quickstart allows a new user to complete a single-worker run within 30 minutes.

---

## 11. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Empty verification, gate false positives | `G3=UNVERIFIED`; integration requires a real case |
| Implicit schemes create strong interface coupling | T3 blocked; RFC the Jacobian interface first |
| Worker does not commit, integration has no change | AGENTS + post-run `git status`/`git rev-list` checks |
| Scope checks paths but not commands | `guard.ts` + pre-push; containers for high-risk work |
| `pi -p` is stateless across turns | explicit `--session-id` or `--no-session`; the report is the memory |
| Build resource contention | `-j` limit, ccache/sccache, GPU/FPGA resource locks |
| Agent overconfidence | numerical gate + human review; no "the LLM said it passed" |
| Platform/domain coupling | domain pack spec; verify with a second domain |
| Pi version drift | pin the version + smoke tests; depend only on public APIs |
| Overbuilding the platform | v0.1 stays Bash; TypeScript is deferred to v0.2 |

---

## 12. First-round instructions for the coding agent

You are the implementation agent for this project. The first round covers **Phase 0 + the single-worker vertical slice** only. Do not start Phase 2.

### 12.1 Required behavior

1. Review the two ZIPs and the current repository first; do not assume the scripts already work;
2. do not modify human-owned content in `domains/cfd/contracts/`; when an interface is unclear, write an RFC/`need_decision`;
3. do not loosen tolerances, skip tests, or delete failing tests;
4. do not submit HPC jobs, push, or merge;
5. mark unexecuted tests as `Not Run`;
6. reuse the existing starter instead of rewriting the platform;
7. keep `platform/` and `domains/` separate.

### 12.2 Execution order

1. Output the current repository structure and an issue list;
2. create the `open-research-agents/` skeleton;
3. create `examples/cfd-mini`;
4. merge `domains/cfd/`;
5. implement `preflight.sh`;
6. confirm the minimum CFD interface + `core_api.md`;
7. implement the minimum `Field/Mesh/Comm` + CMake + CTest;
8. register one real MMS case;
9. run Spatial S1;
10. inspect scope/gate/report/commit/repro;
11. output recommendations for the next two-worker round.

### 12.3 Per-round output format

```text
Summary
Files Changed
Contracts Affected
Tests Executed
Numerical Verification
Known Risks
Pending Approvals
Next Tasks
```

---

## 13. Differences from the two ZIPs

| Item | `cfd-agents-starter` | `agent-lab_1` | Consolidated plan |
|---|---|---|---|
| Directory structure | `coordination/` inside one repository | `platform/` + `domains/` + install into `.agentlab/` | **Use agent-lab** |
| Platform location | Inside the repository; workers can modify it | Outside the repository; workers cannot modify it | **Use agent-lab** |
| Multiple projects | Not supported | Domain packs reusable | **v0.3** |
| CFD contracts | Detailed | Same source | **Keep, add `core_api.md`** |
| Core API | Undefined | Undefined | **Add** |
| Verification | Placeholder | Placeholder | **Three-state + strict integration** |
| Repro records | None | `repro_snapshot.sh` | **Adopt; add Pi/model/commands** |
| Worker commit | Not required | Not required | **Required** |
| Preflight | None | None | **Add** |
| Command interception | AGENTS only | AGENTS only | **Add guard + pre-push** |
| Session policy | Unspecified | Unspecified | **Explicit `--session-id`/`--no-session`** |
| Compilable example | None | None | **Add `examples/cfd-mini`** |
| Platform language | Bash | Bash | **v0.1 Bash; v0.2 TypeScript** |
| Task engine | None | Documented as not implemented | **v0.2** |
| Governance documentation | Minimal | `governance.md` states what is not enforced | **Keep; map to v0.2+** |

---

## 14. Final success criteria

Success is not measured by the number of agents, but by these capabilities:

1. multiple agents can safely collaborate on scientific software;
2. interface conflicts and out-of-scope changes are prevented;
3. numerical correctness can be verified independently;
4. interrupted long-running tasks can be recovered;
5. multiple independent research repositories can be managed;
6. research can proceed within explicit authorization and bounded budgets;
7. the system can extend to other AI4S domains through Domain Packs;
8. daily human attention is bounded, visible, and spent only on decisions or
   usable results.

**Strategy:**

> CFD First → Verified Multi-Agent Development → Multi-Project Coordination → Bounded Autonomous Research → Open AI4S Platform.

**First-round authorization:**

> Complete Phase 0 and the single-worker vertical slice only. After real C++ compilation, numerical verification, and scope/gate/commit/repro all pass, start the Spatial/Temporal two-worker round.
