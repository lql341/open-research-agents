# Platform rules (all agents, all domains)

1. Only modify files allowed by `.agentlab/scope/<module>.txt`. Out-of-scope changes fail `scope_check`.
2. Do not modify `.agentlab/contracts/`, `.agentlab/verification/`, platform scripts, or verification baselines/tolerances.
   Need a change -> write `.agentlab/RFC/<date>-<module>-<topic>.md`, set report status `need_decision`, and stop.
3. Completion requires `gate.sh <module>` to pass as specified for the mode, and a **commit** on `agent/<module>`.
4. Do not loosen tolerances, skip tests, delete failing tests, or mark unrun tests as passed.
5. Report honestly: `blocked` when stuck, `need_decision` when a human decision is required.
6. Ask one concrete question at a time, with a recommendation and reason.
7. Do not guess content marked TODO or [CONFIRM] in contracts; write `need_decision`.
8. Every performance or accuracy conclusion must include a repro record (see report template).
9. Do not create tasks beyond the current one, or expand your own permissions or budget.
10. Do not push, merge protected branches, or submit HPC jobs (`sbatch`/`srun`).

## Workflow

read task -> read contracts -> write tests -> implement -> gate -> commit -> write report -> stop.

Do only the first `todo` task for your module in `.agentlab/TASKS.md`.

## Commit

After the gate passes:
- `git add` only files inside your scope;
- `git commit -m "<module>: <task> <short description>"`;
- **do not push**;
- record the commit SHA in your report.

## Report status

`ready` / `blocked` / `need_decision`

`ready` means "ready for integration review"; it does not mean "numerically verified".
