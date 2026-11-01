#!/usr/bin/env bash
# Usage (inside target repo main checkout): run_worker.sh <module> [extra instruction...]
# Env: PI_BIN (default pi), PI_ARGS (e.g. "--model ..."), PI_SESSION=0 for --no-session,
#      WT_ROOT, BASE_REF, SKIP_PREFLIGHT=1
set -uo pipefail
PLATFORM="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE="${1:?usage: run_worker.sh <module> [instruction]}"; shift || true
EXTRA="${*:-}"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "run_worker: not inside a git repository"; exit 2; }
cd "$ROOT"
[ -f .agentlab/domain.env ] || { echo "run_worker: missing .agentlab/domain.env"; exit 2; }
# shellcheck disable=SC1091
source .agentlab/domain.env
BASE="${BASE_REF:-main}"

if [ "${SKIP_PREFLIGHT:-0}" != "1" ]; then
  "$PLATFORM/preflight.sh" "$MODULE" || { echo "run_worker: preflight failed"; exit 1; }
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "run_worker: working tree is dirty; commit or stash before starting a worker"
  exit 1
fi

WT_ROOT="${WT_ROOT:-$(dirname "$ROOT")/$(basename "$ROOT")-wt}"
WT="$WT_ROOT/$MODULE"
BRANCH="agent/$MODULE"

if [ ! -d "$WT" ]; then
  mkdir -p "$WT_ROOT"
  git worktree add -B "$BRANCH" "$WT" "$BASE"
fi

cd "$WT"
if [ -n "$(git status --porcelain)" ]; then
  echo "run_worker: worktree $WT is dirty; clean it before starting"
  exit 1
fi

if [ "$(git rev-list --count "HEAD..$BASE" 2>/dev/null || echo 0)" -gt 0 ]; then
  echo "run_worker: warning: $BASE has commits not in $BRANCH; rebase before work if needed"
fi

mkdir -p .agentlab/reports/logs .agentlab/sessions

PROMPT=$(cat <<PROMPT_EOF
你是模块「${MODULE}」的负责 agent。

1. 先完整阅读 .agentlab/AGENTS.md、.agentlab/contracts/ 下全部文件、.agentlab/scope/${MODULE}.txt，以及 .agentlab/TASKS.md 中「${MODULE}」部分。
2. 只做本模块状态为 todo 的第一项；测试先行。
3. 完成后运行 $PLATFORM/gate.sh ${MODULE}，按 worker 模式接受 PASS 或 UNVERIFIED；UNVERIFIED 必须在报告中写明，不能写成数值已验证。
4. gate 通过后，只 git add 范围内的文件并 commit 到当前分支 agent/${MODULE}；不要 push、不要 merge。
5. 按 .agentlab/templates/report.md 写 .agentlab/reports/${MODULE}.md，必须包含 commit SHA 和复现记录。
6. 如果契约不明确、需要改 core/contracts/verification 或需要人决定，写 .agentlab/RFC/<日期>-${MODULE}-<主题>.md，状态 need_decision，然后停止。
PROMPT_EOF
)
if [ -n "$EXTRA" ]; then PROMPT="$PROMPT
$EXTRA"; fi

LOG=".agentlab/reports/logs/$MODULE-$(date -u +%Y%m%dT%H%M%SZ).log"
GUARD=(-e "$PLATFORM/extensions/guard.ts")
if [ "${PI_SESSION:-1}" = "0" ]; then
  SESSION_ARGS=(--no-session)
else
  SESSION_ARGS=(--session-id "agentlab-$MODULE" --session-dir "$ROOT/.agentlab/sessions" --name "agentlab-$MODULE")
fi

echo "run_worker: module=$MODULE branch=$BRANCH worktree=$WT"
echo "run_worker: log=$LOG"
set +e
# shellcheck disable=SC2086
${PI_BIN:-pi} "${SESSION_ARGS[@]}" "${GUARD[@]}" ${PI_ARGS:-} -p "$PROMPT" 2>&1 | tee "$LOG"
rc=${PIPESTATUS[0]}

# Post-run checks: a worker must commit, stay in scope, and leave a clean worktree.
if [ -n "$(git status --porcelain)" ]; then
  echo "run_worker: worker left uncommitted changes"
  rc=1
fi
if [ "$(git rev-list --count "$BASE..HEAD" 2>/dev/null || echo 0)" -eq 0 ]; then
  echo "run_worker: worker made no commit on $BRANCH"
  rc=1
fi
"$PLATFORM/scope_check.sh" "$MODULE" "$BASE" || rc=1

echo "run_worker: exit=$rc head=$(git rev-parse --short HEAD 2>/dev/null || echo none)"
exit $rc
