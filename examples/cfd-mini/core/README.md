# core

Human-maintained numerical foundation. Agents read only.

- `Field`: owns `std::vector<double>` storage; `like/copy/axpy/norm2`.
- `Mesh`: structured 1D minimum; read-only geometry.
- `Comm`: serial no-op; MPI is a later RFC.

The public surface is frozen in `.agentlab/contracts/core_api.md`.
