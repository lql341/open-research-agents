# Task Board — cfd-mini (human-maintained)

## Prerequisites (human)

- [x] Fill `.agentlab/contracts/data_layout.md`
- [x] Confirm `.agentlab/contracts/interfaces.md`
- [x] Implement `Field / Mesh / Comm` in `core/`
- [x] Add root `CMakeLists.txt` and CTest label `unit`
- [ ] Register at least one real verification case; replace the placeholder `verification/run_all.sh`
- [x] Replace `scope/*.txt` with the repository's real paths

## spatial

- S1 [todo] First-order upwind residual for 1D linear advection; implement `ISpatialOperator`; MMS spatial order test (target 1) + conservation test.
- S2 [todo] Second-order reconstruction (MUSCL + limiter); smooth MMS reaches order 2.
- S3 [todo] Boundary-condition residual contributions (periodic / wall / farfield).

## temporal

- T1 [todo] Explicit RK (including SSP-RK3); verify time order with linear/nonlinear ODE operators in `tests/mocks`.
- T2 [todo] Time-step control: call `max_stable_dt` + global `Comm` reduction.
- T3 [blocked] Implicit schemes: write an RFC for the Jacobian interface first; implement only after approval.

## Deferred

- Data-structure/parallel performance optimization: after correctness is green, run as a separate serial task; results must match the pre-optimization baseline within tolerance.
