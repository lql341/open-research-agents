# temporal

Owns explicit time integration and time-step control.

`ITimeIntegrator` is frozen in `.agentlab/contracts/interfaces.md`.
`ForwardEuler` is a placeholder; T1 implements Forward Euler and SSP-RK3,
verified against ODE operators in `tests/mocks`.
