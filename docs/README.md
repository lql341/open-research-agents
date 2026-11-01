**English** | [中文](README.zh-CN.md)

# Documentation

agentlab is a bounded multi-agent development system built on Pi. The platform is
generic; CFD is the first domain and OneFLOW is the first worked example.

English is the default documentation language. Every page has a Chinese version
linked at the top. The English page is canonical: when the two versions differ,
the English text describes the current behavior.

Operational files that workers read as data are not duplicated:

- `.agentlab/TASKS.md`
- `.agentlab/contracts/`
- `.agentlab/scope/`
- `.agentlab/templates/`
- test fixtures and generated `.agentlab/` packs

These files belong to a target repository and follow that repository's language.
They are configuration and evidence, not documentation pages.

## Start here

| Document | Purpose |
|---|---|
| [Quickstart](quickstart.md) | First successful worker run in five minutes, using the built-in validation target |
| [Workflow](workflow.md) | Full process for any target repository: audit, task, scope, gate, integration |
| [Validation](validation.md) | End-to-end validation experiment, including negative cases |

## Operating agentlab

| Document | Purpose |
|---|---|
| [Usage](usage.md) | Daily commands: status, run, gate, integrate, pi, clean |
| [Installation (manual)](install-manual.md) | Step-by-step installation, verification, troubleshooting, removal |
| [Installation (agent protocol)](install-agent.md) | Executable protocol for a coding agent |
| [Platform support](platform-support.md) | macOS, Linux, WSL, Windows Git Bash; native PowerShell is not supported |

## Reference

| Document | Purpose |
|---|---|
| [Target pack specification](../platform/docs/target-pack-spec.md) | Files, keys, installation and update semantics for one repository |
| [Domain pack specification](../platform/docs/domain-pack-spec.md) | Reusable domain rules and validation |
| [Governance](../platform/docs/governance.md) | Authorization model and current enforcement |
| [Verification](../platform/docs/verification.md) | Gate layers and exit codes |

## Worked example

| Document | Purpose |
|---|---|
| [OneFLOW target](../targets/oneflow/README.md) | Installation, status, and decisions for the first target |
| [OneFLOW workflow](../targets/oneflow/WORKFLOW.md) | Concrete commands and decisions for OneFLOW |

## Language policy

- English is the default and canonical language.
- Each documentation page has a `.zh-CN.md` counterpart and a language switch at
  the top.
- Code, configuration, tasks, contracts, scope files, templates, and test fixtures
  are not translated. They are read by workers and must remain unambiguous.
- `IMPLEMENTATION_PLAN.md` is a historical planning artifact and remains in Chinese.
  Current behavior is documented in this directory and in the target guides.
