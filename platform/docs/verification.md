# Verification Gates

| Gate | Content | Result |
|---|---|---|
| G0 | Scope check: added/deleted/renamed/untracked files | PASS / FAIL |
| G1 | Build and static checks | PASS / FAIL |
| G2 | Unit tests (`ctest -L unit`) | PASS / FAIL |
| G3 | Numerical verification (MMS/ODE/conservation) | PASS / FAIL / **UNVERIFIED** |
| G4 | Integration regression | PASS / FAIL |
| G5 | Performance benchmark | PASS / FAIL / N/A |

Rules:

- A missing verification case is `UNVERIFIED`, never `PASS`.
- Worker gate may return `UNVERIFIED`; the report must say so.
- Integration gate (`GATE_MODE=integration`) requires `G3=PASS`.
- Only `G0-G4` PASS allows human approval.
- Tolerances and baselines are human-owned; agents cannot loosen them.
- Every accuracy/performance conclusion must have `.agentlab/repro/*.json`.

`gate.sh` exit codes: `0` PASS, `1` FAIL, `2` UNVERIFIED.
