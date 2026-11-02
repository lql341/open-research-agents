#!/usr/bin/env python3
"""GitHub notification source (read-only intake).

Polls GitHub notifications through the authenticated `gh` CLI, or reads a saved
JSON fixture with `--input`. Each notification becomes a candidate in
`.agentlab/candidates/`; it does not create a ticket until a human approves it.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

EXPLICIT_REASONS = {"mention", "review_requested", "assign", "team_mention"}
ADMITTED_REASONS = EXPLICIT_REASONS | {"comment", "ci_activity", "state_change", "subscribed"}


def repo_root() -> Path:
    out = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=False)
    if out.returncode != 0:
        print("source github: not inside a git repository", file=sys.stderr)
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


def resolve_repo(root: Path, explicit: str | None) -> str:
    if explicit:
        return explicit
    env = read_env(root / ".agentlab" / "domain.env")
    env.update(read_env(root / ".agentlab" / "target.env"))
    if env.get("GITHUB_REPOSITORY"):
        return env["GITHUB_REPOSITORY"]
    out = subprocess.run(
        ["gh", "repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner"],
        cwd=root, capture_output=True, text=True, check=False,
    )
    return out.stdout.strip() if out.returncode == 0 else ""


def load_notifications(args: argparse.Namespace) -> list[dict]:
    if args.input:
        payload = json.loads(Path(args.input).read_text(encoding="utf-8"))
        if isinstance(payload, dict):
            payload = payload.get("notifications", [])
        if not isinstance(payload, list):
            raise ValueError("--input must contain a notification list")
        return payload
    out = subprocess.run(
        ["gh", "api", "/notifications?all=true&per_page=100"],
        cwd=repo_root(), capture_output=True, text=True, check=False,
    )
    if out.returncode != 0:
        message = out.stderr.strip() or "gh api failed"
        print(f"source github: {message}", file=sys.stderr)
        raise SystemExit(1)
    payload = json.loads(out.stdout or "[]")
    return payload if isinstance(payload, list) else []


def compact_timestamp(value: str) -> str:
    return re.sub(r"[^0-9a-zA-Z]", "", value).lower()


def html_url(api_url: str) -> str:
    if not api_url:
        return ""
    url = api_url.replace("api.github.com/repos/", "github.com/")
    url = url.replace("/pulls/", "/pull/")
    return url


def strength_for(reason: str) -> str:
    return "explicit" if reason in EXPLICIT_REASONS else "inferred"


def candidate_from(notification: dict, repo: str) -> dict | None:
    if notification.get("repository", {}).get("full_name") not in (None, repo):
        return None
    reason = str(notification.get("reason", "subscribed"))
    if reason not in ADMITTED_REASONS:
        return None
    subject = notification.get("subject") or {}
    notification_id = str(notification.get("id", ""))
    updated = str(notification.get("updated_at", ""))
    if not notification_id or not updated:
        return None
    candidate_id = f"gh-{notification_id}-{compact_timestamp(updated)}"
    title = str(subject.get("title") or "Untitled notification")
    subject_type = str(subject.get("type") or "Notification")
    url = html_url(str(subject.get("latest_comment_url") or subject.get("url") or ""))
    return {
        "id": candidate_id,
        "source": "github",
        "repo": repo,
        "notification_id": notification_id,
        "reason": reason,
        "subject_type": subject_type,
        "title": title,
        "url": url,
        "strength": strength_for(reason),
        "sender": "unknown",
        "status": "pending",
        "observed_at": datetime.now(timezone.utc).isoformat(),
        "updated_at": updated,
    }


def save_candidate(root: Path, candidate: dict) -> bool:
    directory = root / ".agentlab" / "candidates"
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / f"{candidate['id']}.json"
    if path.exists():
        return False
    path.write_text(json.dumps(candidate, indent=2, ensure_ascii=False) + "\n")
    return True


def write_state(root: Path, repo: str, fetched: int, created: int) -> None:
    directory = root / ".agentlab" / "sources"
    directory.mkdir(parents=True, exist_ok=True)
    state = {
        "source": "github",
        "repo": repo,
        "last_poll": datetime.now(timezone.utc).isoformat(),
        "fetched": fetched,
        "created": created,
    }
    (directory / "github.json").write_text(json.dumps(state, indent=2, ensure_ascii=False) + "\n")


def command_poll(args: argparse.Namespace) -> int:
    root = repo_root()
    repo = resolve_repo(root, args.repo)
    if not repo:
        print("source github: repository not configured; use --repo owner/name or GITHUB_REPOSITORY", file=sys.stderr)
        return 2
    try:
        notifications = load_notifications(args)
    except (OSError, ValueError) as error:
        print(f"source github: {error}", file=sys.stderr)
        return 1
    created = 0
    skipped = 0
    candidates = []
    for notification in notifications[: args.limit]:
        candidate = candidate_from(notification, repo)
        if not candidate:
            skipped += 1
            continue
        if save_candidate(root, candidate):
            created += 1
            candidates.append(candidate)
        else:
            skipped += 1
    write_state(root, repo, len(notifications), created)
    result = {"repo": repo, "fetched": len(notifications), "created": created,
              "skipped": skipped, "candidates": candidates}
    if args.json:
        json.dump(result, sys.stdout, indent=2, ensure_ascii=False)
        print()
    else:
        print(f"github source: repo={repo} fetched={len(notifications)} created={created} skipped={skipped}")
        for candidate in candidates:
            print(f"  candidate:{candidate['id']}  {candidate['title']}")
            print(f"       reason={candidate['reason']} strength={candidate['strength']} {candidate['url']}")
        if created:
            print("Review with: agentlab inbox")
            print("Approve with: agentlab decide candidate:<id> --approve --workstream <ws>")
    return 0


def command_status(args: argparse.Namespace) -> int:
    root = repo_root()
    state_path = root / ".agentlab" / "sources" / "github.json"
    state = {}
    if state_path.is_file():
        try:
            state = json.loads(state_path.read_text(encoding="utf-8"))
        except ValueError:
            state = {}
    pending = 0
    directory = root / ".agentlab" / "candidates"
    if directory.is_dir():
        for path in directory.glob("*.json"):
            try:
                candidate = json.loads(path.read_text(encoding="utf-8"))
            except ValueError:
                continue
            if candidate.get("status") == "pending":
                pending += 1
    result = {"configured": bool(state), **state, "pending_candidates": pending}
    if args.json:
        json.dump(result, sys.stdout, indent=2, ensure_ascii=False)
        print()
    else:
        print(f"github source: repo={state.get('repo', '-')} last_poll={state.get('last_poll', '-')} pending_candidates={pending}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="agentlab GitHub source")
    sub = parser.add_subparsers(dest="command", required=True)
    github = sub.add_parser("github", help="GitHub notification source")
    gsub = github.add_subparsers(dest="github_command", required=True)

    poll = gsub.add_parser("poll", help="read notifications and create candidates")
    poll.add_argument("--repo", help="owner/name; defaults to GITHUB_REPOSITORY or gh repo view")
    poll.add_argument("--input", help="read notifications from a JSON fixture instead of gh")
    poll.add_argument("--limit", type=int, default=100)
    poll.add_argument("--json", action="store_true")
    poll.set_defaults(func=command_poll)

    status = gsub.add_parser("status", help="show source state")
    status.add_argument("--json", action="store_true")
    status.set_defaults(func=command_status)
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
