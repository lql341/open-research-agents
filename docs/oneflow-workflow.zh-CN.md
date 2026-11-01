# 用 agentlab 开发 OneFLOW

状态：v0.1  
读者：习惯 `cd ~/OneFLOW && pi`，然后直接用自然语言提需求的单人开发者。

`agentlab` 不替代 Pi。它在普通 Pi 会话外面加了四件事：
**任务（task）**、**隔离工作树（worktree）**、**门禁（gate）**、**提交 + 报告**。

---

## 1. 三种用法

| 模式 | 命令 | 适合 | 门禁/报告 |
|---|---|---|---|
| **原生 Pi** | `cd ~/OneFLOW && pi` | 读代码、探索、一次性小改、提问 | 没有，靠你自己看 |
| **任务 worker** | `agentlab run <ws>` | 一个明确交付物：代码 + 测试 + 验证 + 提交 | 有 |
| **交互 worker** | `agentlab pi <ws>` | 进 worker 的 worktree，用同一会话继续聊、排查 | 手动跑 gate |

选择原则：

- **探索用原生 Pi。** “这个函数在哪”“为什么编译失败”“改个注释”不值得付任务和门禁的成本。
- **已经知道要交付什么时，用任务 worker。** 你想要范围限制、独立工作树、提交和报告。
- **任务 worker 跑完或卡住时，用交互 worker。** 在同一个 worktree、同一个会话里继续。

自然语言仍然可用。任务 worker 的请求写在 `.agentlab/TASKS.md`；worker 主要读任务板，
不是读一段自由聊天。可以追加一句澄清：

```bash
agentlab run runtime-io "保持 serial 输出逐字节不变。"
```

想在同一工作树里自由对话：

```bash
agentlab pi runtime-io
```

---

## 2. OneFLOW 现在已经装好了什么

```text
~/OneFLOW
  branch        dev
  .agentlab/    目标包，已提交在 dev
  mode          audit          （worker 不能改代码）
  workstreams   runtime-io、numerics
  reports       .agentlab/reports/runtime-io.md、numerics.md
  RFCs          .agentlab/RFC/runtime-io-...md、numerics-...md
```

检查：

```bash
cd ~/OneFLOW
agentlab status
```

大致输出：

```text
WORKSTREAM    REPORT          GATE              WORKTREE  BRANCH  AHEAD
runtime-io    need_decision   audit:pass        -         yes     0
numerics      ready           audit:pass        -         yes     0

Pending decisions (RFC status: proposed):
  .agentlab/RFC/runtime-io-2026-11-01-shared-case-runtime-target.md
  .agentlab/RFC/numerics-2026-11-01-boundary-contracts.md
```

---

## 3. 当前是 audit 模式

`audit` 模式下 worker 只能写：

```text
.agentlab/reports/<workstream>.md
.agentlab/RFC/<workstream>-*
.agentlab/repro/<workstream>-*
```

不编译、不跑测试、不改代码。适合“还不完全信任这个代码库边界”的阶段。

两个审计已经完成。剩下的是人的工作：

1. 回答两份 RFC；
2. 选第一批代码 workstream；
3. 收窄它们的 scope；
4. 填 contracts，注册一个真实验证算例；
5. 切到 `worker` 模式。

---

## 4. 从 audit 切到 worker

### 4.1 回答 RFC

- `runtime-io`：提议的共享 `oneflow_case_runtime` 目标 **不采纳**。
  v0.1 已决定不重构测试架构。把 RFC 标为 rejected，`io_paths.txt` 的发现单独做任务。
- `numerics`：双时间是补齐，还是显式声明不支持并 fail-fast。
  建议先“声明不支持 + fail fast”，因为 5 个回归算例都是 `idualtime=0`。

RFC 状态只能由人改。

### 4.2 写一个任务

编辑 `.agentlab/TASKS.md`。worker 只做本 workstream 第一个 `todo`。
任务要有明确交付物和验收条件，不要写“优化一下”。

```markdown
## runtime-io

- R1 [todo] 让 `io_paths.txt` 在多 rank 下只由 owner rank 写。

  范围：
  - `codes/main/src/SimuContextIO.cpp`
  - 现有聚焦测试目标（不要新建构建目标）

  验收：
  - serial 输出不变；
  - `mpirun -np 2` 下只有一个 rank 打开/截断 `io_paths.txt`；
  - 现有相关测试通过；
  - 不改 `Prj.cpp` 的公共语义。
```

### 4.3 收窄 scope

`.agentlab/scope/<workstream>.txt` 现在只允许报告/RFC/repro。改成任务真正需要的文件和测试：

```text
# .agentlab/scope/runtime-io.txt
codes/main/src/SimuContextIO.cpp
tests/main/simu_context_parameter_test.cpp
.agentlab/reports/runtime-io.md
.agentlab/RFC/runtime-io-*
.agentlab/repro/runtime-io-*
```

不要放整个目录，例如 `codes/main/`、`codes/ns/`。scope 是强制手段；放太宽，门禁就形同虚设。

### 4.4 契约和验证

两个文件决定门禁有没有意义：

| 文件 | 必须包含 |
|---|---|
| `.agentlab/contracts/` | OneFLOW 在这个 workstream 的真实边界，不是通用模板。替换 `TODO` / `[CONFIRM]`。 |
| `.agentlab/verification/run_all.sh` | 一个真实算例：跑现有 OneFLOW case + 现有 baseline，退出 `0` PASS / `1` FAIL / `2` UNVERIFIED。 |

规则：

- 不允许为了通过门禁而放宽容差；
- 不要新造第二套数值基线，用 `test/` 和现有 `autotest/` 参考结果；
- 验证还是占位时，worker gate 会 `UNVERIFIED`，`integration` 会拒绝。这是故意的。

### 4.5 构建和测试命令

`.agentlab/target.env` 里是候选命令：

```text
BUILD_CMD   cmake -S . -B build ... && cmake --build build -j2
UNIT_CMD    ctest --test-dir build --output-on-failure
```

切换前先在本机验证。OneFLOW 没有 `unit` 这个 CTest label，当前会发现约 1067 个测试；
每个 worker 都跑全部会很慢。用 `ctest -R <pattern>` 收窄是改命令配置，不是改测试架构。
不要在一个代码任务里顺手引入新的 label 体系。

### 4.6 切模式

```bash
cd ~/OneFLOW
# macOS
sed -i '' 's/^AGENTLAB_MODE=audit/AGENTLAB_MODE=worker/' .agentlab/target.env
# Linux
# sed -i 's/^AGENTLAB_MODE=audit/AGENTLAB_MODE=worker/' .agentlab/target.env

git add .agentlab
git commit -m "agentlab: enable worker mode for runtime-io"
agentlab preflight runtime-io
```

`preflight` 不过就不要浪费一次 worker。

---

## 5. 跑、审、集成

```bash
cd ~/OneFLOW

# 1. 后台起一个 worker
agentlab run runtime-io --detach

# 2. 跟踪
agentlab status
tail -f ../OneFLOW-wt/logs/runtime-io-detached-*.log

# 3. 看它改了什么
cd ../OneFLOW-wt/runtime-io
git diff --stat main...HEAD
cat .agentlab/reports/runtime-io.md

# 4. 需要时进同一会话继续
agentlab pi runtime-io

# 5. 在 worker 分支上跑门禁（默认就是工作树）
agentlab gate runtime-io

# 6. 合并到 integration 并跑集成门禁
cd ~/OneFLOW
agentlab integrate runtime-io

# 7. 人工 review 后合并
git checkout dev
git merge --no-ff integration
```

注意：

- `agentlab gate <ws>` **默认在 worker 工作树里跑**。主检出通常还是桩，在主检出跑会得到
  误导性的 `UNVERIFIED`。只有确实要跑当前检出的才用 `--here`。
- `agentlab integrate` 会拒绝脏工作区。唯一例外是未跟踪的 `.agentlab/repro/*.json`，
  它们会随 integration 一起提交。
- `agentlab status` 里 `WORKTREE=repro` 表示只有门禁生成的记录没提交，没有源码改动。

---

## 6. 建议的第一个任务

先做 `runtime-io`，不要一上来改求解器核心。

```text
任务：    MPI 下 io_paths.txt 单写者
范围：    codes/main/src/SimuContextIO.cpp + 一个现有测试目标
不要：    改 Prj.cpp 公共语义、构建系统、测试架构
证据：    serial 不变；np=2 只有一个写者；现有测试通过
```

为什么是它：

- 审计已经定位了缺陷；
- 改动小、可审；
- 不需要构建重构（项目已拒绝）；
- 产出的报告可以和审计发现对照。

如果现有测试目标无法表达多 rank 行为，不要假装它覆盖了。在报告里记录缺口，
把 `mpirun -np 2` 的命令和输出作为人工证据。

第二个候选是 `numerics` 的小任务，例如让未实现的 scheme 显式 fail-fast，
而不是静默产生零通量。**第一个任务完整走通之前，不要同时开两个。**

---

## 7. 旧工作流 vs agentlab

| 你以前 | agentlab |
|---|---|
| `pi` 在 OneFLOW 主检出里跑，直接改工作区 | worker 在独立 git worktree 里跑，主检出保持干净 |
| 一个长会话不断累积上下文 | 每个 workstream 一个独立会话 |
| 事后自己看 diff | worker 必须提交，否则 `run_worker` 判失败 |
| 没有路径限制 | 改到 scope 外，`scope_check` 直接失败 |
| 没有验证门槛 | 三态门禁：PASS / FAIL / UNVERIFIED |
| 没有报告 | 强制报告 + commit SHA + repro 记录 |
| 串行做任务 | 多个 workstream 可以并行，各自独立 worktree |

代价：你要写任务、定 scope、维护 contracts 和 verification。  
收益：你审的是一个小 diff 和一份报告，而不是一整段长对话。

---

## 8. 什么时候别用 agentlab

- “这个函数在哪” → 原生 Pi；
- “为什么编译不过” → 原生 Pi；
- 一行修复、改注释 → 原生 Pi；
- 还没想清楚要交付什么 → 先用原生 Pi 探索。

agentlab 适合：**交付物已知，且你需要隔离、验证或可追溯记录。**

---

## 9. 文件在哪

```text
~/OneFLOW/.agentlab/               目标包（提交在 dev）
  TASKS.md                         人维护的任务板
  scope/<ws>.txt                   人维护的写入边界
  contracts/                       人维护的接口和数据布局
  verification/                    人维护的数值门禁
  reports/                         worker 产出
  RFC/                             待人工批准的提案
  repro/                           门禁证据
  target.env                       模式、base ref、workstream、命令

../OneFLOW-wt/<ws>/                worker 工作树（不在仓库里）
../OneFLOW-wt/logs/                worker 日志
../OneFLOW-wt/sessions/            worker 的 Pi 会话
../OneFLOW-wt/run/                 detach worker 的 pid 文件
```

worker 不使用主检出，也不使用你日常的 `~/.pi/agent`。

---

## 10. 已知阻塞和决策

| 项 | 状态 | 要做什么 |
|---|---|---|
| `.agentlab/target.env` 模式 | `audit` | 完成 4.1–4.5 后切 `worker` |
| `.agentlab/contracts/` | 通用模板 | 换成 OneFLOW 真实边界 |
| `.agentlab/verification/run_all.sh` | 占位 | 注册一个真实算例后才能 integration |
| `UNIT_CMD` | 会跑约 1067 个 CTest | 日常用 `ctest -R` 收窄 |
| `dev` vs `upstream/hexin` | 已分叉 | 先决定本地 fork 还是上游兼容基线 |
| 测试架构 | v0.1 冻结 | 不重构；按现有模式加测试 |
| `Prj`/测试源清单 | 人所有 | 不要复制或重写 |
