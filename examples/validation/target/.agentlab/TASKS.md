# Task Board (human-maintained)

## Prerequisites (already done for this target)

- [x] Data layout and interface contract filled
- [x] `Field / Mesh / Comm` implemented in `core/`
- [x] Root `CMakeLists.txt` with CTest label `unit`
- [x] Numerical verification case registered (`verification/adv_mms.cpp`)
- [x] Scope narrowed to the spatial workstream

## spatial

- S1 [todo] Implement the first-order upwind residual for 1D linear advection.

  Requirements:
  - `UpwindSpatial::residual` computes `R_i = -a * (U_i - U_{i-1}) / dx` for interior cells;
  - `UpwindSpatial::max_stable_dt` returns `dx / |a|`;
  - add unit tests under `tests/unit/spatial/` and register them in `CMakeLists.txt` with label `unit`;
  - `bash .agentlab/verification/run_all.sh` must print `PASS` with `observed_order` between 0.85 and 1.15;
  - do not edit `core/`, `.agentlab/contracts/`, `.agentlab/verification/`, or `verification/`.
