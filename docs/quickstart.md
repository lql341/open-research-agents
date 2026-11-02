**English** | [中文](quickstart.zh-CN.md)

# Quickstart

Goal: complete one successful worker run in about five minutes, **without touching your
real repository**.

This page only gets you to the first success. Installation details are in
[`install-manual.md`](install-manual.md); the full development process is in
[`workflow.md`](workflow.md).

Assumes:

- `agentlab` is installed and on `PATH` (or use `~/open-research-agents/bin/agentlab`);
- a worker Pi profile exists (`~/.pi/agentlab` with credentials);
- `agentlab doctor` passes.

---

## 0. Verify the installation without spending tokens

```bash
cd ~/open-research-agents
bash tests/platform_smoke.sh        # expect: 73 passed, 0 failed
bash scripts/validate-harness.sh    # expect: 27 passed, 0 failed
```

Both are deterministic and call no model. If either fails, stop here and see
the troubleshooting section in [`install-manual.md`](install-manual.md).

---

## 1. Prepare a scratch target

The repository ships a small validation target. It starts with an unimplemented
upwind residual and a real MMS verification case.

```bash
rm -rf /tmp/agentlab-first /tmp/agentlab-first-wt
cp -R ~/open-research-agents/examples/validation/target /tmp/agentlab-first
cd /tmp/agentlab-first
git init -b main
git add -A
git commit -m "validation target"
```

---

## 2. Check the starting point

```bash
agentlab status
agentlab gate spatial
```

Expected:

```text
spatial   missing   -   -   no   0
```

`agentlab gate spatial` must exit **2** and print:

```text
UNVERIFIED: S1 not implemented: first-order upwind residual
GATE UNVERIFIED (mode: worker)
```

This is intentional: before implementation, the numerical gate is honestly
`UNVERIFIED`, not `PASS`.

---

## 3. Run one real worker

```bash
agentlab run spatial --detach
```

It prints a pid, a log path, and returns. Follow it:

```bash
agentlab status
tail -f /tmp/agentlab-first-wt/logs/spatial-detached-*.log
```

When it finishes, `agentlab status` should show:

```text
spatial   ready   worker:pass   repro   yes   >=1
```

The worker:

- edited `modules/spatial/upwind.cpp`;
- added `tests/unit/spatial/upwind_test.cpp`;
- registered the test in `CMakeLists.txt`;
- ran build + unit + verification;
- committed on `agent/spatial`;
- wrote `.agentlab/reports/spatial.md`.

---

## 4. Gate and integrate

```bash
agentlab gate spatial
```

Expected:

```text
case=mms-advection-1d
n=40 l2=3.487041e-01
n=80 l2=1.744417e-01
observed_order=0.9993
PASS
GATE PASS (mode: worker)
```

Then:

```bash
agentlab integrate spatial
```

Expected:

```text
GATE PASS (mode: integration)
GATE PASS. Review the integration branch, then merge main after human approval.
```

At this point, the change is on the `integration` branch, waiting for you.
`agentlab` does not merge the base branch.

---

`agentlab inbox` now shows the completed report as a review item, without the
gate noise.

## 5. Look at what happened

```bash
cd /tmp/agentlab-first-wt/spatial
git diff --stat main...HEAD
cat .agentlab/reports/spatial.md
```

The report contains the commit SHA, gate output, files changed, repro record,
and known limitations. If the worker found something the contract does not
specify, it should record it as an open question instead of silently deciding.

---

## 6. Use it on your own repository

Install a domain + target pack:

```bash
agentlab install <domain> <target> <repo>
cd <repo>
git add .agentlab AGENTS.md
git commit -m "agentlab: add <target> pack"
agentlab status
```

Start in `audit` mode if you do not know the repository boundaries yet. Switch
to `worker` only after scopes, contracts, and a real verification case are in
place.

Read next:

- [`workflow.md`](workflow.md) — the generic process;
- [`validation.md`](validation.md) — the full validation experiment, including
  how a wrong implementation is caught;
- [`../targets/oneflow/WORKFLOW.md`](../targets/oneflow/WORKFLOW.md) — a complete
  worked example.
