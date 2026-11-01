**English** | [中文](governance.zh-CN.md)

# Governance Model (v0.1 implementation status)

## Authorization

- **Campaign mandate**: currently the human-maintained `TASKS.md` plus module `scope/` files.
- **Task mandate**: one `TASKS.md` item plus the module scope.
- Agents cannot expand authorization by creating subtasks.
  v0.1 enforces this through prompts + scope checks; v0.2 moves it into the task engine.

## Four permission levels

| Level | Meaning | v0.1 enforcement |
|---|---|---|
| Autonomous | Read code, work in own worktree, run local tests | Not blocked |
| Conditional | Small refactor, draft commits | Scope + gate |
| Approval | Contract/data-layout/verification changes, merge main, external PR, budget increase | RFC + human merge; **not programmatically enforced** |
| Forbidden | Cross-project access, bypass verification, credential leakage | `scope_check` blocks path escapes; other actions need a guard/sandbox |

## Principles

- Deterministic programs make policy decisions; the model only proposes.
- A lead/reviewer agent's approval is **not** human approval.
- Numerical verification and code review are independent gates.

## Not implemented in v0.1 (v0.2+)

Leases/heartbeats, idempotent execution, contract version numbers, budget metering,
approval queue, event bus, task state machine.
