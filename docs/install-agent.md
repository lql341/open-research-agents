**English** | [中文](install-agent.zh-CN.md)

# Agent Installation Protocol

**Audience: a coding agent (Pi, Codex, Claude Code, or similar). The human only
answers questions and approves actions.**

This document is an executable protocol. Follow it in order. Run every
verification command and record its real output. Do not skip steps, assume
results, or report an unexecuted test as passing.

---

## Objective

Install `open-research-agents` on this machine, attach a target pack to one
repository, and make the `agentlab` command available **without modifying the
human's daily Pi configuration**.

## Hard constraints

1. **Do not modify `~/.pi/agent`.** Workers use a separate
   `PI_CODING_AGENT_DIR`.
2. **Do not modify the target repository's source, build scripts, or test
   architecture.** Only create or modify `.agentlab/` and, if absent, the root
   `AGENTS.md` pointer.
3. **Do not run `pi /login`.** Authentication belongs to the human. Prepare the
   directory and provide the command.
4. **Do not install global software** without explicit human approval. Check for
   existing tools first.
5. **Do not run `git push`, merge protected branches, or submit `sbatch`/`srun`.**
6. **Do not commit files outside `.agentlab/`** unless the human explicitly
   approves each file. Inspect `git status --short` before committing.
7. **Ask one concrete question at a time.** Provide a recommendation and reason.
8. **Stop on failure.** Report the command and its output. Do not bypass the
   failure and continue.

## Non-goals

- Do not implement features, modify the platform, or optimize performance.
- Do not restructure the target repository's tests or CMake layout.
- Do not configure clusters, containers, or CI.

---

## Step 0: Reconnaissance (read-only)

Collect facts without changing anything:

```bash
pwd
ls
git rev-parse --show-toplevel 2>/dev/null || echo "not a git repo"
bash --version | head -1
git --version
python3 --version
cmake --version 2>/dev/null | head -1
c++ --version 2>/dev/null | head -1
pi --version 2>/dev/null || echo "pi: not found"
echo "PI_CODING_AGENT_DIR=${PI_CODING_AGENT_DIR:-unset}"
ls ~/.pi 2>/dev/null
ls ~/.config/agentlab 2>/dev/null || echo "no agentlab config"
```

Produce a short summary:

```text
Found:
  platform repo   : <path or "not found">
  target repo     : <path or "not chosen">
  pi              : <version or missing>
  worker profile  : <exists / missing>
  config          : <exists / missing>
Blocking issues : <none | list>
```

If `pi` is missing, stop and ask the human whether to install it. Do not install
it yourself.

### Platform check

Use `uname -s`:

| Output | Action |
|---|---|
| `Darwin` / `Linux` | Continue |
| `MINGW*` / `MSYS*` / `CYGWIN*` | Continue; report "Windows via Git Bash" |
| Other | Stop and report an unverified platform. Do not modify scripts to fit it |

On Windows without Bash (PowerShell), stop and ask the human to rerun this
protocol in Git Bash or WSL.

---

## Step 1: Confirm two paths

Ask one question:

> Where is `open-research-agents`, and which repository is the target?

Recommendation: the platform repository is the current clone; the target is an
existing repository with its own `AGENTS.md`.

Do not guess. If only one path is provided, ask for the other.

---

## Step 2: Prepare the worker Pi profile

```bash
mkdir -p ~/.pi/agentlab
ls -A ~/.pi/agentlab
```

If the directory contains `extensions/`, `skills/`, or `mcp.json`, stop and tell
the human: these resources will load into every worker. Recommend clearing them.

If the directory has no `auth.json` or `models.json`, ask the human to
authenticate:

> Run `PI_CODING_AGENT_DIR=~/.pi/agentlab pi /login` in your terminal and tell me
> when it completes.

After confirmation:

```bash
PI_CODING_AGENT_DIR=~/.pi/agentlab pi --list-models | head -5
```

The command must list at least one model. Otherwise, stop.

---

## Step 3: Write the CLI configuration

```bash
mkdir -p ~/.config/agentlab
[ -f ~/.config/agentlab/config.toml ] || \
  cp <platform-repo>/examples/agentlab.config.toml ~/.config/agentlab/config.toml
```

Confirm the profile path by reading the file:

```bash
grep -E '^(bin|profile|args)' ~/.config/agentlab/config.toml
```

If the human requested a specific model, add it to the `[pi]` section as
`args = "--model <id>"`.

---

## Step 4: Add the CLI to PATH

```bash
mkdir -p ~/.local/bin
ln -sf <platform-repo>/bin/agentlab ~/.local/bin/agentlab
command -v agentlab
agentlab version
```

If `command -v agentlab` prints nothing, `~/.local/bin` is not on `PATH`. Ask the
human before modifying a shell profile:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

---

## Step 5: Self-check

```bash
cd <platform-repo>
agentlab doctor
```

Require `doctor: PASS`. Explain each warning; do not ignore it.

Run the platform tests:

```bash
bash tests/platform_smoke.sh
```

Require `smoke: N passed, 0 failed`. Stop and report failures.

---

## Step 6: Install into the target repository

Inspect the target first:

```bash
cd <target-repo>
git branch --show-current
git status --short
ls .agentlab 2>/dev/null && echo "already installed" || echo "not installed"
```

If the pack already exists, do not overwrite it. `install_target.sh` does not
overwrite existing files, so rerunning is safe:

```bash
agentlab install <domain> <target> <target-repo>
```

Available packs are documented in `targets/`. For the first example:

| Domain | Target | Notes |
|---|---|---|
| `cfd` | `oneflow` | OneFLOW, audit mode, workstreams `runtime-io` and `numerics` |

Inspect the changes:

```bash
cd <target-repo>
git status --short
```

Only `.agentlab/` and, if newly created, `AGENTS.md` should appear. Stop and
report any other path.

Check the base ref:

```bash
git branch --show-current
grep BASE_REF .agentlab/target.env
```

If they differ, update `target.env` and record the change.

---

## Step 7: Commit (requires human approval)

Show the human what will be committed:

```bash
cd <target-repo>
git status --short
git diff --stat
```

Ask one question:

> May I commit `.agentlab/` to the current branch?

Recommendation: yes. `scope_check` reads the scope from the base ref; an
uncommitted pack cannot enforce anything.

After approval:

```bash
git add .agentlab
[ -f AGENTS.md ] && git add AGENTS.md
git status --short
git commit -m "agentlab: add <target> pack"
```

Do not push.

---

## Step 8: Verify availability

```bash
cd <target-repo>
agentlab status
agentlab preflight <ws>
```

`status` must print the workstream table. `preflight` must pass in `audit` mode.

Do not run `agentlab run` here unless the human explicitly requests it; it calls
the model and consumes tokens.

---

## Step 8.5: Maintenance (only when requested)

| Request | Command | Notes |
|---|---|---|
| Update the tool and pack | `cd <platform-repo> && agentlab update` | Confirm the platform tree is clean; if `.agentlab/AGENTS.md.new` appears, show the diff and do not overwrite automatically |
| Update one target | `cd <target-repo> && agentlab update` | Adds new files and missing env keys; existing values are not overwritten; inspect `git status` before committing |
| Uninstall | `cd <target-repo> && agentlab uninstall` | Requires human confirmation; refuses while worker worktrees exist |
| Clean worktrees | `agentlab clean <ws...>` | Removes worktrees, keeps branches and logs |

Do not perform unrequested cleanup. Uninstall removes reports and RFCs.

---

## Step 9: Delivery report

Use exactly this structure:

```text
Summary
  <one sentence: what was installed and where>

Installed
  platform repo   : <path> @ <commit>
  target repo     : <path> @ <branch> <commit>
  domain/target   : <domain> / <target>
  mode            : audit
  workstreams     : <list>
  cli             : ~/.local/bin/agentlab
  worker profile  : ~/.pi/agentlab

Verification (real output only)
  agentlab doctor        : <PASS/FAIL>
  tests/platform_smoke   : <N passed / M failed>
  agentlab status        : <ok/error>
  agentlab preflight     : <PASS/FAIL>

Files changed
  <list of new files under .agentlab/, or a git show --stat summary>

Not changed
  ~/.pi/agent            : untouched
  target source/build    : untouched

Known risks
  <for example: a worker with shell access can read paths outside the worktree>

Pending human decisions
  <for example: which workstream to run first; whether to switch to worker mode>

Next step
  <one concrete command>
```

---

## Failure handling

| Failure | Action |
|---|---|
| `pi` is missing | Stop; ask the human whether to install it. Do not install it yourself |
| No model is available | Stop; ask the human to complete `pi /login` |
| `doctor` fails | Report the failing item and follow the troubleshooting section in `install-manual.md` |
| `smoke` fails | Stop and report. Do not modify platform code to make it pass |
| `git status` shows files outside `.agentlab/` | Stop; restore them with `git checkout -- <file>` and report |
| The base ref does not exist | Update `.agentlab/target.env`; do not change Git branches |
| The human requests work outside this protocol | Refuse and identify it as a human decision |

---

## Minimum command set for the human

After installation, the human normally needs only:

```bash
agentlab doctor
agentlab status
agentlab run <ws>
agentlab integrate <ws...>
agentlab pi <ws>
```
