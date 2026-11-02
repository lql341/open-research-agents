[English](IMPLEMENTATION_PLAN.md) | **中文**

# Open Research Agents — 综合实施方案

> **持续更新的规划文件。** v0.1 记录初始实施和设计理由；下方路线图是当前方向。
> 当前仓库使用 `examples/validation/target`、`tests/fixtures/mini-target` 和
> `targets/oneflow`；当前流程见 [`docs/workflow.zh-CN.md`](docs/workflow.zh-CN.md)。

**状态：** Draft v1.0（综合稿）  
**综合来源：**
- `cfd-agents-starter.zip`：CFD 单仓库脚手架、AGENTS、contracts、scope/gate/integrate 脚本
- `agent-lab_1.zip`：`platform/` + `domains/` 分层、install_domain、repro_snapshot、治理文档
- 上一版 `IMPLEMENTATION_PLAN.md` 草案：v0.1–v0.5 长期路线
- 评审反馈：commit 纪律、preflight、core API contract、strict verification、command/push guard、session 策略

**首个领域：** CFD  
**首选 Agent Runtime：** Pi  
**v0.1 实现语言：** Bash + Markdown（可执行规范）  
**编排实现：** Bash + Markdown；TypeScript 任务引擎尚未排期  
**长期目标：** 面向科学计算与 AI4S 的开源、可验证、人类治理的多智能体研发平台

---

## 0. 摘要

> **v0.1 = agent-lab 的平台/领域分层 + starter 的 CFD 契约与任务 + 一个真实可编译的 `cfd-mini` 目标仓库 + 更硬的 gate。先单 worker，后双 worker；TypeScript 任务引擎尚未排期。**

---

## 1. 综合结论

### 1.1 采用什么

1. **采用 `agent-lab` 的平台/领域分层**  
   `platform/` 放通用规则、脚本、模板；`domains/<domain>/` 放契约、scope、任务、验证、复现字段；`install_domain.sh` 把领域包装进目标仓库的 `.agentlab/`。  
   理由：平台脚本在目标仓库之外，worker 改不了 gate；同一套平台可服务 OneFLOW、KylinFlow 等多个仓库。

2. **保留 `cfd-agents-starter` 的 CFD 具体内容**  
   `AGENTS` 铁律、`interfaces.md`、`data_layout.md`、`TASKS.md`、scope 思路、mock ODE / MMS 解耦测试，合并进 `domains/cfd/`。

3. **v0.1 不写 TypeScript 平台**  
   Bash 脚本就是可执行规范。先把 scope → build → unit → verification → integration 验证通过，再把语义固化成 TypeScript 编排器。  
   理由：现在缺的不是平台代码，而是“真实 C++ 工程 + 真实验证 + 真实权限检查”。

4. **新增 `examples/cfd-mini`**  
   两个 ZIP 都没有可编译的求解器代码，worker 无法实际启动。v0.1 必须提供一个独立 git 仓库形态的最小 CFD 工程：`Field/Mesh/Comm + CMake + CTest + 一个 MMS 算例`。  
   它是 target repo 的 fixture，不是平台仓库的子目录。

5. **新增硬门禁**  
   - `preflight.sh`：contracts 还有 TODO/[CONFIRM]、core/CMake/unit 测试缺失时，拒绝启动 worker；
   - `gate.sh` 三态：`PASS / FAIL / UNVERIFIED`；
   - integration gate 要求 `G3 numerical = PASS`；worker gate 允许 `UNVERIFIED`，但报告必须写明；
   - worker 必须 commit 到 `agent/<module>`，报告写 commit SHA；
   - `guard.ts` + `pre-push`：拦 `sbatch/srun`、`git push`、`gh pr merge`；
   - session 策略：`--session-id` 或 `--no-session` 显式选择，不留下无限增长的会话。

### 1.2 不在范围内

v0.1 不做：

- 隐式时间积分器（T3 保持 `blocked`，先 RFC）；
- MPI/GPU 并行性能优化（正确性全绿后单独串行任务）；
- TypeScript 任务引擎 / SQLite / 审批队列；
- 多项目、多租户、Web 面板；
- 自动合并关键求解器代码；
- 自动提交 HPC 集群作业；
- 跨项目长期记忆；
- 由 agent 批准 agent。

---

## 1A. v0.1 目标适配：OneFLOW，而不是 cfd-mini

- 真实目标仓库是 OneFLOW；`tests/fixtures/mini-target` 只是平台 smoke test fixture。
- OneFLOW 是 runtime/task 架构，不是 starter 的 spatial/temporal 两块干净模块。直接让两个 worker 并行改代码会重叠。
- v0.1 先开两个只读审计 worker：
  - `runtime-io`：`codes/main/`、`codes/io/`、`tests/main/`、`tests/io/`、`doc/AI_CONTEXT.md`
  - `numerics`：`codes/ns/`、`codes/residual/`、`codes/grad/`、`codes/solver/`、`codes/lhs/`、`codes/time/`、`codes/unsteady/`、`codes/update/`、相关 tests
- 审计产出：入口/调用者、状态与资源所有权、共享文件、测试覆盖、缺失契约、风险、可并行的 scope 提案、需要人确认的问题。
- 人确认 scopes/contracts 后，把 `target.env` 的 `AGENTLAB_MODE` 从 `audit` 改为 `worker`，再开代码任务。
- 这样避免在 OneFLOW 这种紧耦合代码库里过早并行编辑。

### 1A.1 首次审计记录（2026-11-01）

- OneFLOW `.agentlab/` 已安装并提交到 `dev`（`7328dc504`）。
- 两个只读审计已运行并合入 `dev`（merge commits `883640c07`、`94a7161b8`）：
  - `runtime-io`：369 行报告 + RFC；发现 `io_paths.txt` 多 rank 写者过滤缺失、`TeardownCase` 无测试、测试源清单重复。
  - `numerics`：449 行报告 + RFC；发现 `HybridRoe()` 空实现、`linearTwoStepMethods` 越界退化、`SolverState::Converge()` 恒真、数值循环无实例化测试、显式 RK 无基线。
- 两份报告都停留在 `need_decision`/`ready`，没有声称任何未运行的测试通过。
- **决策（2026-11-01）：不改目标仓库的测试架构。** runtime-io 提出的共享
  `oneflow_case_runtime` 目标不采纳；`TeardownCase` 的覆盖缺口作为已知问题记录，
  由人工决定是否值得单独处理。理由：这是对大仓库的构建重构，没有独立的性能或正确性
  收益，且编译宏传播风险高，属于人所有的工作。见
  `platform/docs/decisions/0002-no-test-architecture-refactor.md`。
- worker 只允许按现有模式加测试：一个测试目标列出它需要的生产源，不新建测试入口、
  不改构建系统。
- 下一步：人工确认两个不重叠的代码 workstream，切 `AGENTLAB_MODE=worker`。
  该执行工作可以与 v0.2 注意力收件箱（已实现）和 v0.3 Mandate-lite 并行推进。

## 2. 总体架构

```text
Human Principal
      │ 授权、审批、优先级
      ▼
Lead / Reviewer（v0.1 = 人工操作的 Pi 主会话，可只读）
      │
      ▼
Platform（目标仓库之外，worker 不可修改）
  - scope_check / preflight / gate / integrate
  - run_worker / repro_snapshot / guard
  - 模板与治理文档
      │
      ▼
Target Repo
  .agentlab/            ← install_domain.sh 安装
    AGENTS.md
    contracts/
    scope/
    TASKS.md
    verification/
    reports/
    RFC/
    repro/
    sessions/
  core/                 ← CFD 数值基础，人工维护，worker 只读
  modules/spatial/      ← Worker A
  modules/temporal/     ← Worker B
  tests/
      │
      ▼
Gates
  G0 scope → G1 build → G2 unit → G3 numerical → G4 integration → G5 performance
      │
      ▼
Integration branch → Human approval → main
```

### 2.1 仓库布局

```text
open-research-agents/
├── platform/
│   ├── AGENTS.md
│   ├── scripts/
│   │   ├── preflight.sh
│   │   ├── scope_check.sh
│   │   ├── gate.sh
│   │   ├── run_worker.sh
│   │   ├── integrate.sh
│   │   ├── repro_snapshot.sh
│   │   └── install_domain.sh
│   ├── extensions/
│   │   └── guard.ts
│   ├── templates/
│   │   ├── report.md
│   │   ├── rfc.md
│   │   └── decision.md
│   └── docs/
│       ├── domain-pack-spec.md
│       ├── governance.md
│       └── verification.md
│
├── domains/
│   └── cfd/
│       ├── domain.env
│       ├── AGENTS.domain.md
│       ├── contracts/
│       │   ├── interfaces.md
│       │   ├── data_layout.md
│       │   └── core_api.md
│       ├── scope/
│       │   ├── spatial.txt
│       │   └── temporal.txt
│       ├── TASKS.md
│       ├── verification/
│       │   ├── README.md
│       │   ├── run_all.sh
│       │   └── cases/
│       └── repro_fields.yaml
│
├── examples/
│   └── cfd-mini/          # 独立 git 仓库骨架，用于 demo/CI
│       ├── CMakeLists.txt
│       ├── core/
│       ├── modules/
│       ├── tests/
│       └── .gitignore
│
├── tests/                 # 平台脚本测试
├── docs/
├── AGENTS.md
├── README.md
└── IMPLEMENTATION_PLAN.md
```

**命名澄清：**

- `platform/`：平台内核（脚本、规则、模板），不是 CFD 数值核心；
- `domains/cfd/`：CFD 领域包；
- 目标仓库里的 `core/`：CFD 的 `Field / Mesh / Comm`，人工维护，agent 只读；
- 目标仓库里的 `.agentlab/`：领域包安装位置，worker 只读契约与验证。

---

## 3. 角色与权限

| 角色 | v0.1 由谁承担 | 职责 | 禁止 |
|---|---|---|---|
| Human Principal | 你 | 填契约、确认接口、注册验证、审批合并 | — |
| Lead / Reviewer | 你的 Pi 主会话 | 拆任务、审核 diff、运行 integration gate、提出审批建议 | 不直接改模块代码；不代替人批准 |
| Worker Spatial | `pi -p` / `pi --session-id` | 实现空间离散、测试、报告、commit | 不改 core/contracts/scripts/verification；不 push/merge |
| Worker Temporal | 同上 | 实现时间积分、mock ODE 测试、报告、commit | 同上 |
| Platform | Bash 脚本 | 确定性执行 scope/gate/integrate/复现快照 | 不做技术判断 |

**职责分离：**

- Worker 写代码；
- Lead/Reviewer 审核；
- Human 批准契约、验证基准、合并 main；
- 任何 agent 的“通过”都不等于人类批准。

---

## 4. CFD v0.1 契约

### 4.1 数据布局（必须人工填写）

`domains/cfd/contracts/data_layout.md` 保持 TODO 清单，但 v0.1 必须先做出最小决定：

- 结构化 1D 网格；
- 守恒变量顺序固定；
- ghost 宽度固定；
- AoS（v0.1 简单优先；SoA 作为后续 RFC）；
- `double`；
- MPI 暂不启用，`Comm` 提供串行 no-op 与 `mpirun -np 4` 的接口占位。

**在 `data_layout.md` 填完前，worker 不得启动。**

### 4.2 Core API（新增 `contracts/core_api.md`）

两个 ZIP 只给了 `Field/Mesh/Comm` 类名，没给方法。worker 会猜，然后 spatial/temporal 各发明一套。v0.1 必须固定最小面：

```cpp
namespace cfd {

class Field {
public:
  double* data();
  const double* data() const;
  std::size_t size() const;

  Field like() const;                    // 同布局，未初始化
  void copy(const Field& other);
  void axpy(double a, const Field& x);   // this += a*x
  double norm2() const;
};

class Mesh {
public:
  int dim() const;
  int nx() const;
  int ny() const;
  int nz() const;
  double dx() const;
  double dy() const;
  double dz() const;
  bool periodic(int axis) const;
  std::size_t cellCount() const;
  std::size_t ghostWidth() const;
};

class Comm {
public:
  void haloExchange(Field& field) const;
  double allreduceMin(double value) const;
  double allreduceSum(double value) const;
};

} // namespace cfd
```

规则：

- `Field` 的 `like/copy/axpy/norm2` 是 v0.1 必需，temporal 的 RK 不能自己发明；
- `Mesh` 只读；v0.1 结构化 1D，2D/3D 方法可先返回 1；
- `Comm` 串行时 no-op；MPI 实现留到后续阶段；
- 不允许 worker 修改 `core/`。

### 4.3 模块接口（修正版）

```cpp
namespace cfd {

class ISpatialOperator {
public:
  virtual ~ISpatialOperator() = default;

  // 计算残差 R；U 只读。
  // halo 交换由 spatial 在 residual 内部完成；调用者不预先交换。
  virtual void residual(const Field& U, double t, Field& R) const = 0;

  // 本进程内的稳定性时间步上限（CFL=1）。
  // 全局最小值由 time integrator 通过 Comm 归约。
  virtual double max_stable_dt(const Field& U, double t) const = 0;
};

class ITimeIntegrator {
public:
  virtual ~ITimeIntegrator() = default;

  // U 原地推进；t 更新时间；dt 由调用者给定。
  // comm 用于 max_stable_dt 的全局归约。
  virtual void advance(Field& U, double& t, double dt,
                       const ISpatialOperator& L, Comm& comm) = 0;

  virtual int order() const = 0;
};

} // namespace cfd
```

必须确认的约定：

- `dU/dt = R(U,t)`，`R` 已包含符号与单元体积归一化；
- `U` 只读，`R` 输出；
- halo 交换由 spatial 负责；
- 边界条件由 spatial 通过 `residual()` 体现；
- `max_stable_dt` 是空间稳定性建议值，不是最终 dt；
- 时间步裁剪由 temporal 负责；
- RK 工作数组由 temporal 用 `Field::like()` 分配。

**未确认前，worker 只能写 `need_decision`，不能猜。**

### 4.4 解耦测试

- Temporal：`tests/mocks` 提供线性/非线性 ODE 算子，实现 `ISpatialOperator`，验证时间阶数；
- Spatial：MMS 人造解，直接比较 `residual()` 与解析时间导数，验证空间阶数；
- 联调只在 integration 分支通过真实验证算例完成。

---

## 5. 门禁与验证

### 5.1 分层门禁

| 门 | 内容 | 结果 |
|---|---|---|
| G0 | scope 检查：新增/删除/重命名/未提交文件 | PASS / FAIL |
| G1 | 编译与静态检查 | PASS / FAIL |
| G2 | 单元测试（`ctest -L unit`） | PASS / FAIL |
| G3 | 数值验证（MMS/ODE/守恒） | PASS / FAIL / **UNVERIFIED** |
| G4 | 集成回归 | PASS / FAIL |
| G5 | 性能基准 | PASS / FAIL / N/A |

**关键规则：**

- 未注册验证算例时，G3 必须是 `UNVERIFIED`，不能默认为 `PASS`；
- worker gate 允许 `UNVERIFIED`，但报告状态必须写明，不得写“数值正确”；
- integration gate 要求 `G3 = PASS`；没有真实验证算例时 integration 必须失败；
- 只有 `G0–G4` 全 PASS，才允许进入人工审批。

### 5.2 `gate.sh` 三态

```bash
# worker：允许 G3 UNVERIFIED
scripts/gate.sh spatial

# integration：要求 G3 PASS
GATE_MODE=integration scripts/gate.sh
```

实现建议：

- `GATE_MODE=worker|integration|release`；
- `run_all.sh` 在 `GATE_MODE=integration` 且没有注册算例时 `exit 1`；
- gate 结束写 `.agentlab/repro/last-gate.json`：`{mode, status, module, at}`；
- `repro_snapshot.sh` 读取该文件，写入完整复现记录。

### 5.3 复现记录

每个数值/性能结论必须写 `.agentlab/repro/<label>-<timestamp>.json`，至少包含：

```json
{
  "label": "spatial-S1",
  "gate_mode": "worker",
  "gate_status": "unverified",
  "git_commit": "<sha>",
  "git_branch": "agent/spatial",
  "git_dirty": false,
  "pi_version": "<version>",
  "model": "<provider/model>",
  "host": "<host>",
  "compiler": "<c++ --version>",
  "cmake": "<cmake --version>",
  "mpi": "<mpirun --version or none>",
  "commands": ["..."],
  "case": { "name": "mms-1d", "input_hash": "<sha256>" },
  "metrics": { "error_l2": null, "observed_order": null, "elapsed_seconds": null },
  "result": "unverified"
}
```

字段模板见 `domains/cfd/repro_fields.yaml`；验证算例负责写 `*.case.json`。

### 5.4 报告模板

`platform/templates/report.md` 增加：

```text
status: ready | blocked | need_decision
commit:
branch:
model:
pi_version:
gate_mode:
gate_status:
gate tail:
repro files:
```

`ready` 只表示“可进入集成审查”，不表示“数值已验证”。

---

## 6. 协作与工作流

### 6.1 Worker 单轮流程

```text
preflight → 读 AGENTS/contracts/scope/TASKS
  → 只做本模块第一个 todo
  → 先写测试
  → 实现
  → gate（worker 模式）
  → git add 范围内文件 + commit 到 agent/<module>
  → 写报告（含 commit SHA）
  → 停止
```

**必须 commit。** 否则 `integrate.sh` 合并的分支上没有可合并的变更。

**禁止 push。** 推送由 `pre-push` hook 或 command guard 拦截。

### 6.2 Scope 检查

`scope_check.sh` 必须覆盖：

- 已提交 diff：`git diff --name-only "$BASE"...HEAD`；
- 工作区 diff：`git diff --name-only`；
- 未跟踪文件：`git ls-files --others --exclude-standard`；
- 删除/重命名：Git 路径会体现，测试用例要覆盖；
- `BASE` 先 `git fetch`，避免用过期 main；
- scope 文件从 `BASE` 读取，worker 改不了；
- RFC/repro 建议限制为 `.agentlab/RFC/<module>-*`、`.agentlab/repro/<module>-*`，避免跨模块覆盖。

### 6.3 集成

`integrate.sh`：

1. 检查工作区干净；
2. `git fetch`；
3. `git checkout -B integration main`；
4. 按 `MODULES` 顺序合并 `agent/<module>`；
5. 冲突则 abort，并要求对应 worker 基于最新 main 整理；
6. 运行 `GATE_MODE=integration scripts/gate.sh`；
7. 通过后停在 `integration`，等待人工审查；
8. 人工批准后合并 `main`。

**v0.1 不允许自动合并 main。**

### 6.4 定期交互

v0.1 的协作是**异步的**：worker 通过 `TASKS.md`、`contracts/`、`RFC/`、`reports/` 交互，不自由聊天。

如需定期同步，增加 `scripts/sync.sh`（v0.1.1）：

```text
你是 spatial 的负责 agent。不要改代码。
阅读 .agentlab/reports/temporal.md、contracts/、git log integration..agent/temporal。
输出：
1. 你是否受影响
2. 是否需要 RFC
3. 下一步建议
写入 .agentlab/reports/sync-<date>-spatial.md
```

两个 worker 各运行一次，由人或只读 lead 汇总决策。

---

## 7. 安全与权限

### 7.1 强制点

| 阶段 | 强制手段 |
|---|---|
| Worker 启动前 | `preflight.sh` 校验 contracts/scope/core/CMake/unit 测试 |
| 工具调用时 | `guard.ts` 拦截 `sbatch/srun`、`git push`、`gh pr merge` |
| 提交前 | `scope_check.sh` 校验文件范围 |
| 集成前 | `gate.sh` 校验 build/unit/verification |
| 合并/发布前 | 人工审批 |

### 7.2 明确边界

- Git 路径检查是**必要但不充分**；
- `guard.ts` 是**约定级防护**，不是沙箱；有 bash 权限的 worker 技术上仍可绕过；
- 真实隔离需要容器、独立 OS 用户或执行网关；
- 高风险项目（芯片代码、生产仓库）必须使用独立账号/容器，并限制凭据；
- 不提交 HPC 作业；大算例命令写入报告，由人执行。

### 7.3 Pi 特有防护

- `run_worker.sh` 加 `-e "$PLATFORM/extensions/guard.ts"`；
- 目标仓库安装 `pre-push` hook：只允许 `agent/*` 分支推送；
- Worker 使用 `--session-id "agentlab-$MODULE"` 或 `--no-session`；
- Worker 不加载不必要的 MCP/extension；默认工具即可；
- 记录 `pi --version` 与模型到复现记录。

---

## 8. 路线图

方向是**注意力治理优先**。执行层已经存在：Pi worker、隔离工作树、scope 强制、
三态门禁和报告。剩余工作是控制面：决定什么值得占用人的注意力，以及什么工作被授权。

分层吸收 dsh-superagent；不把 DSH 作为运行时。每个阶段独立交付，并保持前一阶段可用。
短期交接见 [`docs/living-todo.zh-CN.md`](docs/living-todo.zh-CN.md)。

### v0.1 — 手动任务执行层（已完成）

- Pi worker 在独立工作树和会话中运行；scope、门禁、报告、repro 已打通。
- OneFLOW target 处于 audit 模式；两个只读审计已完成。
- 平台和 target pack；92 项 smoke 检查和 27 项 harness 检查。

局限：仍由人决定什么进入注意力；没有 Source、Mandate、Ticket、Outbox 或注意力视图。

### v0.2 — 注意力收件箱（已实现，beta）

目标：在增加自主性之前，先降低注意力成本。

- `agentlab inbox`：将条目分类为 `pending`、`review`、`fyi`。
- 条目来源：
  - `reports/*.md` 中 `status: need_decision`；
  - `RFC/*.md` 中 `Status: proposed`；
  - gate 的 `FAIL` 或 `UNVERIFIED`；
  - worker 失败和中断的运行。
- `agentlab decide <id>`：记录决定并回写到任务板。
- 注意力策略：按类型选择 `never`、`digest` 或 `immediate`；限制每个任务的问题数量。

验收：一条命令只显示需要人的内容；分类确定性；不调用模型；不新增 Source 或自主行动。

当前实现：`agentlab inbox` 和 `agentlab decide`；策略键位于 `.agentlab/target.env`。
参见 [`docs/usage.zh-CN.md`](docs/usage.zh-CN.md)。

### v0.3 — Mandate-lite 与 Ticket-lite（已实现，beta）

目标：让授权显式，但不引入完整 dsh 领域模型。

- Ticket 记录 `source`、`sender`、`strength`（`explicit`/`inferred`）、`rule`、
  `policy_version`、`scope_ref`、`scope_hash`、`status` 和 `history`。
- `policy_version` 对 `AGENTS.md`、contracts、scope、mode、target 和 base ref 做哈希；
  `ticket revalidate` 将变化的 ticket 标为 `stale`。
- Ticket 生命周期：`proposed → authorized → running → review/blocked → ended`；
  恢复和停止是显式命令。
- scope 和 gate 仍是强制层。Ticket 引用 workstream scope，因此不能扩大 scope。
- 这是账本，不是执行调度器；每 ticket 的 session 和 assignment 留到 v0.6。

验收：每个 ticket 记录其被允许的原因；revalidation 能标记策略变化；ticket 不能扩大 scope。

当前实现：`agentlab ticket new/list/show/authorize/reject/set/revalidate/resume`；
proposed 和 stale ticket 会出现在收件箱。参见 [`docs/usage.zh-CN.md`](docs/usage.zh-CN.md)。

### v0.4 — Source 与 Trigger（先接 GitHub，已实现，beta）

目标：让工作从事件流进入，同时不失去控制。

- 第一个 Source：通过已认证的 **agent 账号** wrapper（`GITHUB_CLI`，例如 `gh-agent`）读取
  GitHub notifications，不使用真人账号。只读。
- 候选记录 repo、notification id、reason、subject type、title、URL、strength 和 status。
  notifications endpoint 不提供 actor，因此 `sender` 暂为 `unknown`，后续 Source 适配器再补齐。
- 使用 notification id + `updated_at` 去重；同一通知更新后会产生新候选。
- 准入仅支持 `observe`：候选进入 Inbox，不自动创建 ticket。批准时必须指定 workstream，
  并创建 `source=github` 的已授权 ticket。
- `agentlab source github status` 和 `poll`；`--input` 读取已保存的 fixture。
- 轮询不会把通知标记为已读。

验收：一条 GitHub mention 生成一个候选；重复轮询被忽略；不自动创建 ticket；
批准后创建带策略快照的已授权 ticket。

当前实现：`agentlab source github poll/status`、`.agentlab/candidates/`、
`.agentlab/sources/github.json`。参见 [`docs/usage.zh-CN.md`](docs/usage.zh-CN.md)。

### v0.4.1 — Source 与收件箱硬化（下一步）

目标：在增加对外通信之前，让注意力闭环达到可日常使用的可靠度。

- Source 分页与限流：超过 100 条通知、HTTP 403/429、部分失败；保留上一次成功轮询状态。
- 候选详情：尽可能解析 actor，保留 thread/subject 标识，避免轻微更新产生新候选。
- Source 健康：在 `sources/github.json` 记录最近错误、连续失败次数和上次成功轮询；
  在 `source status` 中显示。
- 收件箱过滤：`--category`、`--since`，JSON 输出包含 decision 和 ticket id；`fyi` 默认隐藏。
- 决策审计：只读的 `agentlab decisions` 视图，读取 `.agentlab/decisions/`。
- 测试：分页、429、候选更新、decision 列表。

验收：连续两次轮询不产生重复候选；限流轮询保留上次状态并报告错误；inbox 过滤结果与
JSON 一致。

当前短期工作见 [`docs/living-todo.zh-CN.md`](docs/living-todo.zh-CN.md)。

### v0.5 — Outbox 与 Channel

目标：让对外通信持久且幂等。

- Outbox：先写后发、退避重试、receipt。
- 第一个 Channel：GitHub 评论/回复。
- 不自动合并；回复只限于 ticket 的来源 thread。

验收：回复只发送一次；重试不产生重复评论；发送失败在 `status` 中可见。

### v0.6 — Ticket 执行语义对齐

目标：在 solo 场景重要的地方对齐 dsh-superagent 的执行语义。

- 每个 ticket 一个 session 和工作区，而不是每个 workstream。
- Subscription 和 follow-up：ticket thread 上的人消息可以恢复它。
- 停止、重试、重启和 policy revalidation。
- 后台工作和长时间任务限制。

验收：ticket 在重启后仍存在；follow-up 能恢复；被停止的 ticket 不接收自动输入。

### v0.7 — 多 target 与注意力视图

目标：管理多个仓库而不放大注意力。

- 一个 workspace 下多个 target。
- 跨 target 的统一 Inbox，按 target 和注意力类型分组。
- 可选的终端或 Web 注意力视图；不做完整活动面板。

验收：两个 target 共用一个 Inbox；target A 的 worker 不能写 target B。

### v0.8 — 有边界自主

目标：只有注意力和授权层被证明后，才允许主动工作。

- Campaign：跨 ticket 的长期目标。
- 预算：workers、模型成本、GPU hours。
- Task 权限是 campaign 权限的子集。
- 只对 observe 模式精确度已被测量并经人接受的规则开放 auto-accept。
- 高风险动作仍需要人工批准。

验收：预算被强制执行；auto-accept 仅限白名单规则；每个决定可审计。

## 8A. 从 dsh-superagent 吸收什么

dsh-superagent 是控制面的参考实现。复用其概念和部分 core 代码（MIT），不把 DSH 作为运行时。

| dsh-superagent | agentlab 阶段 | 复用 | 不复用 |
|---|---|---|---|
| 注意力哲学（`docs/000`） | 全部 | 只在被请求或规则允许时行动；只在人必须行动时说话；一次一个问题；诚实报告 | — |
| 领域模型（`docs/001`） | v0.3、v0.6 | Trigger、Thread、Ticket、Mandate、Subscription、Assignment | solo 场景不需要的完整多用户准入模型 |
| 执行模型（`docs/003`） | v0.6 | 每 ticket session/工作区、恢复、停止、重新校验 | DSH presets、DSH job/subagent 服务 |
| `src/core` | v0.3、v0.6 | 领域类型和纯规则 | DSH 专属胶水 |
| `src/policy.ts` | v0.3 | Gate、policy version、revalidation | 原样照搬多用户 allowed list |
| Outbox / Effects 模式 | v0.5 | 先写后发、receipt、重试、幂等 | DSH channel 实现 |
| 面板 / 注意力路由 | v0.2、v0.7 | 按“需要人”排序；隐藏健康状态 | DSH Web 客户端 |
| DSH executor 和 presets | — | — | 不移植 |
| DSH Source 插件 | v0.4 | 事件形状和去重思路 | 不依赖 DSH 插件 |

规则：

- `platform/`、`domains/`、`targets/` 不引入 DSH 类型。
- 只复用不依赖 DSH 的代码；其他概念重新实现。
- 复制代码时保留 MIT 版权声明。
- 不把 DSH 加入平台依赖。
- 如果某个阶段离开 DSH 无法交付，停止并记录原因；不得静默耦合两套运行时。

## 9. Sprint 计划

> Sprint 0–4 记录原始 v0.1 实施。未来工作以第 8 节路线图为准。

### Sprint 0：审查与地基（1–2 天）

- 审查两个 ZIP 的全部脚本与文档；
- 建立 `open-research-agents/` 仓库骨架；
- 建立 `examples/cfd-mini` 独立 git 仓库；
- 合并 `domains/cfd/`；
- 实现 `install_domain.sh` 安装到 `cfd-mini`；
- 增加 `preflight.sh`；
- 增加根 `AGENTS.md` 指针（Pi 自动加载根 `AGENTS.md`，不会自动加载 `.agentlab/AGENTS.md`）。

**交付：** `cfd-mini` 可编译，`.agentlab` 安装完成，preflight 能拒绝空契约。

### Sprint 1：单 Worker 垂直切片（3–5 天）

- 填 `data_layout.md`；
- 确认 `interfaces.md` 的 `[CONFIRM]`；
- 写 `core_api.md`，实现 `Field/Mesh/Comm` 最小版；
- 根 `CMakeLists.txt`，`ctest -L unit` 标签；
- 注册一个真实 MMS 空间收敛算例；
- 运行 Spatial S1；
- 检查 scope/gate/report/commit/repro；
- 修复脚本问题。

**交付：** 单 Worker 能完成真实开发任务，输出可信但明确标注 `G3` 状态的报告。

### Sprint 2：双 Worker 与集成（3–5 天）

- Temporal T1（mock ODE，Forward Euler + SSPRK3）；
- 两个 worktree 并行；
- `integrate.sh` 合并；
- 使用 `GATE_MODE=integration` 运行 G0–G4；
- 人工审批报告；
- 合并 main。

**交付：** 可复现的双 Agent CFD Demo。

### Sprint 3：硬化与 v0.1 发布（1–2 周）

- `guard.ts` + `pre-push`；
- `sync.sh`；
- scope 覆盖删除/重命名/未跟踪；
- 平台脚本测试；
- Quickstart、治理说明、已知限制；
- 开源许可证与依赖检查。

### Sprint 4：v0.2 任务引擎（2–3 周）

- TypeScript 平台；
- SQLite；
- Task 状态机；
- 消息协议；
- RFC/审批；
- 恢复与幂等。

---

## 10. v0.1 验收标准

- [ ] `examples/cfd-mini` 能独立 `cmake` + `ctest`；
- [ ] `install_domain.sh cfd <repo>` 能安装 `.agentlab/`，不覆盖已编辑文件；
- [ ] `preflight.sh` 在 contracts 有 TODO/[CONFIRM]、core/CMake/unit 缺失时失败；
- [ ] Spatial S1 在独立 worktree 完成，scope 检查通过；
- [ ] Temporal T1 用 mock ODE 独立验证，不依赖 spatial；
- [ ] 两个 worker 并发运行，无共享文件写入冲突；
- [ ] 越权修改（新增/删除/重命名/未跟踪）被 scope_check 拒绝；
- [ ] `guard.ts` 拦住 `sbatch/srun`、`git push`、`gh pr merge`；
- [ ] worker 必须 commit；报告含 commit SHA；
- [ ] worker gate 允许 `G3=UNVERIFIED`，但报告明确标注；
- [ ] integration gate 在无真实验证算例时失败；
- [ ] integration G0–G4 通过后，人工审批才能合并 main；
- [ ] 复现记录含 commit、编译器、硬件、模型、Pi 版本、命令；
- [ ] Quickstart 能让一个新人在 30 分钟内验证通过单 worker。

---

## 11. 风险与应对

| 风险 | 应对 |
|---|---|
| 验证关卡为空，gate 误报 | `G3=UNVERIFIED`；integration 必须有真实算例 |
| 隐式格式导致接口强耦合 | T3 blocked；先 RFC 确定 Jacobian 接口 |
| Worker 不 commit，集成无变更 | AGENTS + run_worker 后检查 `git status`/`git rev-list` |
| Scope 只查路径，不查命令 | `guard.ts` + pre-push；高风险用容器 |
| `pi -p` 无状态，跨轮丢上下文 | `--session-id` 或 `--no-session` 显式选择；报告即记忆 |
| Build 资源竞争 | `-j` 上限、ccache/sccache、GPU/FPGA 资源锁 |
| Agent 过度自信 | 数值门禁 + 人工 review；禁止“LLM 说通过” |
| 平台/领域耦合 | domain pack spec；第二个领域检验 |
| Pi 版本漂移 | pin 版本 + smoke test；只依赖公开 API |
| 过度建设平台 | v0.1 只使用 Bash；TypeScript 任务引擎尚未排期 |

---

## 12. 给 Coding Agent 的第一轮指令

你是本项目的工程实现 Agent。第一轮只做 **Phase 0 + 单 Worker 垂直切片**，不要进入 Phase 2。

### 12.1 必须遵守

1. 先审查两个 ZIP 和当前仓库，不要假设脚本已正确运行；
2. 不得修改 `domains/cfd/contracts/` 中的人填内容；接口不明确时写 RFC/`need_decision`；
3. 不得放宽容差、跳过测试或删除失败测试；
4. 不得提交 HPC 作业、push、merge；
5. 未运行的测试标记 `Not Run`；
6. 优先复用现有 starter，不要重写平台；
7. 保持 `platform/` 与 `domains/` 分离。

### 12.2 执行顺序

1. 输出当前仓库结构与问题清单；
2. 建立 `open-research-agents/` 骨架；
3. 建立 `examples/cfd-mini`；
4. 合并 `domains/cfd/`；
5. 实现 `preflight.sh`；
6. 确认 CFD 最小接口 + `core_api.md`；
7. 实现 `Field/Mesh/Comm` 最小版 + CMake + CTest；
8. 注册一个真实 MMS 算例；
9. 运行 Spatial S1；
10. 检查 scope/gate/report/commit/repro；
11. 输出下一轮双 Worker 建议。

### 12.3 每轮输出格式

```text
Summary
Files Changed
Contracts Affected
Tests Executed
Numerical Verification
Known Risks
Pending Approvals
Next Tasks
```

---

## 13. 与两个 ZIP 的差异清单

| 项目 | `cfd-agents-starter` | `agent-lab_1` | 综合方案 |
|---|---|---|---|
| 目录结构 | 单仓库内 `coordination/` | `platform/` + `domains/` + 安装到 `.agentlab/` | **采用 agent-lab** |
| 平台位置 | 仓库内，worker 可改 | 仓库外，worker 不可改 | **采用 agent-lab** |
| 多项目 | 不支持 | 领域包可复用 | **v0.3 采用** |
| CFD 契约 | 详细 | 同源 | **保留，补 `core_api.md`** |
| Core API | 未定义 | 未定义 | **新增** |
| 验证 | 占位 | 占位 | **三态 + integration 严格** |
| 复现记录 | 无 | `repro_snapshot.sh` | **采用，补 Pi/模型/命令** |
| Worker commit | 未要求 | 未要求 | **新增强制** |
| Preflight | 无 | 无 | **新增** |
| 命令拦截 | 仅 AGENTS | 仅 AGENTS | **新增 guard + pre-push** |
| Session 策略 | 未指定 | 未指定 | **显式 `--session-id`/`--no-session`** |
| 可编译示例 | 无 | 无 | **新增 `examples/cfd-mini`** |
| 平台语言 | bash | bash | **v0.1 bash；TypeScript 任务引擎尚未排期** |
| 任务引擎 | 无 | 文档提到未实现 | **尚未排期；见第 8 节** |
| 治理文档 | 简单 | `governance.md` 诚实列出未实现 | **保留并映射到 v0.2+** |

---

## 14. 最终成功标准

不以 agent 数量衡量，而以以下能力衡量：

1. 多个 agent 能安全协作修改科学计算软件；
2. 能阻止接口冲突和越权修改；
3. 能独立验证数值正确性；
4. 能恢复中断的长期任务；
5. 能管理多个独立科研仓库；
6. 能在有限预算和明确授权下推进研发；
7. 能通过 Domain Pack 扩展到其他 AI4S 领域；
8. 每天占用人的注意力是有界、可见的，且只用于决策或可使用的结果。

**实施策略：**

> CFD First → Verified Multi-Agent Development → Multi-Project Coordination → Bounded Autonomous Research → Open AI4S Platform.

**第一轮授权：**

> 只完成 Phase 0 和单 Worker 垂直切片。等真实 C++ 编译、数值验证、scope/gate/commit/repro 都验证通过，再开 Spatial/Temporal 双 Worker。
