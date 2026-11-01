**English** | [中文](0002-no-test-architecture-refactor.zh-CN.md)

# 0002 — Do not refactor the target's test architecture

- Date: 2026-11-01
- Status: accepted
- Scope: v0.1 (first applied to OneFLOW)

## Decision

agent-lab does **not** ask a worker to restructure an existing test build.
The OneFLOW audit proposed a shared `oneflow_case_runtime` CMake target so that
`SimcuContext::TeardownCase` could be linked by a test. That proposal is **rejected
for v0.1**.

The target repository keeps its current test architecture:

- `tests/` — CTest/GoogleTest targets that list production sources per target;
- `test/` — `test.py` end-to-end numerical regression against `OneFLOW`;
- Python tooling tests;
- `ci/kunshan/*` hardware/MPI runners.

## Reason

1. The refactor is an architecture change to a large, actively developed
   repository. It has no measured performance or correctness benefit on its own.
2. It has real risk: compile definitions (`MPI`/`METIS`/`CGNS`/`HIP`) must
   propagate identically, or the same translation unit compiles differently in
   tests and production.
3. Coordination scope is the point of agent-lab. Broad build refactoring is
   exactly the kind of change that should stay human-owned.
4. A known coverage gap is an acceptable, recorded outcome. It is not a reason
   to restructure someone else's build.

## Consequence

- `TeardownCase` remains untested. This is recorded as a known gap, not fixed by
  agent-lab.
- Contract tests proposed by the audit are not added in this form.
- If a human later decides the gap matters enough, that refactor is a separate,
  human-owned task with its own design and measurement.

## What agent-lab may still do

- Add tests that fit the existing pattern: one target per contract, listing the
  production sources it needs.
- Fix behavioural defects that are covered by existing targets.
- Record gaps in reports and RFCs for a human to prioritise.
