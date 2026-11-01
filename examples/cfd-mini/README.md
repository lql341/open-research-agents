# cfd-mini

Minimal C++17 CFD target repository for agent-lab. It is a **template**, not a solver.

## Build

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j2
ctest --test-dir build -L unit --output-on-failure
```

## Status

- `core/`: minimal `Field`, `Mesh`, `Comm` (human-owned, agents read-only).
- `modules/spatial/`: `ISpatialOperator` + `UpwindSpatial` placeholder (S1 task).
- `modules/temporal/`: `ITimeIntegrator` + `ForwardEuler` placeholder (T1 task).
- `tests/unit/`: core unit test only; spatial/temporal tests are TODO for workers.
- `.agentlab/verification/`: placeholder returns `UNVERIFIED` (exit 2).

This is intentional: `GATE PASS` is not claimed until a real numerical case is registered.

## Use with agent-lab

```bash
# from a copy, not from this template directory
cp -R examples/cfd-mini /tmp/cfd-mini
cd /tmp/cfd-mini
git init -b main
git add . && git commit -m "init cfd-mini"

# install/reinstall the CFD domain pack (does not overwrite existing .agentlab files)
<agent-lab>/platform/scripts/install_domain.sh cfd /tmp/cfd-mini

# run a worker
<agent-lab>/platform/scripts/preflight.sh spatial
<agent-lab>/platform/scripts/run_worker.sh spatial
```
