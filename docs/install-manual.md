**English** | [中文](install-manual.zh-CN.md)

# Manual Installation

This page is for a human operator. Each step includes a verification command;
stop if a verification fails.

If a coding agent will perform the installation, use
[`install-agent.md`](install-agent.md) instead.

> Platform support is described in
> [`platform-support.md`](platform-support.md). Native PowerShell is not
> supported; use Git Bash or WSL on Windows.

## 0. Prerequisites

```bash
bash --version | head -1     # 4.0+ recommended; system Bash 3.2 on macOS is supported
git --version                # 2.32+
python3 --version            # 3.8+ (status and repro records); `python` also works on Windows
pi --version                 # 1.x
```

The target repository also needs its own build and test tools. These are only
required for `worker` and `integration` gates:

```bash
cmake --version | head -1
c++ --version | head -1
```

If `pi` is not installed, install it once:

```bash
curl -fsSL https://pi.dev/install | sh
# or
npm install -g @earendil-works/pi-coding-agent
```

Verify:

```bash
pi --version
```

## 1. Obtain the repository

```bash
cd ~/agentlab
git clone <this-repo> open-research-agents
cd open-research-agents
export AGENTLAB="$PWD"
```

Verify:

```bash
ls platform/scripts bin docs
```

## 2. Create a separate Pi profile for workers

This is the most important isolation step. Workers must not share the daily Pi
configuration, because personal extensions, skills, and MCP servers would load
into every worker.

```bash
mkdir -p ~/.pi/agentlab
PI_CODING_AGENT_DIR=~/.pi/agentlab pi /login
```

If `~/.pi/agent/auth.json` and `models.json` already exist, they can be copied
instead of logging in again:

```bash
cp ~/.pi/agent/auth.json ~/.pi/agentlab/ 2>/dev/null || true
cp ~/.pi/agent/models.json ~/.pi/agentlab/ 2>/dev/null || true
```

Verify:

```bash
PI_CODING_AGENT_DIR=~/.pi/agentlab pi --list-models | head -5
ls ~/.pi/agentlab
```

The profile should not contain `extensions/`, `skills/`, or `mcp.json` unless
those resources are intentionally available to workers.

## 3. Configure the CLI

```bash
mkdir -p ~/.config/agentlab
cp examples/agentlab.config.toml ~/.config/agentlab/config.toml
```

Confirm:

```toml
[pi]
bin = "pi"
profile = "~/.pi/agentlab"
```

To use a cheaper model for workers:

```toml
[pi]
args = "--model your-provider/your-model"
```

Verify:

```bash
./bin/agentlab config
```

Expected:

```text
pi.profile  /Users/<you>/.pi/agentlab
```

## 4. Add the CLI to PATH

```bash
mkdir -p ~/.local/bin
ln -sf "$AGENTLAB/bin/agentlab" ~/.local/bin/agentlab
```

Confirm `~/.local/bin` is on `PATH`:

```bash
printf '%s\n' "$PATH" | tr ':' '\n' | grep -q "$HOME/.local/bin" && echo "in PATH" || echo "NOT in PATH"
```

If it is missing, add this line to `~/.zshrc` or `~/.bashrc`:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

Verify:

```bash
agentlab version
```

## 5. Self-check

```bash
cd ~/open-research-agents
agentlab doctor
```

Expected:

```text
tools
  ok    git ...
  ok    python3 ...
pi
  ok    pi 1.x
  ok    worker profile /Users/<you>/.pi/agentlab
guard
  ok    platform/extensions/guard.ts
```

The last line should be `doctor: PASS`. If a warning appears, resolve it before
continuing.

## 6. Install into a target repository

### 6.1 Existing repository

```bash
agentlab install <domain> <target> <repo>
```

The installer:

- creates `<repo>/.agentlab/` with rules, contract templates, scope, task board,
  and a verification placeholder;
- creates `<repo>/AGENTS.md` only if it does not already exist;
- does not modify solver code, build scripts, or tests.

Commit the pack, because `scope_check` reads the scope from the base ref:

```bash
cd <repo>
git status --short
git add .agentlab AGENTS.md
git commit -m "agentlab: add <target> pack"
agentlab status
```

At this point all workstreams normally show `missing`; that is expected before
the first worker run.

### 6.2 Template repository

```bash
cp -R "$AGENTLAB/examples/validation/target" ~/agentlab-target
cd ~/agentlab-target
git init -b main
git add -A
git commit -m "init"

agentlab install <domain> <target> ~/agentlab-target
git add -A
git commit -m "agentlab install"
```

The validation target is a fixture for the platform, not product code.

### 6.3 Check the base ref

`BASE_REF` in `.agentlab/target.env` must match a real branch or ref:

```bash
cd <repo>
git branch --show-current
grep BASE_REF .agentlab/target.env
```

If they differ, update `target.env` and commit it. `agentlab status` warns when
the base ref does not exist.

## 7. First run

Start in `audit` mode: workers may only write reports, RFCs, and repro records.

```bash
cd <repo>
grep AGENTLAB_MODE .agentlab/target.env    # expected: audit
agentlab preflight <ws>
agentlab run <ws>
agentlab status
```

`agentlab run` invokes the model and consumes tokens. To verify the flow without
model calls, use a deterministic stand-in:

```bash
cat > /tmp/fake-pi.sh <<'SH'
#!/bin/sh
mkdir -p .agentlab/reports
printf '# Report\nstatus: ready\ncommit: deadbee\n' > .agentlab/reports/<ws>.md
git add .agentlab/reports/<ws>.md
git commit -q -m "fake report"
SH
chmod +x /tmp/fake-pi.sh
PI_BIN=/tmp/fake-pi.sh agentlab run <ws>
agentlab status
```

## 8. Switch to code mode

Only after the audit and the human decisions are complete:

1. Read `.agentlab/reports/*.md` and `.agentlab/RFC/*.md`.
2. Answer the `need_decision` items.
3. Replace `.agentlab/scope/<ws>.txt` with the real, disjoint source paths.
4. Fill `.agentlab/contracts/` with the repository's actual boundary.
5. Set `AGENTLAB_MODE=worker` in `.agentlab/target.env`.
6. Verify `BUILD_CMD` and `UNIT_CMD` on this machine.
7. Register at least one real verification case; replace the placeholder
   `verification/run_all.sh`.

```bash
agentlab preflight <ws>
agentlab run <ws>
agentlab gate <ws> --mode integration
```

### Gate semantics

| Gate | Requirement |
|---|---|
| `audit` | Scope only |
| `worker` | Scope + build + tests + verification (UNVERIFIED allowed) |
| `integration` | Same, but verification must PASS |
| `release` | All gates must PASS |

`gate.sh` exit codes: `0` PASS, `1` FAIL, `2` UNVERIFIED.

## 8.5 Run the validation experiment first

Before using a real repository, run the end-to-end loop:

```bash
bash scripts/validate-harness.sh          # no model calls
```

Then follow Method B in [`validation.md`](validation.md) with a real worker.
Proceed to a real repository only after both pass.

## 9. Troubleshooting

| Symptom | Cause | Action |
|---|---|---|
| `agentlab: .agentlab/ not found` | Pack not installed, or wrong directory | Run `agentlab install ...` from the repository root |
| `base ref '<ref>' not found` | `BASE_REF` does not match a real ref | Update `.agentlab/target.env` and commit |
| `working tree is dirty` | Uncommitted changes in the target repository | Commit or stash; workers branch from the base ref, not from the working tree |
| `worker made no commit` | Worker exited without committing | Inspect `agentlab status`, the worktree, and the log |
| `OUT OF SCOPE: ...` | Change outside the workstream scope | Adjust scope (human decision) or require an RFC |
| Gate reports `UNVERIFIED` | Verification is still a placeholder | Register a real case; `integration` will reject UNVERIFIED |
| `ctest` finds zero tests | The target has no matching label or selector | Use the target's real test command; do not rely on a label that does not exist |
| Worker uses the wrong model | `~/.pi/agentlab` has no model configuration | Log in again in that directory, or set `pi.args` in the config |
| Daily Pi behavior changed | Shell profile exports `PI_CODING_AGENT_DIR` | Remove it from the shell profile |

## 9.5 Update

```bash
cd ~/open-research-agents
agentlab update
```

It performs four steps:

1. `git pull --ff-only` on the tool repository (skipped when the tree is dirty or
   `--no-pull` is used);
2. re-applies the pack recorded in `.agentlab/.pack`, adding only new files;
3. adds missing keys from the current target and domain packs to
   `.agentlab/target.env` and `.agentlab/domain.env`; existing values are never
   overwritten;
4. regenerates `.agentlab/AGENTS.md`; if it differs, writes
   `.agentlab/AGENTS.md.new` and prints a diff instead of overwriting local edits.

After updating:

```bash
cd <repo>
git status --short
agentlab status
```

If `.agentlab/AGENTS.md.new` was created, review and merge it manually.

## 10. Uninstall

```bash
cd <repo>
agentlab uninstall
```

It removes `.agentlab/` and the generated root `AGENTS.md` pointer, but only when
that pointer was created by the installer. It keeps `agent/*` branches,
`<repo>-wt/logs`, and the worker Pi profile.

If worker worktrees still exist, uninstall refuses until they are removed:

```bash
agentlab clean <ws...>
```

Optional full cleanup:

```bash
rm -rf <repo>-wt
rm -f ~/.local/bin/agentlab
rm -rf ~/.config/agentlab
rm -rf ~/.pi/agentlab      # removes the worker login state
```

`~/.pi/agent` is not modified at any point.

## Appendix: files created by the installation

| Path | Created by | Contents |
|---|---|---|
| `<repo>/.agentlab/` | `agentlab install` | Rules, contracts, scope, task board, verification placeholder, templates |
| `<repo>/AGENTS.md` | `agentlab install` (only if absent) | Pointer to `.agentlab/AGENTS.md` |
| `<repo>-wt/<ws>/` | `agentlab run` | Git worktree |
| `<repo>-wt/logs/` | `agentlab run` | Worker logs |
| `<repo>-wt/sessions/` | `agentlab run` | Worker Pi sessions |
| `<repo>/.agentlab/reports/` | Worker | One report per workstream |
| `<repo>/.agentlab/RFC/` | Worker | Proposals awaiting a human |
| `<repo>/.agentlab/repro/` | Gate / worker | Gate and run evidence |
| `<repo>/.agentlab/tickets/` | Human / inbox | Ticket authorization ledger |
| `<repo>/.agentlab/decisions/` | Human / inbox | Decision records |
| `<repo>/.agentlab/candidates/` | GitHub source | Pending source candidates |
| `<repo>/.agentlab/sources/` | Source | Last poll state per source |
| `~/.config/agentlab/config.toml` | Operator | CLI configuration |
| `~/.pi/agentlab/` | Operator | Worker Pi configuration |

The installer does not write `~/.pi/agent`, target source code, build scripts, or
tests.
