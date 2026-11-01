#!/usr/bin/env bash
# Usage (inside target repo main checkout): run_worker.sh <workstream> [extra instruction...]
# Env: PI_BIN (default pi), PI_ARGS, PI_SESSION=0 for --no-session,
#      WT_ROOT, BASE_REF, SKIP_PREFLIGHT=1, AGENTLAB_MODE=audit|worker
set -uo pipefail
SELF="${BASH_SOURCE[0]}"
PLATFORM="$(cd "$(dirname "$SELF")" && pwd)"
MODULE="${1:?usage: run_worker.sh <workstream> [instruction]}"; shift || true
EXTRA="${*:-}"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "run_worker: not inside a git repository"; exit 2; }
# A detached child starts from the worktree, so the parent passes the real
# repository root and worktree root explicitly. Without this the child would
# compute a nested <worktree>-wt and use a different pid/session directory.
ROOT="${AGENTLAB_ROOT:-$ROOT}"
cd "$ROOT"
[ -f .agentlab/domain.env ] || { echo "run_worker: missing .agentlab/domain.env"; exit 2; }
# shellcheck disable=SC1091
source .agentlab/domain.env
MODE="${AGENTLAB_MODE:-worker}"
BASE="${BASE_REF:-main}"

if [ "${SKIP_PREFLIGHT:-0}" != "1" ]; then
  "$PLATFORM/preflight.sh" "$MODULE" || { echo "run_worker: preflight failed"; exit 1; }
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "run_worker: warning: main working tree is dirty; the worktree will be created from $BASE, not from uncommitted changes"
  echo "run_worker: dirty files (not copied into the worker):"
  git status --short | sed 's/^/  /'
fi

WT_ROOT="${AGENTLAB_WT_ROOT:-${WT_ROOT:-$(dirname "$ROOT")/$(basename "$ROOT")-wt}}"
WT="$WT_ROOT/$MODULE"
BRANCH="agent/$MODULE"
mkdir -p "$WT_ROOT/logs" "$WT_ROOT/sessions"

if [ ! -d "$WT" ]; then
  mkdir -p "$WT_ROOT"
  git worktree add -B "$BRANCH" "$WT" "$BASE" || {
    echo "run_worker: could not create worktree $WT" >&2
    echo "run_worker: if the branch is already checked out elsewhere, run: git worktree prune" >&2
    exit 1
  }
fi

cd "$WT" || { echo "run_worker: cannot enter worktree $WT" >&2; exit 1; }
if [ -n "$(git status --porcelain)" ]; then
  echo "run_worker: worktree $WT is dirty; clean it before starting"
  exit 1
fi

if [ "$(git rev-list --count "HEAD..$BASE" 2>/dev/null || echo 0)" -gt 0 ]; then
  echo "run_worker: warning: $BASE has commits not in $BRANCH; rebase before work if needed"
fi


if [ "$MODE" = "audit" ]; then
PROMPT=$(cat <<PROMPT_EOF
你是 OneFLOW / agent-lab 的只读审计 agent，workstream「${MODULE}」。

1. 先读 .agentlab/AGENTS.md、仓库根 AGENTS.md、doc/AI_CONTEXT.md、.agentlab/contracts/、.agentlab/scope/${MODULE}.txt、.agentlab/TASKS.md。
2. 不要修改任何求解器代码、CMake、contracts、verification。只写 .agentlab/reports/${MODULE}.md，必要时写 .agentlab/RFC/<日期>-${MODULE}-<主题>.md。
3. 产出必须包含：入口与调用者、状态/资源所有权、共享文件、现有测试、缺失的契约测试、风险、可并行的未来 scope 提案、以及一个需要人确认的具体问题。
4. 不要假设 starter 的 spatial/temporal 边界适用于 OneFLOW；从代码和测试里推导边界。
5. 运行 GATE_MODE=audit $PLATFORM/gate.sh ${MODULE}；PASS 后只 commit 报告/RFC/repro，不要 push、不要 merge。
6. 报告用中文；路径、类名、测试名保持原文。不要声称未运行的测试通过。
PROMPT_EOF
)
else
PROMPT=$(cat <<PROMPT_EOF
你是 OneFLOW / agent-lab 的 workstream「${MODULE}」负责 agent。

1. 先完整阅读 .agentlab/AGENTS.md、仓库根 AGENTS.md、doc/AI_CONTEXT.md、.agentlab/contracts/ 下全部文件、.agentlab/scope/${MODULE}.txt，以及 .agentlab/TASKS.md 中「${MODULE}」部分。
2. 只做本 workstream 状态为 todo 的第一项；测试先行。
3. 完成后运行 GATE_MODE=worker $PLATFORM/gate.sh ${MODULE}，接受 PASS 或 UNVERIFIED；UNVERIFIED 必须在报告中写明，不能写成数值已验证。
4. gate 通过后，只 git add 范围内的文件并 commit 到当前分支 agent/${MODULE}；不要 push、不要 merge。
5. 按 .agentlab/templates/report.md 写 .agentlab/reports/${MODULE}.md，必须包含 commit SHA 和复现记录。
6. 如果契约不明确、需要改 core/contracts/verification 或需要人决定，写 .agentlab/RFC/<日期>-${MODULE}-<主题>.md，状态 need_decision，然后停止。
PROMPT_EOF
)
fi

if [ -n "$EXTRA" ]; then PROMPT="$PROMPT
$EXTRA"; fi

SESS_DIR="$WT_ROOT/sessions"
mkdir -p "$SESS_DIR" "$WT_ROOT/logs"
if [ "${AGENTLAB_RESET_SESSION:-0}" = "1" ]; then
  rm -f "$SESS_DIR"/*"agentlab-$MODULE"*.jsonl
  echo "run_worker: cleared the $MODULE session history"
fi

# A resumed Session keeps the model recorded in its history. If that model is no
# longer available (for example because the worker profile changed), every turn
# fails with a provider error that looks unrelated. Detect it before spending a
# turn, and say exactly how to fix it.
model_of_session() {
  local python_bin="${PYTHON:-python3}"
  command -v "$python_bin" >/dev/null 2>&1 || return 0
  "$python_bin" - "$SESS_DIR" "agentlab-$MODULE" <<'PY2'
import glob, json, os, sys
directory, prefix = sys.argv[1], sys.argv[2]
files = sorted(glob.glob(os.path.join(directory, "*%s*.jsonl" % prefix)), key=os.path.getmtime)
if not files:
    raise SystemExit(0)
provider = model = None
with open(files[-1], encoding="utf-8", errors="replace") as stream:
    for line in stream:
        try:
            record = json.loads(line)
        except ValueError:
            continue
        if record.get("type") == "model_change":
            provider = record.get("provider")
            model = record.get("modelId")
if provider and model:
    print("%s\t%s" % (provider, model))
PY2
}

pinned="$(model_of_session)"
if [ -n "$pinned" ]; then
  pinned_provider="${pinned%%$'\t'*}"
  pinned_model="${pinned#*$'\t'}"
  # ANSI-C quoting does not expand inside double quotes; build the separator once.
  TAB="$(printf '\t')"
  available="$("${PI_BIN:-pi}" --list-models 2>/dev/null | awk 'NR>1 { print $1 "\t" $2 }')"
  if [ -n "$available" ] && ! printf '%s\n' "$available" | grep -qxF "${pinned_provider}${TAB}${pinned_model}"; then
    echo "run_worker: the $MODULE session is pinned to an unavailable model: $pinned_provider/$pinned_model" >&2
    echo "run_worker: available models:" >&2
    printf '%s\n' "$available" | head -10 | sed 's/^/    /' >&2
    echo "run_worker: fix it with: agentlab run $MODULE --reset-session" >&2
    echo "run_worker: or set a default in ${PI_CODING_AGENT_DIR:-~/.pi/agent}/settings.json" >&2
    exit 3
  fi
fi

RUN_DIR="$WT_ROOT/run"
mkdir -p "$RUN_DIR"

# --detach: hand this run to a background process so a long turn does not hold
# the terminal. The parent verifies preflight and the session guard, then exits.
if [ "${AGENTLAB_DETACH:-0}" = "1" ] && [ "${AGENTLAB_DETACHED:-0}" != "1" ]; then
  PID_FILE="$RUN_DIR/$MODULE.pid"
  if [ -f "$PID_FILE" ]; then
    old_pid="$(cat "$PID_FILE" 2>/dev/null || echo)"
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
      echo "run_worker: $MODULE is already running (pid $old_pid)" >&2
      echo "run_worker: stop it with: kill $old_pid" >&2
      exit 4
    fi
  fi
  DLOG="$WT_ROOT/logs/$MODULE-detached-$(date -u +%Y%m%dT%H%M%SZ).log"
  AGENTLAB_DETACHED=1 AGENTLAB_ROOT="$ROOT" AGENTLAB_WT_ROOT="$WT_ROOT" \
    nohup bash "$SELF" "$MODULE" "$EXTRA" >"$DLOG" 2>&1 &
  echo $! > "$PID_FILE"
  echo "run_worker: detached pid=$(cat "$PID_FILE")"
  echo "run_worker: log=$DLOG"
  echo "run_worker: follow with: tail -f $DLOG"
  echo "run_worker: stop with:   kill \$(cat $PID_FILE)"
  echo "run_worker: progress:    agentlab status"
  exit 0
fi

PID_FILE=""
if [ "${AGENTLAB_DETACHED:-0}" = "1" ]; then PID_FILE="$RUN_DIR/$MODULE.pid"; fi
cleanup_pid() { [ -n "$PID_FILE" ] && rm -f "$PID_FILE"; }
trap cleanup_pid EXIT

LOG="$WT_ROOT/logs/$MODULE-$(date -u +%Y%m%dT%H%M%SZ).log"
GUARD=(-e "$(cd "$PLATFORM/.." && pwd)/extensions/guard.ts")
if [ "${PI_SESSION:-1}" = "0" ]; then
  SESSION_ARGS=(--no-session)
else
  SESSION_ARGS=(--session-id "agentlab-$MODULE" --session-dir "$WT_ROOT/sessions" --name "agentlab-$MODULE")
fi

report_state() {
  local head branch_ahead dirty
  head="$(git rev-parse --short HEAD 2>/dev/null || echo none)"
  branch_ahead="$(git rev-list --count "$BASE..HEAD" 2>/dev/null || echo 0)"
  dirty="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  echo "run_worker: worktree state: head=$head commits_since_$BASE=$branch_ahead uncommitted=$dirty"
  if [ "$branch_ahead" -gt 0 ] && [ "$dirty" -eq 0 ]; then
    echo "run_worker: the work is committed; only the report or the final gate may be missing"
  elif [ "$branch_ahead" -eq 0 ]; then
    echo "run_worker: nothing committed yet; re-run to continue from the same session"
  else
    echo "run_worker: uncommitted changes present; commit or discard them before re-running"
  fi
  echo "run_worker: log=$LOG"
  echo "run_worker: inspect with: agentlab status"
}

on_signal() {
  trap - INT TERM
  echo >&2
  echo "run_worker: interrupted" >&2
  report_state >&2
  exit 130
}
trap on_signal INT TERM

echo "run_worker: mode=$MODE workstream=$MODULE branch=$BRANCH worktree=$WT"
echo "run_worker: log=$LOG"
set +e
# shellcheck disable=SC2086
${PI_BIN:-pi} "${SESSION_ARGS[@]}" "${GUARD[@]}" ${PI_ARGS:-} -p "$PROMPT" 2>&1 | tee "$LOG"
rc=${PIPESTATUS[0]}

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
if [ $rc -ne 0 ]; then report_state >&2; fi
exit $rc
