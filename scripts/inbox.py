#!/usr/bin/env python3
"""Attention inbox: show only items that need a human.

Reads the target repository's .agentlab state and the worker worktree logs.
Deterministic; no model calls.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path

import tickets

CATEGORIES = ("pending", "review", "fyi")
PRIORITY = {"pending": "P1", "review": "P2", "fyi": "P3"}
DEFAULT_POLICY = {
    "need_decision": "pending",
    "rfc": "pending",
    "blocked": "pending",
    "gate_fail": "pending",
    "gate_unverified": "review",
    "report_ready": "review",
    "worker_failure": "pending",
    "ticket": "pending",
    "ticket_review": "review",
}
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


def repo_root() -> Path:
    out = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=False
    )
    if out.returncode != 0:
        print("inbox: not inside a git repository", file=sys.stderr)
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
        key = key.strip()
        value = value.strip()
        if len(value) >= 2 and value[0] in "\"'" and value[-1] == value[0]:
            value = value[1:-1]
        values[key] = value
    return values


def policy_from_env(env: dict[str, str]) -> dict[str, str]:
    policy = dict(DEFAULT_POLICY)
    mapping = {
        "ATTENTION_NEED_DECISION": "need_decision",
        "ATTENTION_RFC": "rfc",
        "ATTENTION_BLOCKED": "blocked",
        "ATTENTION_GATE_FAIL": "gate_fail",
        "ATTENTION_GATE_UNVERIFIED": "gate_unverified",
        "ATTENTION_REPORT_READY": "report_ready",
        "ATTENTION_WORKER_FAILURE": "worker_failure",
        "ATTENTION_TICKET": "ticket",
        "ATTENTION_TICKET_REVIEW": "ticket_review",
    }
    for key, kind in mapping.items():
        value = env.get(key, "").strip().lower()
        if value in CATEGORIES or value == "ignore":
            policy[kind] = value
    return policy


def fingerprint(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8", errors="replace")).hexdigest()[:16]


def short(text: str, limit: int = 96) -> str:
    text = re.sub(r"\s+", " ", text).strip()
    return text if len(text) <= limit else text[: limit - 1] + "…"


def heading(text: str) -> str:
    for line in text.splitlines():
        if line.startswith("#"):
            return short(line.lstrip("#").strip(), 80)
    return ""


def field(text: str, name: str) -> str:
    pattern = re.compile(r"^\s*" + re.escape(name) + r"\s*:\s*(.*)$", re.IGNORECASE | re.MULTILINE)
    match = pattern.search(text)
    return match.group(1).strip() if match else ""


def report_item(path: Path, policy: dict[str, str]) -> dict[str, object] | None:
    text = path.read_text(encoding="utf-8", errors="replace")
    status = field(text, "status").lower()
    kind = {"need_decision": "need_decision", "blocked": "blocked", "ready": "report_ready"}.get(status)
    if not kind:
        return None
    category = policy.get(kind, "pending")
    if category == "ignore":
        return None
    return {
        "id": f"report:{path.stem}",
        "kind": kind,
        "category": category,
        "title": heading(text) or path.stem,
        "detail": f"status={status} commit={field(text, 'commit') or '-'}",
        "at": field(text, "updated"),
        "path": str(path),
        "fingerprint": fingerprint(text),
    }


def rfc_item(path: Path, policy: dict[str, str]) -> dict[str, object] | None:
    text = path.read_text(encoding="utf-8", errors="replace")
    raw_status = field(text, "status").lower()
    # Older RFC templates write "proposed | approved | rejected (...)". Treat
    # the first word as the status.
    status = raw_status.split()[0] if raw_status.split() else ""
    if status != "proposed":
        return None
    category = policy.get("rfc", "pending")
    if category == "ignore":
        return None
    return {
        "id": f"rfc:{path.stem}",
        "kind": "rfc",
        "category": category,
        "title": heading(text) or path.stem,
        "detail": f"status={status}",
        "at": "",
        "path": str(path),
        "fingerprint": fingerprint(text),
    }


def latest_repro(repro_dir: Path, workstream: str) -> Path | None:
    if not repro_dir.is_dir():
        return None
    files = sorted(repro_dir.glob(f"{workstream}-*.json"), key=lambda p: p.name)
    return files[-1] if files else None


def gate_item(path: Path, workstream: str, policy: dict[str, str]) -> dict[str, object] | None:
    try:
        record = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    status = str(record.get("gate_status", "")).lower()
    kind = "gate_fail" if status in ("fail", "failed") else "gate_unverified" if status == "unverified" else None
    if not kind:
        return None
    category = policy.get(kind, "pending")
    if category == "ignore":
        return None
    return {
        "id": f"gate:{workstream}:{path.name}",
        "kind": kind,
        "category": category,
        "title": f"{workstream} gate {status}",
        "detail": f"mode={record.get('gate_mode', '-')} commit={str(record.get('git_commit', ''))[:9] or '-'}",
        "at": record.get("time_utc", ""),
        "path": str(path),
        "fingerprint": fingerprint(path.read_text(encoding="utf-8", errors="replace")),
    }


def latest_log(wt_root: Path, workstream: str) -> Path | None:
    log_dir = wt_root / "logs"
    if not log_dir.is_dir():
        return None
    files = sorted(log_dir.glob(f"{workstream}-*.log"), key=lambda p: p.name)
    return files[-1] if files else None


def worker_item(path: Path, workstream: str, policy: dict[str, str]) -> dict[str, object] | None:
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    error = ""
    for line in lines:
        stripped = line.strip()
        if stripped.startswith(ERROR_MARKERS):
            error = stripped
    if not error:
        return None
    category = policy.get("worker_failure", "pending")
    if category == "ignore":
        return None
    tail = "\n".join(lines[-200:])
    return {
        "id": f"worker:{workstream}:{path.name}",
        "kind": "worker_failure",
        "category": category,
        "title": f"{workstream} worker failed",
        "detail": short(error, 120),
        "at": "",
        "path": str(path),
        "fingerprint": fingerprint(tail),
    }


def ticket_items(agentlab: Path, policy: dict[str, str]) -> list[dict[str, object]]:
    items: list[dict[str, object]] = []
    directory = agentlab / "tickets"
    if not directory.is_dir():
        return items
    for path in sorted(directory.glob("*.json")):
        try:
            ticket = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        status = ticket.get("status")
        if status in ("proposed", "stale", "blocked"):
            kind = "ticket"
        elif status == "review":
            kind = "ticket_review"
        else:
            continue
        category = policy.get(kind, "pending")
        if category == "ignore":
            continue
        items.append({
            "id": f"ticket:{ticket.get('id', path.stem)}",
            "kind": kind,
            "category": category,
            "title": str(ticket.get("title", path.stem)),
            "detail": f"status={status} workstream={ticket.get('workstream', '-')} policy={ticket.get('policy_version', '-')}",
            "at": ticket.get("updated_at", ""),
            "path": str(path),
            "fingerprint": fingerprint(path.read_text(encoding="utf-8", errors="replace")),
        })
    return items


def load_decisions(decisions_dir: Path) -> dict[str, set[str]]:
    decisions: dict[str, set[str]] = {}
    if not decisions_dir.is_dir():
        return decisions
    for path in decisions_dir.glob("*.json"):
        try:
            record = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        item_id = record.get("id")
        fp = record.get("fingerprint")
        if isinstance(item_id, str) and isinstance(fp, str):
            decisions.setdefault(item_id, set()).add(fp)
    return decisions


def collect(root: Path) -> tuple[dict[str, str], list[dict[str, object]]]:
    agentlab = root / ".agentlab"
    env = read_env(agentlab / "domain.env")
    env.update(read_env(agentlab / "target.env"))
    policy = policy_from_env(env)
    modules = env.get("MODULES", "").split()
    wt_root = Path(os.environ.get("WT_ROOT") or (root.parent / f"{root.name}-wt"))
    decisions = load_decisions(agentlab / "decisions")

    items: list[dict[str, object]] = []
    for path in sorted((agentlab / "reports").glob("*.md")):
        item = report_item(path, policy)
        if item:
            items.append(item)
    for path in sorted((agentlab / "RFC").glob("*.md")):
        item = rfc_item(path, policy)
        if item:
            items.append(item)
    items.extend(ticket_items(agentlab, policy))
    for ws in modules:
        path = latest_repro(agentlab / "repro", ws)
        if path:
            item = gate_item(path, ws, policy)
            if item:
                items.append(item)
        log = latest_log(wt_root, ws)
        if log:
            item = worker_item(log, ws, policy)
            if item:
                items.append(item)

    visible: list[dict[str, object]] = []
    for item in items:
        if item["category"] == "ignore":
            continue
        if item["fingerprint"] in decisions.get(str(item["id"]), set()):
            continue
        visible.append(item)
    visible.sort(key=lambda i: (CATEGORIES.index(str(i["category"])), str(i["id"])))
    return policy, visible


def print_items(root: Path, policy: dict[str, str], items: list[dict[str, object]], show_all: bool) -> None:
    shown = [i for i in items if show_all or i["category"] != "fyi"]
    print(f"Attention Inbox — {root}")
    print("policy: " + " ".join(f"{k}={v}" for k, v in sorted(policy.items())))
    print()
    if not shown:
        print("No items need attention.")
        return
    for category in CATEGORIES:
        group = [i for i in shown if i["category"] == category]
        if not group:
            continue
        print(f"{category} ({len(group)})")
        for item in group:
            print(f"  [{PRIORITY[category]}] {str(item['id']):<38} {str(item['kind']):<16} {item['title']}")
            if item["detail"]:
                print(f"       {item['detail']}")
        print()
    print("Decide: agentlab decide <id> --ack|--approve|--reject --note \"...\"")


def command_inbox(args: argparse.Namespace) -> int:
    root = repo_root()
    if not (root / ".agentlab" / "domain.env").is_file():
        print("inbox: .agentlab/ not found; run: agentlab install <domain> <target> <repo>", file=sys.stderr)
        return 2
    policy, items = collect(root)
    if args.json:
        json.dump({"repo": str(root), "policy": policy, "items": items}, sys.stdout, indent=2, ensure_ascii=False)
        print()
    else:
        print_items(root, policy, items, args.all)
    return 0


def command_decide(args: argparse.Namespace) -> int:
    root = repo_root()
    agentlab = root / ".agentlab"
    if not (agentlab / "domain.env").is_file():
        print("decide: .agentlab/ not found", file=sys.stderr)
        return 2
    policy, items = collect(root)
    item = next((i for i in items if i["id"] == args.id), None)
    if not item:
        print(f"decide: no open item with id {args.id}", file=sys.stderr)
        return 2
    decision = "approved" if args.approve else "rejected" if args.reject else "acknowledged"

    if item["kind"] == "ticket":
        ticket_id = str(item["id"]).split(":", 1)[1]
        if decision == "approved":
            tickets.transition(root, tickets.load(root, ticket_id), "authorized",
                               args.note or "attention inbox approval", "human")
        elif decision == "rejected":
            tickets.transition(root, tickets.load(root, ticket_id), "rejected",
                               args.note or "attention inbox rejection", "human")
        else:
            print("decide: a ticket requires --approve or --reject", file=sys.stderr)
            return 2
    elif item["kind"] == "ticket_review" and decision != "acknowledged":
        print("decide: a ticket review requires --ack", file=sys.stderr)
        return 2

    if item["kind"] == "rfc" and decision in ("approved", "rejected"):
        path = Path(str(item["path"]))
        text = path.read_text(encoding="utf-8")
        updated = re.sub(r"(?im)^(\s*status\s*:\s*).*$", r"\1" + decision, text, count=1)
        if updated == text:
            print("decide: RFC has no Status field; not modified", file=sys.stderr)
            return 2
        path.write_text(updated)

    decisions_dir = agentlab / "decisions"
    decisions_dir.mkdir(parents=True, exist_ok=True)
    safe = re.sub(r"[^A-Za-z0-9_.-]+", "_", args.id)[:120]
    record = {
        "id": args.id,
        "kind": item["kind"],
        "decision": decision,
        "note": args.note or "",
        "fingerprint": item["fingerprint"],
        "at": __import__("datetime").datetime.now(__import__("datetime").timezone.utc).isoformat(),
        "path": item["path"],
    }
    (decisions_dir / f"{safe}.json").write_text(json.dumps(record, indent=2, ensure_ascii=False) + "\n")
    print(f"decided {args.id}: {decision}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="agentlab attention inbox")
    sub = parser.add_subparsers(dest="command", required=True)

    inbox = sub.add_parser("inbox", help="show items that need a human")
    inbox.add_argument("--json", action="store_true")
    inbox.add_argument("--all", action="store_true", help="include fyi items")
    inbox.set_defaults(func=command_inbox)

    decide = sub.add_parser("decide", help="record a decision for one item")
    decide.add_argument("id")
    group = decide.add_mutually_exclusive_group()
    group.add_argument("--approve", action="store_true")
    group.add_argument("--reject", action="store_true")
    decide.add_argument("--ack", action="store_true", help="acknowledge without changing an RFC")
    decide.add_argument("--note", default="")
    decide.set_defaults(func=command_decide)
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
