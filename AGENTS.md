**English** | [中文](AGENTS.zh-CN.md)

# Open Research Agents — platform repository

This repository is the **platform**, not a CFD solver.

Before changing anything:
1. Read `platform/AGENTS.md`.
2. Read `IMPLEMENTATION_PLAN.md`.
3. Do not edit `domains/cfd/contracts/` unless you are the human owner; agents must submit an RFC.
4. Do not change `platform/scripts/` semantics without updating `platform/docs/governance.md` and tests.

The target repositories are separate git repositories. `examples/validation/target/` is a template; copy it out and `git init` before running workers.
