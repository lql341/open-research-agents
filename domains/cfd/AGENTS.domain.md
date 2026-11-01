# CFD domain rules

Project: C++17 CFD solver. Modules: `spatial` (space discretization), `temporal` (time integration).
Data structures and parallel primitives are human-maintained (`core/`, read-only). Parallel performance optimization is a separate serial task after correctness is green.

1. Do not submit cluster jobs (`sbatch`/`srun`). Local `mpirun -np 4` is allowed; write larger commands in the report for a human.
2. Changes to numerical schemes, physical models, convergence criteria, meshes, or baselines are `need_decision`.
3. Access data and parallel primitives only through the types declared in `contracts/`.
4. Unit tests use CTest with label `unit`.
5. Every accuracy/convergence/performance conclusion needs a repro record; fields are in `.agentlab/repro_fields.yaml`; state the timing method (included/excluded phases, warmup, repetitions).
6. TODO (human): naming conventions, formatter, compile flags.

## Scope reminder

- spatial: residual, flux, reconstruction, boundary conditions.
- temporal: explicit time integration, time-step control.
- Neither worker modifies `core/`, `contracts/`, `verification/`, or platform scripts.
