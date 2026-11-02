**English** | [中文](usage.zh-CN.md)

# Usage

`agentlab` is the only command required. It runs workers with a **separate Pi
agent directory**, so the daily `pi` configuration remains unchanged.

## 1. Worker Pi profile (one time)

```bash
mkdir -p ~/.pi/agentlab
PI_CODING_AGENT_DIR=~/.pi/agentlab pi /login     # or copy auth.json / models.json
```

Nothing is exported globally. `agentlab` sets `PI_CODING_AGENT_DIR` only for the
child process it starts.

## 2. Configuration (optional)

`~/.config/agentlab/config.toml`:

```toml
[pi]
bin = "pi"
profile = "~/.pi/agentlab"
args = "--model openai/gpt-5"

[runtime]
worktree_root = "~/agentlab-wt"
```

Environment variables `PI_BIN`, `PI_PROFILE`, `PI_ARGS`, and `WT_ROOT` take
precedence over the file.

## 3. Daily workflow

```bash
agentlab doctor                  # check Pi, profile, guard, target repository
agentlab status                  # workstreams, reports, gates, pending decisions

agentlab run <ws>                # one worker: rules -> code -> gate -> commit -> report
agentlab run <ws> --detach       # run it in the background

agentlab status                  # gate and report states updated
agentlab gate <ws>               # gate the worker worktree
agentlab integrate <ws...>       # merge and run the integration gate
```

`agentlab` does not merge the base branch. Review the integration branch and
merge it manually.

## 3.1 Attention inbox (v0.2)

The inbox answers one question: **what needs a human now?**

```bash
agentlab inbox                 # pending and review
agentlab inbox --all           # include fyi
agentlab inbox --json          # machine-readable
agentlab decide <id> --ack     # acknowledge an item
agentlab decide <id> --approve # approve an RFC
agentlab decide <id> --reject  # reject an RFC
agentlab decide <id> --note "reason for the decision"
```

Sources:

- `reports/*.md` with `status: need_decision` or `status: blocked`;
- `RFC/*.md` with `Status: proposed`;
- the latest gate for each workstream with `FAIL` or `UNVERIFIED`;
- the latest worker log with a recognizable failure.

Categories and policy are configured in `.agentlab/target.env`:

```sh
ATTENTION_NEED_DECISION=pending   # pending | review | fyi | ignore
ATTENTION_RFC=pending
ATTENTION_BLOCKED=pending
ATTENTION_GATE_FAIL=pending
ATTENTION_GATE_UNVERIFIED=review
ATTENTION_REPORT_READY=review
ATTENTION_WORKER_FAILURE=pending
```

`pending` is shown first, then `review`; `fyi` is hidden unless `--all` is used.
`agentlab decide` records the decision under `.agentlab/decisions/`. A decision
applies only to the exact content it was made on; a changed report, RFC, gate, or
log produces a new item. Approving or rejecting an RFC also changes its `Status`
field.

## 4. Long runs and interruption

A worker using `thinking=high` can take several minutes. Do not block the terminal:

```bash
agentlab run <ws> --detach
```

The command prints a pid, a log path, and returns immediately. Follow it with:

```bash
agentlab status          # shows "Running in background: <ws> pid NNNN"
tail -f <repo>-wt/logs/<ws>-detached-*.log
kill <pid>               # or kill -TERM <pid> for a clean interruption
```

When a foreground worker is interrupted with Ctrl-C, `run_worker` prints the
worktree state before exiting:

```text
run_worker: interrupted
run_worker: worktree state: head=abc1234 commits_since_main=1 uncommitted=0
run_worker: the work is committed; only the report or the final gate may be missing
```

A detached worker removes its pid file on exit, so `status` stops reporting it.

## 5. Debugging a worker

`agentlab status` lists the newest worker log and its last recognizable error
line. A resumed session keeps the model recorded in its history. If that model is
no longer available, every turn fails inside the provider call:

```text
OpenAI API error (400): model_not_found
```

`agentlab run` detects this before spending a turn:

```text
run_worker: the <ws> session is pinned to an unavailable model: <provider>/<model>
run_worker: fix it with: agentlab run <ws> --reset-session
```

Resolve it with:

```bash
agentlab run <ws> --reset-session     # clears only that workstream's session
agentlab pi <ws> --reset-session      # same, then opens interactive Pi
```

To continue in the worker's session and worktree:

```bash
agentlab pi <ws>
```

## 6. Gate the correct checkout

`agentlab gate <ws>` runs in the **worker worktree** by default. The base
checkout may still contain the unimplemented stub, so gating it can produce a
misleading `UNVERIFIED`.

To force the current checkout:

```bash
agentlab gate <ws> --here
```

`agentlab integrate` refuses a dirty base checkout. Untracked
`.agentlab/repro/*.json` and `.agentlab/decisions/*.json` audit records are the
only exception; they are committed with the integration.

`agentlab status` shows `WORKTREE=repro` when the only uncommitted files are
generated repro or decision records. `clean` means nothing is uncommitted.

## 7. Session hygiene

`--reset-session` clears only that workstream's Pi session:

```bash
agentlab run <ws> --reset-session
agentlab pi <ws> --reset-session
```

Use it when a session is pinned to an unavailable model, or when a new task
requires a clean context.

## 8. Install, update, uninstall

```bash
agentlab install <domain> <target> <repo>   # add a pack; never overwrites
agentlab update                             # update the tool, then re-apply the pack here
agentlab update --no-pull                   # re-apply the pack only
agentlab uninstall                          # remove .agentlab from this repository
agentlab uninstall --force --yes            # also when worktrees still exist
```

`update` performs three steps:

1. `git pull --ff-only` on the tool repository (skipped when dirty or with
   `--no-pull`);
2. re-runs `install` with the domain and target recorded in `.agentlab/.pack`,
   adding only files that do not exist;
3. rebuilds `.agentlab/AGENTS.md`; if it differs, writes
   `.agentlab/AGENTS.md.new` and a diff instead of overwriting local edits.

`uninstall` removes `.agentlab/` and the generated root `AGENTS.md` pointer. It
keeps `agent/*` branches, `<repo>-wt/logs`, and the worker Pi profile.

## 9. Boundaries

`agentlab` never:

- edits `~/.pi/agent` (the daily Pi configuration);
- installs extensions or writes global Pi settings;
- modifies the target repository's source, build, or test layout by itself;
- pushes, merges protected branches, or submits cluster jobs.

## 10. Files written

| Path | Contents |
|---|---|
| `<repo>/.agentlab/reports/` | One report per workstream |
| `<repo>/.agentlab/RFC/` | Proposals awaiting a human |
| `<repo>/.agentlab/repro/` | Gate and run evidence |
| `<repo>-wt/<ws>/` | The worker's git worktree |
| `<repo>-wt/logs/` | One log per worker run |
| `<repo>-wt/sessions/` | Worker Pi sessions |
| `<repo>-wt/run/` | Detached-worker pid files |

## 11. Modes

`AGENTLAB_MODE` in `.agentlab/target.env`:

| Mode | Worker may write | Gate runs |
|---|---|---|
| `audit` | reports, RFCs, repro only | scope only |
| `worker` | its scope paths | scope + build + tests + verification |

`integration` and `release` are gate modes, not worker modes.
