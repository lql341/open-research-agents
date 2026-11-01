# Open Research Agents — 综合实施方案

**状态：** Draft v1.0（综合稿）  
**综合来源：**
- `cfd-agents-starter.zip`：CFD 单仓库脚手架、AGENTS、contracts、scope/gate/integrate 脚本
- `agent-lab_1.zip`：`platform/` + `domains/` 分层、install_domain、repro_snapshot、治理文档
- 上一版 `IMPLEMENTATION_PLAN.md` 草案：v0.1–v0.5 长期路线
- 评审反馈：commit 纪律、preflight、core API contract、strict verification、command/push guard、session 策略

**首个领域：** CFD  
**首选 Agent Runtime：** Pi  
**v0.1 实现语言：** Bash + Markdown（可执行规范）  
**v0.2 起实现语言：** TypeScript（编排器/任务引擎）  
**长期目标：** 面向科学计算与 AI4S 的开源、可验证、人类治理的多智能体研发平台

---

## 0. 一句话

> **v0.1 = agent-lab 的平台/领域分层 + starter 的 CFD 契约与任务 + 一个真实可编译的 `cfd-mini` 目标仓库 + 更硬的 gate。先单 worker，后双 worker；TypeScript 平台推迟到 v0.2。**

---

## 1. 综合结论

### 1.1 采用什么

1. **采用 `agent-lab` 的平台/领域分层**  
   `platform/` 放通用规则、脚本、模板；`domains/<domain>/` 放契约、scope、任务、验证、复现字段；`install_domain.sh` 把领域包装进目标仓库的 `.agentlab/`。  
   理由：平台脚本在目标仓库之外，worker 改不了 gate；同一套平台可服务 OneFLOW、KylinFlow 等多个仓库。

2. **保留 `cfd-agents-starter` 的 CFD 具体内容**  
   `AGENTS` 铁律、`interfaces.md`、`data_layout.md`、`TASKS.md`、scope 思路、mock ODE / MMS 解耦测试，合并进 `domains/cfd/`。

3. **v0.1 不写 TypeScript 平台**  
   Bash 脚本就是可执行规范。先把 scope → build → unit → verification → integration 跑通，再把语义固化成 TypeScript 编排器。  
   理由：现在缺的不是平台代码，而是“真实 C++ 工程 + 真实验证 + 真实权限检查”。

4. **新增 `examples/cfd-mini`**  
   两个 zip 都没有可编译的求解器代码，worker 无法真正开跑。v0.1 必须提供一个独立 git 仓库形态的最小 CFD 工程：`Field/Mesh/Comm + CMake + CTest + 一个 MMS 算例`。  
   它是 target repo 的 fixture，不是平台仓库的子目录。

5. **新增硬门禁**  
   - `preflight.sh`：contracts 还有 TODO/[CONFIRM]、core/CMake/unit 测试缺失时，拒绝启动 worker；
   - `gate.sh` 三态：`PASS / FAIL / UNVERIFIED`；
   - integration gate 要求 `G3 numerical = PASS`；worker gate 允许 `UNVERIFIED`，但报告必须写明；
   - worker 必须 commit 到 `agent/<module>`，报告写 commit SHA；
   - `guard.ts` + `pre-push`：拦 `sbatch/srun`、`git push`、`gh pr merge`；
   - session 策略：`--session-id` 或 `--no-session` 显式选择，不留下无限增长的会话。

### 1.2 不做什么

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
| Lead / Reviewer | 你的 Pi 主会话 | 拆任务、审核 diff、跑 integration gate、提出审批建议 | 不直接改模块代码；不代替人批准 |
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

两个 zip 只给了 `Field/Mesh/Comm` 类名，没给方法。worker 会猜，然后 spatial/temporal 各发明一套。v0.1 必须固定最小面：

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
- `Comm` 串行时 no-op；MPI 实现留到 v0.2；
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
6. 跑 `GATE_MODE=integration scripts/gate.sh`；
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

两个 worker 各跑一次，由人或只读 lead 汇总决策。

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

### v0.1 — 可运行的双 Worker CFD Demo

- `platform/` + `domains/cfd/` + `examples/cfd-mini`；
- 单 Worker Spatial S1 跑通；
- 双 Worker Spatial S1 + Temporal T1；
- G0–G4 门禁；
- commit/report/repro；
- 人工审批后合并 main。

### v0.1.1 — 硬化

- `preflight.sh`、`guard.ts`、`pre-push`；
- `sync.sh`；
- `GATE_MODE` 三态；
- scope 覆盖删除/重命名/未跟踪；
- 平台脚本测试。

### v0.2 — 任务引擎与协作

- TypeScript `platform/`（保留 bash 脚本为兼容层）；
- SQLite：`projects/tasks/assignments/agents/events/messages/approvals/artifacts`；
- Task 状态机：`proposed → authorized → ready → running → blocked/review/rework/verified/completed`；
- 结构化消息：`proposal/objection/ack/decision/blocked/review_request/verification_result`；
- RFC 状态与 contract version；
- 审批队列；
- 幂等执行、失败恢复、外部副作用去重。

**验收：** 重启协调服务后能恢复未完成任务，并安全决定继续/重试/等待人工。

### v0.3 — 多项目

- Workspace → Project → Repository；
- OneFLOW / KylinFlow 两个独立仓库；
- 共享 Agent Profile，独立 Assignment；
- 凭据与写入权限按项目隔离；
- 统一状态汇总。

### v0.4 — 有边界自主研发

- Campaign：长期目标、跨项目；
- 权限继承：`Task Permissions ⊆ Campaign Permissions`；
- 预算：workers、model budget、GPU hours；
- Policy Engine 用确定性规则，LLM 只建议；
- 高风险动作人工审批。

### v0.5 — AI4S Domain Pack

- `manifest.yaml` 标准化；
- 第二个领域（分子动力学 / AI4S 推理 / 生物信息学）；
- 平台内核不改即可接入；
- 如果必须改 `platform/`，记录抽象缺陷。

---

## 9. Sprint 计划

### Sprint 0：审查与地基（1–2 天）

- 审查两个 zip 的全部脚本与文档；
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
- 跑 Spatial S1；
- 检查 scope/gate/report/commit/repro；
- 修复脚本问题。

**交付：** 单 Worker 能完成真实开发任务，输出可信但明确标注 `G3` 状态的报告。

### Sprint 2：双 Worker 与集成（3–5 天）

- Temporal T1（mock ODE，Forward Euler + SSPRK3）；
- 两个 worktree 并行；
- `integrate.sh` 合并；
- `GATE_MODE=integration` 跑 G0–G4；
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
- [ ] Quickstart 能让一个新人在 30 分钟内跑通单 worker。

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
| 过度建设平台 | v0.1 只 bash；TS 推迟到 v0.2 |

---

## 12. 给 Coding Agent 的第一轮指令

你是本项目的工程实现 Agent。第一轮只做 **Phase 0 + 单 Worker 垂直切片**，不要进入 Phase 2。

### 12.1 必须遵守

1. 先审查两个 zip 和当前仓库，不要假设脚本已正确运行；
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
9. 跑 Spatial S1；
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
| 平台语言 | bash | bash | **v0.1 bash；v0.2 TypeScript** |
| 任务引擎 | 无 | 文档提到未实现 | **v0.2** |
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
7. 能通过 Domain Pack 扩展到其他 AI4S 领域。

**实施策略：**

> CFD First → Verified Multi-Agent Development → Multi-Project Coordination → Bounded Autonomous Research → Open AI4S Platform.

**第一轮授权：**

> 只完成 Phase 0 和单 Worker 垂直切片。等真实 C++ 编译、数值验证、scope/gate/commit/repro 都跑通，再开 Spatial/Temporal 双 Worker。
