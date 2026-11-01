# 快速开始

目标：**大约五分钟**跑通第一个 worker，**不碰你的真实仓库**。

本页只负责带你到“第一次成功”。安装细节见
[`install-manual.md`](install-manual.md)；完整开发流程见
[`workflow.zh-CN.md`](workflow.zh-CN.md)。

前提：

- `agentlab` 已安装并在 `PATH` 里（或直接用 `~/open-research-agents/bin/agentlab`）；
- worker 的 Pi 配置目录存在（`~/.pi/agentlab`，含可用凭据）；
- `agentlab doctor` 通过。

---

## 0. 不花 token 先验证安装

```bash
cd ~/open-research-agents
bash tests/platform_smoke.sh        # 期望：48 passed, 0 failed
bash scripts/validate-harness.sh    # 期望：27 passed, 0 failed
```

两个都是确定性测试，不调用模型。任一失败就停，按
[`install-manual.md`](install-manual.md) 的排错一节处理。

---

## 1. 准备一个临时目标仓库

仓库自带一个小的 validation target：起点是未实现的迎风残差，带一个真实的 MMS 验证算例。

```bash
rm -rf /tmp/agentlab-first /tmp/agentlab-first-wt
cp -R ~/open-research-agents/examples/validation/target /tmp/agentlab-first
cd /tmp/agentlab-first
git init -b main
git add -A
git commit -m "validation target"
```

---

## 2. 看起点

```bash
agentlab status
agentlab gate spatial
```

期望：

```text
spatial   missing   -   -   no   0
```

`agentlab gate spatial` 必须退出 **2**，并打印：

```text
UNVERIFIED: S1 not implemented: first-order upwind residual
GATE UNVERIFIED (mode: worker)
```

这正是重点：实现之前，数值门禁诚实地是 `UNVERIFIED`，不是 `PASS`。

---

## 3. 跑一个真实 worker

```bash
agentlab run spatial --detach
```

它会打印 pid、日志路径，然后立刻返回。跟踪：

```bash
agentlab status
tail -f /tmp/agentlab-first-wt/logs/spatial-detached-*.log
```

结束后，`agentlab status` 应该显示：

```text
spatial   ready   worker:pass   repro   yes   >=1
```

worker 做了这些事：

- 改 `modules/spatial/upwind.cpp`；
- 新增 `tests/unit/spatial/upwind_test.cpp`；
- 在 `CMakeLists.txt` 注册测试；
- 跑 build + unit + verification；
- 在 `agent/spatial` 上提交；
- 写 `.agentlab/reports/spatial.md`。

---

## 4. 门禁与集成

```bash
agentlab gate spatial
```

期望：

```text
case=mms-advection-1d
n=40 l2=3.487041e-01
n=80 l2=1.744417e-01
observed_order=0.9993
PASS
GATE PASS (mode: worker)
```

然后：

```bash
agentlab integrate spatial
```

期望：

```text
GATE PASS (mode: integration)
GATE PASS. Review the integration branch, then merge main after human approval.
```

这时改动在 `integration` 分支上，等你审。`agentlab` 不会替你合并 base 分支。

---

## 5. 看它到底做了什么

```bash
cd /tmp/agentlab-first-wt/spatial
git diff --stat main...HEAD
cat .agentlab/reports/spatial.md
```

报告里有 commit SHA、gate 输出、改动文件、复现记录和已知局限。
如果 worker 发现契约没规定的东西，它应该记录成待决问题，而不是自己悄悄决定。

---

## 6. 用到你自己的仓库

安装 domain + target pack：

```bash
agentlab install <domain> <target> <repo>
cd <repo>
git add .agentlab AGENTS.md
git commit -m "agentlab: add <target> pack"
agentlab status
```

如果还不清楚仓库边界，先待在 `audit` 模式。等 scope、contracts 和真实验证都准备好，
再切 `worker`。

接下来读：

- [`workflow.zh-CN.md`](workflow.zh-CN.md) — 通用流程；
- [`validation.md`](validation.md) — 完整验证实验，包括错误实现如何被抓住；
- [`../targets/oneflow/WORKFLOW.zh-CN.md`](../targets/oneflow/WORKFLOW.zh-CN.md) — 完整 OneFLOW 示例。
