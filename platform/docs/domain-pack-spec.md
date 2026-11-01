**English** | [中文](domain-pack-spec.zh-CN.md)

# Domain Pack Specification

A domain pack is reusable across repositories. A **target pack** is one concrete
repository. The repository is layered as:

```text
platform/               generic rules, scripts, gates, CLI
domains/<domain>/       reusable domain rules
targets/<target>/       one repository: paths, branch, commands, scope
```

Install both with `agentlab install <domain> <target> <repo>`; the target overlay
wins where the two overlap. See
[`target-pack-spec.md`](target-pack-spec.md).

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

- The platform must not contain target-specific paths, branches, build commands,
  or test commands; those belong in a target pack.
- The platform must not contain CFD-specific logic.
- Domain packs must not depend on a specific solver repository layout; paths are configured in `scope/`.
- If a second domain requires changing `platform/`, record the abstraction failure before changing it.
- Verification cases and tolerances are human-owned. Agents may add cases only through an RFC.
