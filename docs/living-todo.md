**English** | [中文](living-todo.zh-CN.md)

# Living TODO

Updated: 2026-11-02

This is the short-term handoff for the platform repository. The long-term plan is
[`IMPLEMENTATION_PLAN.md`](../IMPLEMENTATION_PLAN.md). This page records what is
being worked on now, what comes next, and what is explicitly undecided.

## Baseline

```text
platform        main, 92 smoke checks / 27 harness checks
target          OneFLOW (local dev), .agentlab installed
source identity lql341-agent through gh-agent
human identity  lql341 (requester and approver)
```

## Now — v0.4.1 source and inbox hardening

Goal: make the attention loop reliable enough for daily use before adding outbound
communication.

- [ ] Source pagination and rate-limit handling: more than 100 notifications,
      HTTP 403/429, and partial failure. Keep the last successful poll.
- [ ] Candidate detail: resolve the actor when possible, keep thread/subject
      identifiers, and avoid creating a new candidate for a trivial update.
- [ ] Candidate health: record last error, consecutive failures, and last
      successful poll in `sources/github.json`; surface it in `source status`.
- [ ] Inbox filters: `--category`, `--since`, and `--json` output that includes
      decisions and ticket ids. Keep `fyi` hidden by default.
- [ ] Decision audit: a read-only `agentlab decisions` view over
      `.agentlab/decisions/`; no new state.
- [ ] Tests: pagination, 429, candidate update, decision listing.

Acceptance: two consecutive polls never duplicate a candidate; a rate-limited poll
leaves the previous state intact and reports an error; inbox filters return the same
items as `--json`.

## Next — v0.5 Outbox and Channel

- [ ] Durable outbox under `.agentlab/outbox/` (or SQLite if the volume justifies it).
- [ ] One Channel: GitHub issue/PR comments through `GITHUB_CLI`.
- [ ] Receipts: sent, failed, retrying, withdrawn; retry with backoff.
- [ ] One reply per ticket/thread unless a new decision explicitly asks for another.
- [ ] No auto-merge, no unsolicited comments, no human-identity posting.

Acceptance: a reply is sent once; a retry does not duplicate the comment; a failed
send is visible in `inbox`/`status`.

## Then — v0.6 Ticket execution

- [ ] `agentlab run <ws> --ticket <id>` validates the ticket, sets it `running`,
      and passes the ticket id to the worker.
- [ ] After the worker exits, set the ticket `review` on success or `blocked` on
      failure; record the commit, report, and session.
- [ ] Per-ticket session/workspace (instead of per-workstream) and follow-up resume.
- [ ] Policy revalidation before resume; a stale ticket cannot start.
- [ ] Tests: authorization refusal, stale refusal, success/failure transitions.

Acceptance: a ticket cannot run without authorization; a stale ticket refuses to
start; restart and follow-up resume preserve the ticket.

## Later

- v0.7: multi-target/workspace registry and one inbox across targets.
- v0.8: campaigns, budgets, and auto-accept only for rules whose observe-mode
  precision is measured and accepted by a human.

## Open decisions

1. **Outbox scope:** only results and questions, or also acknowledgements? Current
   default should be results and questions.
2. **Ticket required for run:** v0.6 should support `TICKET_REQUIRED=0` by default,
   then let a target opt in. Do not break the existing manual workstream flow.
3. **Candidate actor:** GitHub notifications omit the actor. Resolve it from the
   issue/comment API only when the URL is available; otherwise keep `unknown`.
4. **Source admission:** remain `observe` only until v0.6; no automatic ticket.
5. **Multi-target state:** a workspace registry is needed before one inbox can
   aggregate targets. Do not fake it with a global scan.

## How to pick up

```bash
cd ~/open-research-agents
git pull --ff-only
agentlab doctor
bash tests/platform_smoke.sh
bash scripts/validate-harness.sh
```

Read, in order:

1. `docs/workflow.md` — the current process.
2. `IMPLEMENTATION_PLAN.md` Section 8 — the roadmap.
3. `platform/docs/target-pack-spec.md` — target configuration.
4. `targets/oneflow/README.md` — the current target.

Then pick the first unchecked item under **Now**, add a test first, implement, and
update this page. Do not start v0.5 before v0.4.1 acceptance.

## Recently done

- v0.1 manual worker harness, gate, report, repro.
- v0.2 Attention Inbox.
- v0.3 Ticket ledger.
- v0.4 GitHub Source in observe mode; agent account through `gh-agent`.
- Installer creates `tickets/candidates/sources/decisions`; `update` merges missing
  env keys without overwriting values.
- One-command attention demo (`scripts/demo-attention.sh`).
