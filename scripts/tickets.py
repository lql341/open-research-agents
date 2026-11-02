#!/usr/bin/env python3
"""Ticket ledger: authorization records for workstream tasks.

v0.3 is a ledger, not an execution scheduler. It records why a task is allowed,
which policy snapshot it relied on, and its lifecycle. Workers still operate from
the workstream scope and gate.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,63}$")
STATUSES = (
    "proposed", "authorized", "running", "review", "blocked",
    "ended", "stopped", "rejected", "stale",
)
TRANSITIONS = {
    "proposed": {"authorized", "rejected", "stale", "stopped"},
    "authorized": {"running", "blocked", "stopped", "stale"},
    "running": {"review", "blocked", "ended", "stopped", "stale"},
    "review": {"running", "blocked", "ended", "stopped", "stale"},
    "blocked": {"running", "ended", "stopped", "stale"},
    "ended": {"running", "stopped", "stale"},
    "stale": {"authorized", "rejected", "stopped"},
    "stopped": set(),
    "rejected": set(),
}


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def repo_root() -> Path:
    import subprocess
    out = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=False)
    if out.returncode != 0:
        print("ticket: not inside a git repository", file=sys.stderr)
        raise SystemExit(2)
    return Path(out.stdout.strip())


def read_env(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.is_file():
        return values
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key, value = key.strip(), value.strip()
        if len(value) >= 2 and value[0] in "\"'" and value[-1] == value[0]:
            value = value[1:-1]
        values[key] = value
    return values


def hash_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8", errors="replace")).hexdigest()


def policy_snapshot(root: Path) -> tuple[str, str]:
    """Hash the human-owned policy inputs and the workstream scope files.

    Returns (policy_version, scope_digest). Changing a contract, scope, AGENTS
    file, mode, target, or base ref invalidates existing tickets.
    """
    agentlab = root / ".agentlab"
    env = read_env(agentlab / "domain.env")
    env.update(read_env(agentlab / "target.env"))
    parts: list[str] = []
    for rel in ("AGENTS.md", "domain.env", "target.env"):
        path = agentlab / rel
        if path.is_file():
            parts.append(f"== {rel}\n" + path.read_text(encoding="utf-8", errors="replace"))
    for directory in ("contracts", "scope"):
        base = agentlab / directory
        if base.is_dir():
            for path in sorted(base.glob("*")):
                if path.is_file():
                    parts.append(f"== {directory}/{path.name}\n" + path.read_text(encoding="utf-8", errors="replace"))
    parts.append(f"== mode\n{env.get('AGENTLAB_MODE', 'worker')}")
    parts.append(f"== target\n{env.get('TARGET', 'target')}")
    parts.append(f"== base\n{env.get('BASE_REF', 'main')}")
    digest = hash_text("\n".join(parts))
    scope_digest = hash_text("\n".join(
        f"{p.name}\n{p.read_text(encoding='utf-8', errors='replace')}"
        for p in sorted((agentlab / "scope").glob("*.txt"))
    ))
    return digest[:16], scope_digest[:16]


def load(root: Path, ticket_id: str) -> dict:
    path = root / ".agentlab" / "tickets" / f"{ticket_id}.json"
    if not path.is_file():
        print(f"ticket: no ticket {ticket_id}", file=sys.stderr)
        raise SystemExit(2)
    return json.loads(path.read_text(encoding="utf-8"))


def save(root: Path, ticket: dict) -> None:
    directory = root / ".agentlab" / "tickets"
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / f"{ticket['id']}.json"
    path.write_text(json.dumps(ticket, indent=2, ensure_ascii=False) + "\n")


def transition(root: Path, ticket: dict, to: str, reason: str = "", actor: str = "human") -> dict:
    current = ticket.get("status", "proposed")
    if to not in STATUSES:
        print(f"ticket: unknown status {to}", file=sys.stderr)
        raise SystemExit(2)
    if to not in TRANSITIONS.get(current, set()) and to != current:
        print(f"ticket: cannot move {current} -> {to}", file=sys.stderr)
        raise SystemExit(2)
    if to == "authorized":
        version, _ = policy_snapshot(root)
        ticket["policy_version"] = version
    ticket["status"] = to
    ticket["updated_at"] = now()
    if reason:
        ticket["reason"] = reason
    ticket.setdefault("history", []).append({
        "at": ticket["updated_at"], "from": current, "to": to, "actor": actor, "reason": reason,
    })
    save(root, ticket)
    return ticket


def create(root: Path, ticket_id: str, title: str, workstream: str,
           source: str = "manual", sender: str = "human",
           strength: str = "explicit", rule: str = "manual",
           reason: str = "", status: str = "proposed") -> dict:
    agentlab = root / ".agentlab"
    if not (agentlab / "domain.env").is_file():
        raise ValueError(".agentlab/ not found")
    if not ID_RE.match(ticket_id):
        raise ValueError("id must be lowercase letters, digits, or hyphens")
    path = agentlab / "tickets" / f"{ticket_id}.json"
    if path.exists():
        raise ValueError(f"{ticket_id} already exists")
    scope_file = agentlab / "scope" / f"{workstream}.txt"
    if not scope_file.is_file():
        raise ValueError(f"no scope for workstream {workstream}")
    if status not in ("proposed", "authorized"):
        raise ValueError("a new ticket must be proposed or authorized")
    version, scope_digest = policy_snapshot(root)
    timestamp = now()
    history = [{"at": timestamp, "from": "", "to": "proposed", "actor": "human", "reason": reason}]
    if status == "authorized":
        history.append({"at": timestamp, "from": "proposed", "to": "authorized", "actor": "human", "reason": reason})
    ticket = {
        "id": ticket_id,
        "title": title,
        "workstream": workstream,
        "source": source,
        "sender": sender,
        "strength": strength,
        "rule": rule,
        "policy_version": version,
        "scope_ref": f".agentlab/scope/{workstream}.txt",
        "scope_hash": scope_digest,
        "status": status,
        "reason": reason,
        "created_at": timestamp,
        "updated_at": timestamp,
        "history": history,
    }
    save(root, ticket)
    return ticket


def command_new(args: argparse.Namespace) -> int:
    root = repo_root()
    try:
        ticket = create(root, args.id, args.title, args.workstream, args.source, args.sender,
                        args.strength, args.rule, args.reason, "proposed")
    except ValueError as error:
        print(f"ticket: {error}", file=sys.stderr)
        return 2
    print(f"ticket {ticket['id']}: proposed (policy {ticket['policy_version']})")
    return 0


def command_list(args: argparse.Namespace) -> int:
    root = repo_root()
    directory = root / ".agentlab" / "tickets"
    tickets = []
    if directory.is_dir():
        for path in sorted(directory.glob("*.json")):
            try:
                ticket = json.loads(path.read_text(encoding="utf-8"))
            except ValueError:
                continue
            if args.status and ticket.get("status") != args.status:
                continue
            tickets.append(ticket)
    if args.json:
        json.dump(tickets, sys.stdout, indent=2, ensure_ascii=False)
        print()
        return 0
    if not tickets:
        print("No tickets.")
        return 0
    print(f"{'ID':<28}{'WORKSTREAM':<16}{'STATUS':<12}{'POLICY':<18}TITLE")
    for t in tickets:
        print(f"{t['id']:<28}{t.get('workstream', '-'):<16}{t.get('status', '-'):<12}{t.get('policy_version', '-'):<18}{t.get('title', '')}")
    return 0


def command_show(args: argparse.Namespace) -> int:
    root = repo_root()
    ticket = load(root, args.id)
    if args.json:
        json.dump(ticket, sys.stdout, indent=2, ensure_ascii=False)
        print()
        return 0
    for key in ("id", "title", "workstream", "status", "source", "sender", "strength", "rule",
                "policy_version", "scope_ref", "scope_hash", "reason", "created_at", "updated_at"):
        print(f"{key}: {ticket.get(key, '')}")
    print("history:")
    for entry in ticket.get("history", []):
        print(f"  {entry.get('at')} {entry.get('from') or '-'} -> {entry.get('to')} ({entry.get('actor')}) {entry.get('reason', '')}")
    return 0


def command_set(args: argparse.Namespace) -> int:
    root = repo_root()
    ticket = load(root, args.id)
    transition(root, ticket, args.status, args.reason or "", "human")
    print(f"ticket {args.id}: {ticket['status']}")
    return 0


def command_authorize(args: argparse.Namespace) -> int:
    root = repo_root()
    ticket = load(root, args.id)
    transition(root, ticket, "authorized", args.reason or "human approval", "human")
    print(f"ticket {args.id}: authorized (policy {ticket['policy_version']})")
    return 0


def command_reject(args: argparse.Namespace) -> int:
    root = repo_root()
    ticket = load(root, args.id)
    transition(root, ticket, "rejected", args.reason or "rejected by human", "human")
    print(f"ticket {args.id}: rejected")
    return 0


def command_revalidate(args: argparse.Namespace) -> int:
    root = repo_root()
    ticket = load(root, args.id)
    current, _ = policy_snapshot(root)
    if current == ticket.get("policy_version"):
        print(f"ticket {args.id}: policy current ({current})")
        return 0
    transition(root, ticket, "stale", f"policy changed {ticket.get('policy_version')} -> {current}", "system")
    print(f"ticket {args.id}: stale; human authorize is required")
    return 0


def command_resume(args: argparse.Namespace) -> int:
    root = repo_root()
    ticket = load(root, args.id)
    current, _ = policy_snapshot(root)
    if current != ticket.get("policy_version"):
        transition(root, ticket, "stale", f"policy changed {ticket.get('policy_version')} -> {current}", "system")
        print(f"ticket {args.id}: stale; authorize before resuming", file=sys.stderr)
        return 1
    if ticket.get("status") not in ("ended", "blocked"):
        print(f"ticket {args.id}: cannot resume from {ticket.get('status')}", file=sys.stderr)
        return 2
    transition(root, ticket, "running", args.reason or "resumed by human", "human")
    print(f"ticket {args.id}: running")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="agentlab ticket ledger")
    sub = parser.add_subparsers(dest="command", required=True)

    new = sub.add_parser("new")
    new.add_argument("id")
    new.add_argument("--title", required=True)
    new.add_argument("--workstream", required=True)
    new.add_argument("--source", default="manual")
    new.add_argument("--sender", default="human")
    new.add_argument("--strength", choices=("explicit", "inferred"), default="explicit")
    new.add_argument("--rule", default="manual")
    new.add_argument("--reason", default="")
    new.set_defaults(func=command_new)

    ls = sub.add_parser("list")
    ls.add_argument("--status", choices=STATUSES)
    ls.add_argument("--json", action="store_true")
    ls.set_defaults(func=command_list)

    show = sub.add_parser("show")
    show.add_argument("id")
    show.add_argument("--json", action="store_true")
    show.set_defaults(func=command_show)

    st = sub.add_parser("set")
    st.add_argument("id")
    st.add_argument("status", choices=STATUSES)
    st.add_argument("--reason", default="")
    st.set_defaults(func=command_set)

    auth = sub.add_parser("authorize")
    auth.add_argument("id")
    auth.add_argument("--reason", default="")
    auth.set_defaults(func=command_authorize)

    rej = sub.add_parser("reject")
    rej.add_argument("id")
    rej.add_argument("--reason", default="")
    rej.set_defaults(func=command_reject)

    reval = sub.add_parser("revalidate")
    reval.add_argument("id")
    reval.set_defaults(func=command_revalidate)

    resume = sub.add_parser("resume")
    resume.add_argument("id")
    resume.add_argument("--reason", default="")
    resume.set_defaults(func=command_resume)
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
