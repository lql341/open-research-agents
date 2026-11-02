#!/usr/bin/env python3
"""Summarise a target repository's agent-lab state.

Reads only files under <repo>/.agentlab and read-only git queries.
Never writes, never builds, never starts a worker.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path


def git(root: Path, *args: str) -> str:
    try:
        out = subprocess.run(
            ["git", "-C", str(root), *args],
            capture_output=True, text=True, check=False,
        )
        return out.stdout.strip()
    except OSError:
        return ""


def repo_root() -> Path:
    cwd = Path.cwd()
    top = git(cwd, "rev-parse", "--show-toplevel")
    if not top:
        print("agentlab: not inside a git repository", file=sys.stderr)
        raise SystemExit(2)
    return Path(top)


def read_env(path: Path) -> dict[str, str]:
    """Parse KEY=VALUE lines from domain.env / target.env; ignore comments."""
    values: dict[str, str] = {}
    if not path.is_file():
        return values
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip()
        if value.startswith(("'", '"')) and value.endswith(("'", '"')) and len(value) >= 2:
            value = value[1:-1]
        values[key] = value
    return values


def latest_gate(repro_dirs: list[Path], workstream: str, root: Path, ref: str | None) -> dict | None:
    """Newest repro record across the branch, the main checkout and the worktree."""
    prefix = f".agentlab/repro/{workstream}-"
    names: list[str] = []
    if ref:
        out = subprocess.run(
            ["git", "-C", str(root), "ls-tree", "-r", "--name-only", ref, "--", ".agentlab/repro"],
            capture_output=True, text=True, check=False,
        )
        if out.returncode == 0:
            names = [line.strip() for line in out.stdout.splitlines() if line.startswith(prefix)]
    for directory in repro_dirs:
        if not directory.is_dir():
            continue
        for path in directory.glob(f"{workstream}-*.json"):
            try:
                names.append(str(path.resolve().relative_to(root.resolve())))
            except ValueError:
                # A worktree lives outside the main checkout; key it by filename.
                names.append(str(path))
    # Names may be absolute for worktrees; sort by basename (timestamped).
    names = sorted(set(names), key=lambda n: Path(n).name)
    for rel in reversed(names):
        text = read_from_ref(root, ref, rel) if ref and not Path(rel).is_absolute() else None
        if text is None:
            path = Path(rel) if Path(rel).is_absolute() else root / rel
            text = path.read_text(encoding="utf-8") if path.is_file() else None
        if not text:
            continue
        try:
            record = json.loads(text)
        except ValueError:
            continue
        return {
            "file": Path(rel).name,
            "mode": record.get("gate_mode", "?"),
            "status": record.get("gate_status", "?"),
            "commit": (record.get("git_commit") or "")[:9],
        }
    return None


def read_from_ref(root: Path, ref: str, rel: str) -> str | None:
    """Read a file from a git ref, or None when it does not exist there."""
    out = subprocess.run(
        ["git", "-C", str(root), "show", f"{ref}:{rel}"],
        capture_output=True, text=True, check=False,
    )
    return out.stdout if out.returncode == 0 else None


def report_status(text: str | None) -> tuple[str, str]:
    if not text:
        return "missing", ""
    status, commit, updated = "unknown", "", ""
    for line in text.splitlines()[:20]:
        stripped = line.strip()
        for key in ("status:", "commit:", "updated:"):
            if stripped.lower().startswith(key):
                value = stripped[len(key):].strip()
                if key == "status:":
                    status = value.split()[0] if value else "unknown"
                elif key == "commit:":
                    commit = value.split()[0][:9] if value else ""
                else:
                    updated = value
    return status, f"{commit} {updated}".strip()


ERROR_MARKERS = (
    "OpenAI API error",
    "API error",
    "Error:",
    "error:",
    "FAILED:",
    "worker made no commit",
    "pinned to an unavailable model",
    "Cannot read",
)


def recent_log(wt_root: Path, workstream: str) -> tuple[str, str] | None:
    """Newest worker log for a workstream, with its last recognisable error line."""
    log_dir = wt_root / "logs"
    if not log_dir.is_dir():
        return None
    files = sorted(log_dir.glob(f"{workstream}-*.log"), key=lambda p: p.stat().st_mtime)
    if not files:
        return None
    last = files[-1]
    try:
        lines = last.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return None
    error = ""
    for line in lines:
        stripped = line.strip()
        if stripped.startswith(ERROR_MARKERS):
            error = stripped[:150]
    return last.name, error


def detached_state(wt_root: Path, workstream: str) -> dict | None:
    """A detached worker's pid file, and whether the process is still alive."""
    pid_file = wt_root / "run" / f"{workstream}.pid"
    if not pid_file.is_file():
        return None
    try:
        pid = int(pid_file.read_text().strip())
    except (OSError, ValueError):
        return None
    alive = False
    try:
        os.kill(pid, 0)
        alive = True
    except OSError:
        alive = False
    return {"pid": pid, "alive": alive}


def pending_rfcs(root: Path, agentlab: Path, ref: str | None) -> list[tuple[str, str]]:
    """RFCs with `Status: proposed`, read from the worker branch when it exists."""
    items: list[tuple[str, str]] = []
    names: list[str] = []
    if ref:
        out = subprocess.run(
            ["git", "-C", str(root), "ls-tree", "-r", "--name-only", ref, "--", ".agentlab/RFC"],
            capture_output=True, text=True, check=False,
        )
        if out.returncode == 0:
            names = [line.strip() for line in out.stdout.splitlines() if line.strip().endswith(".md")]
    local = sorted((agentlab / "RFC").glob("*.md")) if (agentlab / "RFC").is_dir() else []
    names.extend(str(p.relative_to(root)) for p in local)
    for rel in sorted(set(names)):
        text = read_from_ref(root, ref, rel) if ref else None
        if text is None:
            path = root / rel
            text = path.read_text(encoding="utf-8") if path.is_file() else None
        if not text:
            continue
        status = ""
        for line in text.splitlines()[:15]:
            low = line.strip().lower()
            if low.startswith("status:"):
                status = line.split(":", 1)[1].strip()
        if status.lower().startswith("proposed"):
            items.append((Path(rel).name, status))
    return items


def main(argv: list[str]) -> int:
    as_json = "--json" in argv
    root = repo_root()
    agentlab = root / ".agentlab"
    if not (agentlab / "domain.env").is_file():
        print(f"agentlab: {agentlab} not found; run: agentlab install <domain> <target> <repo>",
              file=sys.stderr)
        return 2

    env = read_env(agentlab / "domain.env")
    env.update(read_env(agentlab / "target.env"))
    modules = env.get("MODULES", "").split()
    base = env.get("BASE_REF", "main")
    mode = env.get("AGENTLAB_MODE", "worker")

    wt_root = Path(os.environ.get("WT_ROOT") or (root.parent / f"{root.name}-wt"))
    reports = agentlab / "reports"
    repro = agentlab / "repro"
    rfcs = agentlab / "RFC"

    rows = []
    for ws in modules:
        branch = f"agent/{ws}"
        has_branch = bool(git(root, "rev-parse", "--verify", branch))
        text = read_from_ref(root, branch, f".agentlab/reports/{ws}.md") if has_branch else None
        if text is None:
            path = reports / f"{ws}.md"
            text = path.read_text(encoding="utf-8") if path.is_file() else None
        status, meta = report_status(text)
        wt = wt_root / ws
        gate = latest_gate([repro, wt / ".agentlab" / "repro"], ws, root,
                           branch if has_branch else None)
        wt_state = "-"
        if wt.is_dir():
            lines = [line for line in git(wt, "status", "--porcelain").splitlines() if line.strip()]
            if not lines:
                wt_state = "clean"
            elif all(
                line.startswith(("?? .agentlab/repro/", "?? .agentlab/decisions/", "?? .agentlab/tickets/",
                                 "?? .agentlab/candidates/", "?? .agentlab/sources/"))
                for line in lines
            ):
                wt_state = "repro"
            else:
                wt_state = "dirty"
        ahead = git(root, "rev-list", "--count", f"{base}..{branch}") if has_branch else "0"
        log = recent_log(wt_root, ws)
        detached = detached_state(wt_root, ws)
        rows.append({
            "workstream": ws,
            "report": status,
            "report_meta": meta,
            "gate": f"{gate['mode']}:{gate['status']}" if gate else "-",
            "gate_commit": (gate or {}).get("commit", ""),
            "worktree": wt_state,
            "branch": "yes" if has_branch else "no",
            "ahead": ahead,
            "log": (log or ("", ""))[0],
            "log_error": (log or ("", ""))[1],
            "detached": detached,
        })

    base_exists = bool(git(root, "rev-parse", "--verify", base))
    rfcs_pending: list[tuple[str, str]] = []
    for ws in modules:
        ref = f"agent/{ws}" if git(root, "rev-parse", "--verify", f"agent/{ws}") else None
        for item in pending_rfcs(root, agentlab, ref):
            if item not in rfcs_pending:
                rfcs_pending.append(item)

    if as_json:
        json.dump({
            "repo": str(root),
            "base_ref": base,
            "mode": mode,
            "workstreams": rows,
            "pending_rfcs": [{"file": name, "status": status} for name, status in rfcs_pending],
        }, sys.stdout, indent=2, ensure_ascii=False)
        print()
        return 0

    print(f"agentlab status — {root}")
    print(f"base ref : {base}          mode : {mode}")
    if not base_exists:
        print(f"  warning: base ref '{base}' not found; AHEAD counts and merges will fail")
    print()
    header = f"{'WORKSTREAM':<14}{'REPORT':<16}{'GATE':<18}{'WORKTREE':<10}{'BRANCH':<8}{'AHEAD':<6}"
    print(header)
    print("-" * len(header))
    for row in rows:
        print(f"{row['workstream']:<14}{row['report']:<16}{row['gate']:<18}"
              f"{row['worktree']:<10}{row['branch']:<8}{row['ahead']:<6}")
    # Detached workers replace the "no worktree" dash with a live marker.
    running = [row for row in rows if row["detached"] and row["detached"]["alive"]]
    if running:
        print("Running in background:")
        for row in running:
            print(f"  {row['workstream']:<14}pid {row['detached']['pid']}  "
                  f"stop with: kill {row['detached']['pid']}")
        print()

    print()
    for row in rows:
        if row["report_meta"]:
            print(f"  {row['workstream']}: {row['report_meta']}")
    if any(row["report_meta"] for row in rows):
        print()

    logs = [row for row in rows if row["log"]]
    if logs:
        print("Recent worker logs:")
        for row in logs:
            print(f"  {row['workstream']:<14}{row['log']}")
            if row["log_error"]:
                print(f"                {row['log_error']}")
        print()

    if rfcs_pending:
        print("Pending decisions (RFC status: proposed):")
        for name, _ in rfcs_pending:
            print(f"  .agentlab/RFC/{name}")
    else:
        print("Pending decisions: none")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
