# temporal unit tests (worker-owned)

T1 adds:
- time-order verification against mock ODE operators;
- update correctness;
- invalid dt handling;
- no mutation of the mock operator's state.

Tag CTest tests with `unit`.
