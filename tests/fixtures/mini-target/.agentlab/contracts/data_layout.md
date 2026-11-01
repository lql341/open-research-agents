# Data Layout Contract — cfd-mini v0.1 (frozen fixture)

- Field layout: AoS (`std::vector<double>` per field)
- Conserved variables: 1 scalar for linear advection
- Index convention: 1D cell index `i`, ghost width 1 on each side
- Ghost width: 1
- Mesh: structured 1D, optional periodic
- Non-dimensionalization: dimensionless
- Memory ownership: `Field` owns its storage; callers allocate via `Field(size)` or `Field::like()`
- Precision: `double`
- Parallel model: serial; `Comm` is a no-op; MPI is a later RFC

This file is for the cfd-mini fixture only. Real target repositories must fill their own layout.
