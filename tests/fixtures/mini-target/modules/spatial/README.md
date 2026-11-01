# spatial

Owns space discretization: residual, flux, reconstruction, boundary conditions.

`ISpatialOperator` is frozen in `.agentlab/contracts/interfaces.md`.
`UpwindSpatial` is a placeholder; S1 implements the first-order upwind residual,
MMS spatial order, and conservation tests.
