**English** | [中文](platform-support.zh-CN.md)

# Platform Support

Summary: **macOS and Linux are supported natively. Windows requires Git Bash or
WSL. Native PowerShell is not supported.**

## Support matrix

| Platform | Status | Notes |
|---|---|---|
| macOS (Intel / Apple Silicon) | Supported | Uses the system `/bin/bash` 3.2; all scripts are validated on that version |
| Ubuntu / Debian | Supported | Bash 5.x; no additional shell handling required |
| Other Linux (RHEL, Rocky, Arch, Alpine with glibc) | Supported | Requires `bash`, `git`, `python`, and `coreutils` |
| WSL1 / WSL2 | Supported | Equivalent to Linux; keep repositories in the WSL filesystem |
| Windows with Git Bash (MSYS2) | Supported with limitations | See the Windows section |
| Windows PowerShell / cmd | Not supported | No Bash; use Git Bash or WSL |
| FreeBSD / OpenBSD | Not verified | The scripts avoid GNU-only flags; not tested |
| Nix / Guix | Supported with caveats | `bash`, `python3`, and `git` must be available in the environment |

## Dependencies

| Dependency | Used by | If missing |
|---|---|---|
| `bash` >= 3.2 | All platform scripts | Cannot run |
| `git` >= 2.32 | Worktrees, scope, integration | Cannot run |
| `python3` or `python` | `agentlab status`, repro records | `status` fails; other commands still work |
| `coreutils` (`find`, `sed`, `tr`, `cmp`, `diff`, `mktemp`) | Script infrastructure | Included on macOS, Linux, and Git Bash |
| `pi` >= 1.x | Workers | Only `install`, `status`, and `uninstall` work |
| Target build tools (`cmake`, `c++`, ...) | `worker` and `integration` gates | `audit` mode is unaffected |

`agentlab doctor` checks each item and prints the observed version.

## macOS

```bash
agentlab doctor
```

Expected:

```text
host
  ok    bash 3.2.57(1)-release (/bin/bash)
  ok    macOS 14.x
```

Homebrew Bash is not required. The scripts avoid Bash 4+ constructs
(`declare -A`, `${var^^}`, `mapfile`) and GNU-only flags (`sed -i` without a
suffix, `readlink -f`, `date -d`, `grep -P`).

## Linux (Ubuntu / Debian)

```bash
sudo apt-get install -y git python3
```

`bash` and `coreutils` are part of the base system.

## Windows

### Option A: Git Bash

1. Install [Git for Windows](https://git-scm.com/download/win), which includes Git Bash.
2. Run from Git Bash:

```bash
git clone <this-repo> open-research-agents
cd open-research-agents
./bin/agentlab doctor
```

`doctor` reports:

```text
warn  Windows via x86_64-pc-msys (Git Bash/MSYS); native PowerShell is not supported, use Git Bash or WSL
```

Limitations:

- Use POSIX paths (`/c/Users/...`), not `C:\...`.
- The target repository must use the same path convention; otherwise `git worktree`
  creates unexpected directories.
- `agentlab clean` and `uninstall` use MSYS `rm -rf`, which is slower but correct.

### Option B: WSL

```bash
wsl
sudo apt-get install -y git python3
git clone <this-repo> ~/open-research-agents
~/open-research-agents/bin/agentlab doctor
```

Guidelines:

- Keep the target repository in the WSL filesystem (`~/...`), not `/mnt/c/...`.
- Install and authenticate Pi inside WSL:
  `mkdir -p ~/.pi/agentlab && PI_CODING_AGENT_DIR=~/.pi/agentlab pi /login`.
- A Windows checkout and a WSL checkout are separate repositories. Do not edit the
  same files from both sides.

### Why native PowerShell is not supported

`agentlab` is a collection of Bash scripts: worktree management, scope globs, gate
orchestration, `trap` cleanup, and exit-code semantics. A PowerShell port would be
a second implementation and would inevitably diverge. On native Windows, run
workers inside Git Bash or WSL.

## Command guard on Windows

Pi on native Windows can expose the `powershell` tool instead of `bash`.
`platform/extensions/guard.ts` is attached to both tools, so

```text
git push / git merge / gh pr merge / sbatch / srun
```

are blocked in both environments.

## Known platform differences

| Item | macOS / Linux | Windows (Git Bash) |
|---|---|---|
| `agentlab pi` interactive session | Supported | Supported; terminal capabilities depend on Git Bash |
| File locks | None | `rm -rf` may fail while a file is in use; retry |
| Repro hardware fields | CPU model available | `wmic` may be absent; fields may be empty |
| Cluster jobs | Blocked by the guard | Blocked by the guard |

## Compatibility checks

```bash
# Syntax check under Bash 3.2
for f in bin/agentlab scripts/*.sh platform/scripts/*.sh; do /bin/bash -n "$f"; done

# Full platform test (no model calls, no network)
bash tests/platform_smoke.sh
```

Current status: **73 smoke checks and 27 harness-validation checks pass**, on both
macOS `/bin/bash` 3.2 and Bash 5.x.

## If a platform does not work

1. Run `agentlab doctor` and record its output.
2. Run `bash tests/platform_smoke.sh` and identify the failing check.
3. Do not modify scripts to accommodate a single machine before identifying the
   missing dependency.
