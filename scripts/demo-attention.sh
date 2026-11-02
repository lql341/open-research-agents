#!/usr/bin/env bash
# One-command attention demo: no model calls, no network.
# It creates a temporary target repository, polls a saved GitHub notification
# fixture, shows the inbox, approves one candidate, and lists the ticket.
set -euo pipefail
HOME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAB="${AGENTLAB_BIN:-$HOME_DIR/bin/agentlab}"
FIXTURE="$HOME_DIR/tests/fixtures/github-notifications.json"
CANDIDATE="gh-1001-20261102t000000z"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
REPO="$TMP/repo"

cp -R "$HOME_DIR/tests/fixtures/mini-target" "$REPO"
cd "$REPO"
git init -q -b main
git add -A
git commit -q -m "attention demo"

echo "== 1. poll a saved GitHub notification fixture"
"$LAB" source github poll --input "$FIXTURE" --repo lql341/OneFLOW

echo
echo "== 2. inbox: candidates need a human"
"$LAB" inbox

echo
echo "== 3. approve one candidate with an explicit workstream"
"$LAB" decide "candidate:$CANDIDATE" --approve --workstream spatial --note "demo approval"

echo
echo "== 4. ticket created by the approval"
"$LAB" ticket list

echo
echo "== 5. inbox after approval"
"$LAB" inbox

echo
echo "demo complete: candidate -> inbox -> approval -> authorized ticket"
