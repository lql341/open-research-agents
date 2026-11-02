[English](workflow.md) | **中文**

# 用 agentlab 开发一个目标仓库

状态：v0.1  
读者：习惯 `cd <repo> && pi`，然后直接用自然语言提需求的单人开发者。

`agentlab` 不替代 Pi。它在普通 Pi 会话外面加了四件事：
**任务（task）**、**隔离工作树（worktree）**、**门禁（gate）**、**提交 + 报告**。

如果只需完成第一次运行，看 [`quickstart.zh-CN.md`](quickstart.zh-CN.md)。
本页是目标无关的完整流程。完整示例见
[OneFLOW target guide](../targets/oneflow/WORKFLOW.zh-CN.md)。

---

## 1. 三种用法

| 模式 | 命令 | 适合 | 门禁/报告 |
|---|---|---|---|
| **原生 Pi** | `cd <repo> && pi` | 读代码、探索、一次性小改、提问 | 没有，靠你自己看 |
| **任务 worker** | `agentlab run <ws>` | 一个明确交付物：代码 + 测试 + 验证 + 提交 | 有 |
| **交互 worker** | `agentlab pi <ws>` | 进 worker 的 worktree，用同一会话继续对话和排查 | 手动运行 gate |

选择原则：

- **探索用原生 Pi。** “这个函数在哪”“为什么编译失败”“改个注释”不值得付任务和门禁的成本。
- **已经知道要交付什么时，用任务 worker。** 你想要范围限制、独立工作树、提交和报告。
- **任务 worker 完成或受阻时，用交互 worker。** 在同一个 worktree、同一个会话里继续。

自然语言仍然可用。任务 worker 的请求写在 `.agentlab/TASKS.md`；worker 主要读任务板，
不是读一段自由聊天。可以追加一句澄清：

```bash
agentlab run <ws> "保持现有 serial 输出逐字节不变。"
```

想在同一工作树里自由对话：

```bash
agentlab pi <ws>
```

---

## 2. 什么是 target pack

仓库分三层：

```text
platform/               通用：规则、脚本、门禁、CLI
domains/<domain>/       可复用的领域规则：契约、验证、复现字段
targets/<target>/       单个仓库的覆盖层：路径、分支、命令
```

domain 可以跨仓库复用；target 是一个具体仓库。
`agentlab install <domain> <target> <repo>` 会把两者装进 `<repo>/.agentlab/`；
重叠的地方 target 覆盖 domain。

一个 target pack 通常提供：

```text
targets/<target>/
  target.env            TARGET、BASE_REF、模式、workstream、命令
  AGENTS.target.md      仓库专属规则
  TASKS.md              人维护的任务板
  scope/<ws>.txt        每个 workstream 的写入边界
  verification/         真实数值/回归门禁
  contracts/            可选的仓库专属契约
```

通用规范见
[`platform/docs/target-pack-spec.md`](../platform/docs/target-pack-spec.md)。

---

## 3. 第一个任务之前

安装 pack 并提交。`scope_check` 从 base ref 读取 scope，所以未提交的 `.agentlab/`
保护不了任何东西。

```bash
agentlab install <domain> <target> <repo>
cd <repo>
git add .agentlab AGENTS.md
git commit -m "agentlab: add <target> pack"
agentlab status
```

如果对仓库还不熟，先待在 `audit` 模式。这时 worker 只能写：

```text
.agentlab/reports/<ws>.md
.agentlab/RFC/<ws>-*
.agentlab/repro/<ws>-*
```

不写代码、不编译、不执行测试。通过审计梳理入口、所有权、共享文件、测试覆盖和风险。
先读报告和 RFC，再决定要不要让 worker 改代码。

---

## 4. 从 audit 切到 worker

### 4.1 回答待决 RFC

RFC 是 worker 写的提案，状态只能由人改。不想要的标 rejected，并在 RFC 或
`platform/docs/decisions/` 里记录理由。

### 4.2 写一个任务

编辑 `.agentlab/TASKS.md`。worker 只做本 workstream 第一个 `todo`。
任务要有交付物和验收条件，不要写“优化一下”。

```markdown
## <ws>

- R1 [todo] <一个具体交付物>。

  范围：
  - <精确的源文件路径>
  - <现有测试目标>

  验收：
  - <必须保持不变的可观察行为>；
  - <必须成立的新行为>；
  - 现有相关测试通过；
  - <不允许改什么>。
```

### 4.3 收窄 scope

`.agentlab/scope/<ws>.txt` 一开始只允许报告。改成任务真正需要的文件和测试：

```text
# .agentlab/scope/<ws>.txt
<path/to/source.cpp>
<path/to/test.cpp>
.agentlab/reports/<ws>.md
.agentlab/RFC/<ws>-*
.agentlab/repro/<ws>-*
```

不要放整个目录。scope 是强制手段；放太宽，门禁就形同虚设。

### 4.4 契约和验证

| 文件 | 必须包含 |
|---|---|
| `.agentlab/contracts/` | 这个仓库在这个 workstream 的真实边界，不是通用模板。替换 `TODO` / `[CONFIRM]`。 |
| `.agentlab/verification/run_all.sh` | 一个真实算例：退出 `0` PASS / `1` FAIL / `2` UNVERIFIED。 |

规则：

- 不允许为了通过门禁而放宽容差；
- 仓库已有基线时，不要新造第二套；
- 验证还是占位时，worker gate 会 `UNVERIFIED`，`integration` 会拒绝。这是故意的。

### 4.5 构建和测试命令

`.agentlab/target.env` 里是候选命令：

```text
BUILD_CMD   <configure + build>
UNIT_CMD    <targeted unit/contract test command>
VERIFY_CMD  <numerical/regression gate>
```

切换前先在本机验证。如果目标仓库的完整测试集很大，用它自己的筛选方式收窄
`UNIT_CMD`（例如 `ctest -R`、`pytest -k`、`go test -run`）。
这是改命令配置，不是改测试架构。

### 4.6 切模式

```bash
cd <repo>
# macOS
sed -i '' 's/^AGENTLAB_MODE=audit/AGENTLAB_MODE=worker/' .agentlab/target.env
# Linux
# sed -i 's/^AGENTLAB_MODE=audit/AGENTLAB_MODE=worker/' .agentlab/target.env

git add .agentlab
git commit -m "agentlab: enable worker mode for <ws>"
agentlab preflight <ws>
```

`preflight` 不过就不要浪费一次 worker。

---

### 4.7 注意力收件箱

收件箱是 v0.2 的注意力层。它不启动工作，只决定什么进入人的视野。

```bash
agentlab inbox              # 仅 pending 和 review
agentlab inbox --all        # 包含 fyi
agentlab inbox --json
agentlab decide <id> --ack|--approve|--reject --note "..."
```

条目来自 `reports/*.md`、`RFC/*.md`、每个 workstream 最新的 gate，以及最新的 worker
日志。分类通过 `.agentlab/target.env` 中的 `ATTENTION_*` 配置。决定只对做出决定时的
内容生效；报告、RFC、gate 或日志变化后会产生新条目。

## 5. 运行、审查、集成

```bash
cd <repo>

# 1. 后台起一个 worker
agentlab run <ws> --detach

# 2. 跟踪
agentlab status
tail -f ../<repo>-wt/logs/<ws>-detached-*.log

# 3. 看它改了什么
cd ../<repo>-wt/<ws>
git diff --stat <base>...HEAD
cat .agentlab/reports/<ws>.md

# 4. 需要时进同一会话继续
agentlab pi <ws>

# 5. 在 worker 分支上运行门禁（默认就是工作树）
agentlab gate <ws>

# 6. 合并到 integration 并运行集成门禁
cd <repo>
agentlab integrate <ws>

# 7. 人工 review 后合并
git checkout <base>
git merge --no-ff integration
```

注意：

- `agentlab gate <ws>` **默认在 worker 工作树中运行**。主检出可能还是桩，在在主检出中运行会得到
  误导性的 `UNVERIFIED`。只有确实要针对当前检出运行时才使用 `--here`。
- `agentlab integrate` 会拒绝脏工作区。唯一例外是未跟踪的 `.agentlab/repro/*.json`
  和 `.agentlab/decisions/*.json`，它们会随 integration 一起提交。
- `agentlab status` 里 `WORKTREE=repro` 表示只有门禁生成的记录没提交，没有源码改动。

---

## 6. 第一个任务应该长什么样

第一个任务应该小、范围窄、能用目标仓库现有测试证明：

```text
任务：    <一个缺陷或一个小能力>
范围：    <一两个源文件> + <一个现有测试目标>
不要：    重写共享基础、构建系统、测试架构
证据：    <现有行为不变>；<新行为成立>；测试通过
```

如果现有测试目标无法表达新行为，不要假装它覆盖了。在报告里记录缺口，
把准确的命令和输出作为人工证据。

第一个任务完整走完 **worker → gate → integration → 人工合并** 之后，
再开第二个 workstream。

---

## 7. 旧工作流 vs agentlab

| 原有工作流 | agentlab |
|---|---|
| `pi` 在仓库主检出中运行，直接修改工作区 | worker 在独立 git worktree 中运行，主检出保持干净 |
| 一个长会话不断累积上下文 | 每个 workstream 一个独立会话 |
| 事后自己看 diff | worker 必须提交，否则 `run_worker` 判失败 |
| 没有路径限制 | 改到 scope 外，`scope_check` 直接失败 |
| 没有验证门槛 | 三态门禁：PASS / FAIL / UNVERIFIED |
| 没有报告 | 强制报告 + commit SHA + repro 记录 |
| 串行做任务 | 多个 workstream 可以并行，各自独立 worktree |

代价：你要写任务、定 scope、维护 contracts 和 verification。  
收益：你审的是一个小 diff 和一份报告，而不是一整段长对话。

---

## 8. 何时不使用 agentlab

- “这个函数在哪” → 原生 Pi；
- “为什么编译不过” → 原生 Pi；
- 一行修复、改注释 → 原生 Pi；
- 还没想清楚要交付什么 → 先用原生 Pi 探索。

agentlab 适合：**交付物已知，且你需要隔离、验证或可追溯记录。**

---

## 9. 文件在哪

```text
<repo>/.agentlab/                  安装后的 target pack（提交在仓库里）
  TASKS.md                         人维护的任务板
  scope/<ws>.txt                   人维护的写入边界
  contracts/                       人维护的接口和数据布局
  verification/                    人维护的数值门禁
  reports/                         worker 产出
  RFC/                             待人工批准的提案
  repro/                           门禁证据
  target.env                       模式、base ref、workstream、命令

../<repo>-wt/<ws>/                 worker 工作树（不在仓库里）
../<repo>-wt/logs/                 worker 日志
../<repo>-wt/sessions/             worker 的 Pi 会话
../<repo>-wt/run/                  detach worker 的 pid 文件
```

worker 不使用主检出，也不使用你日常的 `~/.pi/agent`。

---

## 10. 已知阻塞

| 项 | 要检查什么 |
|---|---|
| 模式 | scope 和验证没准备好前，保持 `AGENTLAB_MODE=audit` |
| Contracts | 通用模板会让 `worker` preflight 失败；替换 `TODO` / `[CONFIRM]` |
| Verification | 占位 → worker gate `UNVERIFIED`，integration 拒绝 |
| Unit 命令 | 全套测试可能太慢；用目标仓库自己的筛选方式收窄 |
| Base 分支 | worker 从 `BASE_REF` 拉分支；让它符合目标仓库的分支策略 |
| 测试架构 | 不要在代码任务中一并重构 |
| 共享基础 | 保持人所有；不要用“顺便修一下”扩大 scope |
