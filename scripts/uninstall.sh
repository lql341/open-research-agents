#!/usr/bin/env bash
# uninstall.sh [--force] [--yes]
# Removes the agent-lab collaboration pack from the current target repository.
# Keeps: branches agent/*, <repo>-wt/logs, worker Pi profile, platform repo.
set -uo pipefail
FORCE=0; YES=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --yes|-y) YES=1 ;;
    *) echo "usage: agentlab uninstall [--force] [--yes]" >&2; exit 2 ;;
  esac
done

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "uninstall: not inside a git repository" >&2; exit 2; }
cd "$ROOT"
[ -d .agentlab ] || { echo "uninstall: no .agentlab/ here; nothing to do"; exit 0; }

# shellcheck disable=SC1091
[ -f .agentlab/domain.env ] && . .agentlab/domain.env
MODULES="${MODULES:-}"
WT_ROOT="${WT_ROOT:-$(dirname "$ROOT")/$(basename "$ROOT")-wt}"

echo "uninstall: $ROOT"

# Report, and by default refuse, when worktrees or worker branches still exist.
worktrees=""
for ws in $MODULES; do
  [ -d "$WT_ROOT/$ws" ] && worktrees="$worktrees $ws"
done
branches="$(git for-each-ref --format='%(refname:short)' 'refs/heads/agent/*' 2>/dev/null | tr '\n' ' ')"

problems=0
if [ -n "${worktrees# }" ]; then
  echo "  worktrees still present:$worktrees"
  echo "    remove them first: agentlab clean${worktrees}"
  problems=1
fi
if [ -n "$branches" ]; then
  echo "  worker branches still present: $branches"
  echo "    they are kept on purpose; delete with: git branch -D <name>"
fi
if [ $problems -eq 1 ] && [ $FORCE -eq 0 ]; then
  echo "uninstall: refused (use --force to remove .agentlab anyway)" >&2
  exit 1
fi

if [ $YES -eq 0 ]; then
  printf 'Remove %s/.agentlab (reports, RFCs and repro records included)? [y/N] ' "$ROOT"
  read -r answer
  case "$answer" in y|Y|yes|YES) ;; *) echo "uninstall: aborted"; exit 1 ;; esac
fi

# Only remove the root AGENTS.md if it is the pointer this tool generated.
if [ -f AGENTS.md ] && grep -q '^# Agent Lab target repository' AGENTS.md && grep -q '\.agentlab/AGENTS.md' AGENTS.md; then
  rm -f AGENTS.md
  echo "  removed AGENTS.md (generated pointer)"
elif [ -f AGENTS.md ]; then
  echo "  kept AGENTS.md (it is yours; remove the .agentlab pointer yourself if you want)"
fi

rm -rf .agentlab
echo "  removed .agentlab/"

echo
echo "kept:"
echo "  branches : ${branches:-none}"
echo "  worktrees: $WT_ROOT ${worktrees:+($worktrees)}"
echo "  profile  : ${PI_CODING_AGENT_DIR:-not set}"
[ -n "${worktrees# }" ] && echo "  note: run 'agentlab clean$worktrees' then 'rm -rf $WT_ROOT'"
echo "done"
