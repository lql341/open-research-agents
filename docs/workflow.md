# Developing a target repository with agentlab

Status: v0.1  
Audience: a solo developer who is used to `cd <repo> && pi` and typing requests in
natural language.

`agentlab` does not replace Pi. It adds four things around a normal Pi session:
a **task**, an **isolated worktree**, a **gate**, and a **commit + report**.

If you only want the first successful run, start with
[`quickstart.md`](quickstart.md). This page is the full process and is
target-neutral. For a complete worked example, see the
[OneFLOW target guide](../targets/oneflow/WORKFLOW.md).

---

## 1. Three ways to work

| Mode | Command | Use it for | Gate / report |
|---|---|---|---|
| **Native Pi** | `cd <repo> && pi` | reading code, exploring, one-off edits, questions | none; you review |
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
agentlab run <ws> "Keep the existing serial output byte-identical."
```

For open-ended conversation in the same worktree:

```bash
agentlab pi <ws>
```

---

## 2. What a target pack is

The repository has three layers:

```text
platform/               generic: rules, scripts, gates, CLI
domains/<domain>/       reusable domain rules: contracts, validation, fields
targets/<target>/       repository-specific overlay: paths, branch, commands
```

A domain is reusable across repositories. A target is one concrete repository.
`agentlab install <domain> <target> <repo>` copies both into `<repo>/.agentlab/`;
the target overlay wins where the two overlap.

A target pack normally provides:

```text
targets/<target>/
  target.env            TARGET, BASE_REF, mode, workstreams, commands
  AGENTS.target.md      repository-specific rules
  TASKS.md              human-owned task board
  scope/<ws>.txt        write boundary per workstream
  verification/         real numerical/regression gate
  contracts/            optional repository-specific contracts
```

The generic specification is
[`platform/docs/target-pack-spec.md`](../platform/docs/target-pack-spec.md).

---

## 3. Before the first task

Install the pack and commit it. `scope_check` reads the scope from the base ref,
so an uncommitted `.agentlab/` cannot protect anything.

```bash
agentlab install <domain> <target> <repo>
cd <repo>
git add .agentlab AGENTS.md
git commit -m "agentlab: add <target> pack"
agentlab status
```

If the repository is unfamiliar, start in `audit` mode. A worker may then only
write:

```text
.agentlab/reports/<ws>.md
.agentlab/RFC/<ws>-*
.agentlab/repro/<ws>-*
```

No code, no build, no tests. Use the audit to map entry points, ownership,
shared files, test coverage, and risks. Read the reports and RFCs before asking
for code changes.

---

## 4. Switch from audit to worker

### 4.1 Answer the open RFCs

RFCs are proposals written by workers. Only a human changes their status.
Reject the ones you do not want, and record the decision in the RFC or a
`platform/docs/decisions/` entry.

### 4.2 Write one task

Edit `.agentlab/TASKS.md`. A worker does the first `todo` for its workstream.
A task needs a deliverable and acceptance criteria, not "improve this".

```markdown
## <ws>

- R1 [todo] <one concrete deliverable>.

  Scope:
  - <exact source path>
  - <existing test target>

  Acceptance:
  - <observable behavior that must not change>;
  - <new behavior that must be true>;
  - existing related tests pass;
  - <what must not be touched>.
```

### 4.3 Narrow the scope

`.agentlab/scope/<ws>.txt` starts as report-only. Replace it with the exact
source and test paths the task needs:

```text
# .agentlab/scope/<ws>.txt
<path/to/source.cpp>
<path/to/test.cpp>
.agentlab/reports/<ws>.md
.agentlab/RFC/<ws>-*
.agentlab/repro/<ws>-*
```

Do not add whole directories. Scope is the enforcement mechanism; a broad scope
makes the gate decorative.

### 4.4 Contracts and verification

| File | What it must contain |
|---|---|
| `.agentlab/contracts/` | The repository's real boundary for this workstream, not generic starter text. Replace `TODO` / `[CONFIRM]`. |
| `.agentlab/verification/run_all.sh` | A real case: exit `0` PASS / `1` FAIL / `2` UNVERIFIED. |

Rules:

- Do not loosen tolerances to make a gate pass.
- Do not invent a second baseline when the repository already has one.
- If verification is still a placeholder, `worker` gates will be `UNVERIFIED`
  and `integration` will refuse them. That is intentional.

### 4.5 Build and test commands

`.agentlab/target.env` holds the candidate commands:

```text
BUILD_CMD   <configure + build>
UNIT_CMD    <targeted unit/contract test command>
VERIFY_CMD  <numerical/regression gate>
```

Check them on this machine before switching. If the target's full test suite is
huge, narrow `UNIT_CMD` with the target's own selection mechanism (for example
`ctest -R`, `pytest -k`, `go test -run`). That is a command configuration, not a
test-architecture change.

### 4.6 Switch the mode

```bash
cd <repo>
sed -i '' 's/^AGENTLAB_MODE=audit/AGENTLAB_MODE=worker/' .agentlab/target.env
# Linux: sed -i 's/^AGENTLAB_MODE=audit/AGENTLAB_MODE=worker/' .agentlab/target.env

git add .agentlab
git commit -m "agentlab: enable worker mode for <ws>"
agentlab preflight <ws>
```

`preflight` must pass before you spend a worker turn.

---

## 5. Run, review, integrate

```bash
cd <repo>

# 1. start a worker in the background
agentlab run <ws> --detach

# 2. follow it
agentlab status
tail -f ../<repo>-wt/logs/<ws>-detached-*.log

# 3. inspect what it changed
cd ../<repo>-wt/<ws>
git diff --stat <base>...HEAD
cat .agentlab/reports/<ws>.md

# 4. continue interactively if needed
agentlab pi <ws>

# 5. gate the worker branch (default: the worktree)
agentlab gate <ws>

# 6. integrate and run the integration gate
cd <repo>
agentlab integrate <ws>

# 7. human review, then merge
git checkout <base>
git merge --no-ff integration
```

Important:

- `agentlab gate <ws>` defaults to the **worker worktree**. The base checkout may
  still hold the unimplemented stub, so gating it could produce a misleading
  `UNVERIFIED`. Use `--here` only when you mean the current checkout.
- `agentlab integrate` refuses a dirty tree. Untracked `.agentlab/repro/*.json`
  records are the only exception; they are committed with the integration.
- `agentlab status` shows `WORKTREE=repro` when the only uncommitted files are
  gate records.

---

## 6. Shape of a good first task

A first task should be small, scoped, and provable with the target's existing
tests:

```text
Task:      <one defect or one small capability>
Scope:     <one or two source files> + <one existing test target>
Do not:    rewrite shared foundations, build system, or test architecture
Evidence:  <existing behavior unchanged>; <new behavior true>; tests pass
```

If the existing test target cannot express the new behavior, do not pretend it
can. Record the missing coverage in the report and provide the exact command and
output as manual evidence.

The second task should be in a different workstream only after the first one has
gone through the full loop: worker → gate → integration → human merge.

---

## 7. Old workflow vs agentlab

| Your old workflow | agentlab |
|---|---|
| `pi` runs in the repository checkout and edits the working tree | worker runs in a separate git worktree; the main checkout stays clean |
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
<repo>/.agentlab/                  installed target pack (committed)
  TASKS.md                         human-owned task board
  scope/<ws>.txt                   human-owned write boundary
  contracts/                       human-owned interfaces and data layout
  verification/                    human-owned numerical gate
  reports/                         worker output
  RFC/                             proposals awaiting a human
  repro/                           gate evidence
  target.env                       mode, base ref, workstreams, commands

../<repo>-wt/<ws>/                 worker worktree (not in the repository)
../<repo>-wt/logs/                 worker logs
../<repo>-wt/sessions/             worker Pi sessions
../<repo>-wt/run/                  detached-worker pid files
```

The main checkout and your daily `~/.pi/agent` are not used by workers.

---

## 10. Known blockers

| Item | What to check |
|---|---|
| Mode | `AGENTLAB_MODE=audit` until scopes and verification are ready |
| Contracts | generic templates fail `worker` preflight; replace `TODO` / `[CONFIRM]` |
| Verification | placeholder → `worker` gate `UNVERIFIED`, `integration` refuses |
| Unit command | full suite may be too slow; narrow it with the target's own selector |
| Base branch | target workers branch from `BASE_REF`; keep it in sync with the target's policy |
| Test architecture | do not refactor it as part of a code task |
| Shared foundations | keep them human-owned; do not widen scope to "just fix it" |
