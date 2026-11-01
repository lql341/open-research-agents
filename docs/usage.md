# Usage

`agentlab` is the only command you need. It runs workers with a
**separate Pi agent directory**, so your daily `pi` is untouched.

## 1. Worker Pi profile (one time)

```bash
mkdir -p ~/.pi/agentlab
PI_CODING_AGENT_DIR=~/.pi/agentlab pi /login     # or copy auth.json / models.json
```

Nothing is exported globally. `agentlab` sets `PI_CODING_AGENT_DIR` only for the
child process it starts.

## 2. Config (optional)

`~/.config/agentlab/config.toml`:

```toml
[pi]
bin = "pi"
profile = "~/.pi/agentlab"
args = "--model openai/gpt-5"

[runtime]
worktree_root = "~/agentlab-wt"
```

Environment variables `PI_BIN`, `PI_PROFILE`, `PI_ARGS`, `WT_ROOT` win over the file.

## 3. Daily loop

```bash
agentlab doctor                  # check Pi, profile, guard, target repo
agentlab status                  # workstream / report / gate / pending decisions

agentlab run runtime-io          # one worker: rules -> code -> gate -> commit -> report
agentlab run numerics

agentlab status                  # gate + report states changed
agentlab integrate runtime-io numerics   # merge + integration gate

# review the integration branch yourself, then merge
```

## 4. Debugging a worker

```bash
agentlab pi runtime-io
```

Opens interactive Pi **in that workstream's worktree**, resuming the same
session (`agentlab-<workstream>`) with the guard extension loaded, so you see
exactly what the worker saw.

## 5. What agentlab never does

- It never edits your `~/.pi/agent` (your daily Pi).
- It never installs extensions or writes global Pi settings.
- It never touches the target repository's source, build, or test layout by itself.
- It never pushes, merges protected branches, or submits cluster jobs.

## 6. Files it writes

| Path | Content |
|---|---|
| `<repo>/.agentlab/reports/` | one report per workstream |
| `<repo>/.agentlab/RFC/` | proposals awaiting a human |
| `<repo>/.agentlab/repro/` | gate/run evidence |
| `<repo>-wt/<workstream>/` | the worker's git worktree |
| `<repo>-wt/logs/` | one log per worker run |
| `<repo>-wt/sessions/` | worker Pi sessions |

## 7. Modes

`AGENTLAB_MODE` in `.agentlab/target.env`:

| Mode | Worker may write | Gate runs |
|---|---|---|
| `audit` | reports, RFCs, repro only | scope only |
| `worker` | its scope paths | scope + build + tests + verification |

`integration` and `release` are gate modes, not worker modes.
