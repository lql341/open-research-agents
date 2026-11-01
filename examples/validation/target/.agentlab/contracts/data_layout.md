# Data Layout Contract (frozen for the validation target)

- Field layout: AoS, one `std::vector<double>` per field
- Conserved variables: 1 scalar (linear advection)
- Index convention: `Field` holds `nx + 2*ghost` values; cell `i` is at index `i + ghost`;
  index `ghost-1` is the left periodic neighbour of cell 0, index `nx+ghost` the right
  neighbour of cell `nx-1`
- Ghost width: 1
- Mesh: structured 1D, uniform `dx`, periodic
- Non-dimensionalization: dimensionless
- Memory ownership: `Field` owns its storage; callers allocate with `Field(size)` or `Field::like()`
- Precision: `double`
- Parallel model: serial; `Comm` is a no-op
