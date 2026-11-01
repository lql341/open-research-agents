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
agentlab gate runtime-io                 # gates the worker worktree by default
agentlab integrate runtime-io numerics   # merge + integration gate (base checkout must be clean)

# review the integration branch yourself, then merge
```

## 4.0 When a worker keeps failing for an unrelated-looking reason

A resumed session keeps the model recorded in its history. If that model is no
longer available (profile changed, provider gone, account limit), every turn
fails inside the provider call and the message looks unrelated:

```text
OpenAI API error (400): model_not_found
```

`agentlab run` now detects this before spending a turn:

```text
run_worker: the spatial session is pinned to an unavailable model: openai/gpt-5.5
run_worker: fix it with: agentlab run spatial --reset-session
```

Fix it with:

```bash
agentlab run spatial --reset-session     # clears only that workstream's session
agentlab pi spatial --reset-session      # same, then open interactively
```

`agentlab status` also shows the newest worker log and its last error line.

## 4. Debugging a worker

```bash
agentlab pi runtime-io
```

Opens interactive Pi **in that workstream's worktree**, resuming the same
session (`agentlab-<workstream>`) with the guard extension loaded, so you see
exactly what the worker saw.

## 4.0 Long runs and interruptions

`agentlab status` shows `WORKTREE=repro` when the only uncommitted files are
generated `.agentlab/repro` records; `clean` means nothing is uncommitted.

A worker with `thinking=high` can take many minutes. Do not hold the terminal:

```bash
agentlab run spatial --detach
```

It prints a pid, a log path, and returns immediately. Then:

```bash
agentlab status          # shows "Running in background: spatial pid NNNN"
tail -f <repo>-wt/logs/spatial-detached-*.log
kill <pid>               # or kill -TERM <pid> to interrupt cleanly
```

If you stop a foreground run with Ctrl-C, `run_worker` prints the worktree state
before exiting:

```text
run_worker: interrupted
run_worker: worktree state: head=abc1234 commits_since_main=1 uncommitted=0
run_worker: the work is committed; only the report or the final gate may be missing
```

That tells you whether to re-run, commit, or just finish the report. A detached
worker removes its pid file when it exits, so `status` stops showing it.

## 4.0.1 Gate in the right checkout

`agentlab gate <ws>` runs in the **current checkout**. If you are on the base
branch (`main`/`dev`), that checkout may still contain the unimplemented stub, so
the gate correctly reports `UNVERIFIED` even after the worker finished.

`agentlab gate <ws>` uses the worker's worktree by default. To force the current
checkout, use `--here` (this is rarely what you want outside the worktree):

```bash
agentlab gate <ws> --here
```

`agentlab integrate` also refuses a dirty base checkout. The only exception is
untracked `.agentlab/repro/*.json` audit records, which are committed with the
integration; a gate run on the base checkout leaves those behind.

## 4.1 Install, update, uninstall

```bash
agentlab install cfd oneflow /path/to/repo   # add the pack (never overwrites)
agentlab update                              # update the tool, then re-apply the pack here
agentlab update --no-pull                    # re-apply the pack only
agentlab uninstall                           # remove .agentlab from this repo (asks first)
agentlab uninstall --force --yes             # also when worktrees still exist
```

`update` does three things:

1. `git pull --ff-only` on the tool repository (skipped when dirty or when `--no-pull`);
2. re-runs `install` with the domain/target recorded in `.agentlab/.pack`,
   which only adds files that do not exist yet;
3. rebuilds `.agentlab/AGENTS.md` from the current rules and, if it differs,
   writes `.agentlab/AGENTS.md.new` plus a diff instead of overwriting your edits.

`uninstall` removes `.agentlab/` and the generated root `AGENTS.md` pointer, and
keeps `agent/*` branches, `<repo>-wt/logs`, and the worker Pi profile.

## 4.2 Session hygiene

`--reset-session` clears only that workstream's Pi session:

```bash
agentlab run spatial --reset-session
agentlab pi spatial --reset-session
```

Use it when a session is pinned to a model that is no longer available (the
guard tells you) or when you want a clean context for a new task.

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
