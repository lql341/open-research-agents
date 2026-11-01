# Domain Pack Specification

A domain pack lives at `domains/<name>/` and must provide:

| File/Dir | Purpose |
|---|---|
| `domain.env` | `DOMAIN`, `MODULES`, `BUILD_CMD`, `UNIT_CMD`, `VERIFY_CMD` |
| `AGENTS.domain.md` | Domain-specific rules, merged into `.agentlab/AGENTS.md` on install |
| `contracts/` | Interfaces, data layout, core API; TODO items are human-owned |
| `scope/<module>.txt` | Allowed path prefixes per module |
| `TASKS.md` | Human-maintained task board |
| `verification/` | Numerical cases and `run_all.sh`; must exit non-zero on failure, 2 for unverified |
| `repro_fields.yaml` | Domain-specific reproducibility fields |

## Rules

- The platform must not contain CFD-specific logic.
- Domain packs must not depend on a specific solver repository layout; paths are configured in `scope/`.
- If a second domain requires changing `platform/`, record the abstraction failure before changing it.
- Verification cases and tolerances are human-owned. Agents may add cases only through an RFC.
