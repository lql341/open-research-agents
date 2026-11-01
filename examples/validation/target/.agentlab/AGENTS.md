# Platform rules (validation target)

1. Only modify files allowed by `.agentlab/scope/<workstream>.txt`.
2. Do not modify `core/`, `.agentlab/contracts/`, `.agentlab/verification/`, or `verification/`.
   Need a change -> write `.agentlab/RFC/<date>-<workstream>-<topic>.md`, set the report
   status to `need_decision`, and stop.
3. Completion requires `gate.sh <workstream>` to pass, and a **commit** on `agent/<workstream>`.
4. Do not loosen tolerances, skip tests, or delete failing tests.
5. Report honestly: `blocked` when stuck, `need_decision` when a human decision is needed.
6. Do not push, merge, or submit cluster jobs.

## Workflow

read contracts -> write tests -> implement -> gate -> commit -> write report -> stop.
Do only the first `todo` task in `.agentlab/TASKS.md`.

## Report

Write `.agentlab/reports/<workstream>.md` with `status`, `commit`, gate output, files changed.
