# Validation target

A tiny, real-enough CFD repository used to validate the **code-changing** loop:
worker mode, scope check, build, unit tests, numerical verification, commit,
integration gate.

The task is genuine: implement the first-order upwind residual for 1D linear
advection and make an MMS convergence check report order 1.

Before the worker implements it, the verification reports **UNVERIFIED** (exit 2).
After it does, the same verification reports **PASS** with a measured order.
That transition is the point of the exercise.

Do not use this as a CFD codebase. It exists to prove the harness does not lie.
