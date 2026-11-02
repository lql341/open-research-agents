**English** | [中文](README.zh-CN.md)

# Open Research Agents

A bounded multi-agent development system built on Pi. The platform is generic;
CFD is the first domain and OneFLOW is the first target.

Status: **v0.1 scaffold + v0.2 Attention Inbox (beta)**. The platform scripts are
Bash and run on the system Bash 3.2 shipped with macOS. macOS, Linux, WSL, and Windows Git Bash are
supported; native PowerShell is not. See
[`docs/platform-support.md`](docs/platform-support.md).

## Layers

```text
platform/               generic core: rules, preflight, scope, gate, workers, integration, evidence
domains/<domain>/       reusable domain pack: contracts, scope, tasks, verification, repro fields
targets/<target>/       one repository: real paths, base branch, commands, workstreams
examples/validation/    a copyable validation target (not product code)
tests/fixtures/         small fixture used by the platform smoke test
```

Solver code is not part of this repository. A domain and target pack are installed
into a target repository under `.agentlab/`. The platform contains no
repository-specific paths, branches, build commands, or test commands.

## Documentation

English is the default. Every documentation page has a Chinese version linked at
the top. Operational files that workers read as data (`TASKS.md`, contracts,
`scope/`, templates, test fixtures) are not duplicated; they remain in the
language of the repository they belong to.

| Document | Audience | Contents |
|---|---|---|
| [`docs/README.md`](docs/README.md) | Everyone | Documentation index and language policy |
| [`docs/quickstart.md`](docs/quickstart.md) | Humans | First successful worker run in five minutes |
| [`docs/workflow.md`](docs/workflow.md) | Humans | Full process for any target repository |
| [`docs/validation.md`](docs/validation.md) | Humans | End-to-end validation experiment |
| [`docs/usage.md`](docs/usage.md) | Humans | Daily commands: status, run, gate, integrate, pi |
| [`docs/install-manual.md`](docs/install-manual.md) | Humans | Manual installation, verification, troubleshooting, removal |
| [`docs/install-agent.md`](docs/install-agent.md) | Coding agents | Executable installation protocol |
| [`docs/platform-support.md`](docs/platform-support.md) | Humans | macOS / Linux / Windows support matrix |
| [`platform/docs/target-pack-spec.md`](platform/docs/target-pack-spec.md) | Humans | Target pack fields and installation semantics |
| [`platform/docs/domain-pack-spec.md`](platform/docs/domain-pack-spec.md) | Humans | Domain pack specification |
| [`platform/docs/governance.md`](platform/docs/governance.md) | Humans | Authorization model and current enforcement |
| [`platform/docs/verification.md`](platform/docs/verification.md) | Humans | Gate layers and exit codes |
| [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md) | Humans | Living roadmap and design record |

### Worked example target

| Document | Contents |
|---|---|
| [`targets/oneflow/README.md`](targets/oneflow/README.md) | OneFLOW target pack: installation and status |
| [`targets/oneflow/WORKFLOW.md`](targets/oneflow/WORKFLOW.md) | Complete OneFLOW workflow |

## Installation

```bash
cd open-research-agents
export AGENTLAB="$PWD"

# A separate Pi configuration directory for workers. Your daily ~/.pi/agent is not modified.
mkdir -p ~/.pi/agentlab
PI_CODING_AGENT_DIR=~/.pi/agentlab pi /login

# Optional configuration
mkdir -p ~/.config/agentlab
cp examples/agentlab.config.toml ~/.config/agentlab/config.toml

# Add the CLI to PATH
ln -sf "$AGENTLAB/bin/agentlab" ~/.local/bin/agentlab

agentlab doctor
```

`agentlab` sets `PI_CODING_AGENT_DIR` only for the child process it starts.
It does not modify the user's shell profile or `~/.pi/agent`.

## First run on any target repository

```bash
# 1. Install a domain and target pack into the repository
agentlab install <domain> <target> <repo>

# 2. Review and commit .agentlab (scope_check reads the scope from the base ref)
cd <repo>
git status --short
git add .agentlab AGENTS.md
git commit -m "agentlab: add <target> pack"

# 3. Check the installation
agentlab doctor
agentlab status
```

When a repository is unfamiliar, keep the target in `audit` mode. In that mode a
worker may only write reports, RFCs, and repro records. Switch to `worker` after
scopes, contracts, and a real verification case are in place.

See [`docs/workflow.md`](docs/workflow.md) for the complete process.

The first available target is OneFLOW:

```bash
agentlab install cfd oneflow ~/OneFLOW
cd ~/OneFLOW
git add .agentlab AGENTS.md
git commit -m "agentlab: add OneFLOW target pack"
agentlab status
```

## Commands

```bash
agentlab install <domain> <target> <repo>   install a pack
agentlab update                             update the tool and re-apply the current pack
agentlab uninstall                          remove .agentlab from the current repository
agentlab doctor                             check Pi, profile, guard, and target repository
agentlab config                             show the resolved configuration
agentlab status [--json]                    workstreams, reports, gates, pending RFCs
agentlab inbox [--all] [--json]             attention inbox: only items that need a human
agentlab decide <id> [--ack|--approve|--reject] [--note TEXT]
agentlab preflight <ws>
agentlab run <ws> [--detach] [extra...]
agentlab gate <ws> [--here]                 gate the worker worktree by default
agentlab integrate <ws...>
agentlab integrate-audit <ws...>
agentlab pi <ws>                            open interactive Pi in that worktree
agentlab clean <ws...>                      remove worktrees, keep branches and logs
```

See [`docs/usage.md`](docs/usage.md) for details.

## Platform tests

```bash
bash tests/platform_smoke.sh        # 58 checks: scripts, CLI, install lifecycle, session guards
bash scripts/validate-harness.sh    # 27 checks: full gate loop, no model calls
```

To verify that a worker can change code while the gate still rejects wrong
implementations, follow [`docs/validation.md`](docs/validation.md).

## Known boundaries

- Isolation is enforced by convention and post-hoc checks, not a sandbox. A worker
  with shell access can still read paths outside its worktree.
- `platform/` lives outside the target repository; a worker cannot change the gate
  by editing the repository.
- The value of the verification gate depends entirely on the case registered by
  the target.
- v0.1 does not implement implicit time integration, MPI/GPU performance
  optimization, multi-project coordination, or a web panel.
- See [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md) for the long-term plan.

## License

MIT. The license may change after a dependency review.
