# Open Research Agents

在 Pi 之上的“有边界的多智能体研发系统”。先服务 CFD，再扩展到 AI4S。

当前状态：**v0.1 scaffold**。平台脚本是 Bash（兼容 macOS 自带 3.2）。
支持 macOS、Linux、WSL、Windows Git Bash；原生 PowerShell 不支持，详见
[`docs/platform-support.md`](docs/platform-support.md)。
真实目标仓库是 **OneFLOW**（`targets/oneflow/`）；`tests/fixtures/mini-target` 只用于平台 smoke test，不是 CFD 产品代码。

```text
platform/            通用内核：规则、preflight、scope、gate、worker 启动、集成、复现快照
domains/<domain>/    领域包：契约、scope、任务、验证算例、复现字段
targets/oneflow/     OneFLOW 目标覆盖层：真实路径、分支、命令、只读审计任务
tests/fixtures/      平台 smoke test 用的小型 fixture（不是 CFD 产品代码）
```

求解器代码不在本仓库。领域包通过 `agentlab install` 装进目标仓库的 `.agentlab/`。

## 文档

| 文档 | 读者 | 内容 |
|---|---|---|
| [`docs/validation.md`](docs/validation.md) | 人 | 验证实验：一次完整的代码改动闭环 |
| [`docs/platform-support.md`](docs/platform-support.md) | 人 | macOS / Linux / Windows 支持矩阵与已知限制 |
| [`docs/install-manual.md`](docs/install-manual.md) | 人 | 手动安装，逐步验证，含排错和卸载 |
| [`docs/install-agent.md`](docs/install-agent.md) | coding agent | 可执行安装协议，人类只回答问题 |
| [`docs/usage.md`](docs/usage.md) | 人 | 日常用法：status / run / gate / integrate / pi |
| [`platform/docs/governance.md`](platform/docs/governance.md) | 人 | 授权模型与当前强制程度 |
| [`platform/docs/verification.md`](platform/docs/verification.md) | 人 | 门禁分层与退出码 |
| [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md) | 人 | 长周期路线 |

## 安装

```bash
cd open-research-agents
export AGENTLAB="$PWD"

# 一个独立的 worker Pi 配置目录（不影响你日常的 pi）
mkdir -p ~/.pi/agentlab
PI_CODING_AGENT_DIR=~/.pi/agentlab pi /login

# 可选：写配置
mkdir -p ~/.config/agentlab
cp examples/agentlab.config.toml ~/.config/agentlab/config.toml

# 放到 PATH
ln -sf "$AGENTLAB/bin/agentlab" ~/.local/bin/agentlab

agentlab doctor
```

`agentlab` 只在自己启动的子进程里设置 `PI_CODING_AGENT_DIR`，你的 `~/.pi/agent` 不受影响。

## 快速开始：OneFLOW

OneFLOW 的模块边界不像 starter 的 `spatial/temporal` 那么干净。v0.1 先开两个**只读审计 worker**，让人确认边界和 scope 后再切到代码模式。

```bash
# 1) 安装 domain + OneFLOW target 到 OneFLOW 的 .agentlab/
agentlab install cfd oneflow /Users/luql/Downloads/agent/repo/OneFLOW

# 2) 检查并提交 .agentlab（scope_check 从 base ref 读取 scope）
cd /Users/luql/Downloads/agent/repo/OneFLOW
git status --short
git add .agentlab
git commit -m "agentlab: add OneFLOW target pack"

# 3) 只读审计
agentlab doctor
agentlab status
agentlab run runtime-io
agentlab run numerics
agentlab status
```

审计报告在 `.agentlab/reports/runtime-io.md` 和 `.agentlab/reports/numerics.md`。
审计阶段不编译、不跑测试、不改代码，只写报告/RFC/repro。

审计分支用轻量合并（只允许 reports/RFC/repro）：

```bash
cd /Users/luql/Downloads/agent/repo/OneFLOW
agentlab integrate-audit runtime-io numerics
# 人工 review 后：
git checkout dev && git merge --no-ff audit-integration
```

### 审计之后

1. 读两份报告，确认两个不重叠的代码 workstream；
2. 填 OneFLOW 专用 contracts；
3. 把 `.agentlab/target.env` 的 `AGENTLAB_MODE=audit` 改成 `worker`；
4. 校验 `BUILD_CMD` / `UNIT_CMD`；
5. 注册真实验证算例后，才能跑 integration。

### 常用命令

```bash
agentlab install cfd oneflow <repo>   # 安装
agentlab update                       # 更新工具 + 重新应用 pack
agentlab uninstall                    # 卸载（保留分支与日志）
agentlab doctor                 # Pi、profile、guard、目标仓库
agentlab config                 # 解析后的配置
agentlab status [--json]        # workstream / 报告 / gate / 待决 RFC
agentlab preflight <ws>
agentlab run <ws> [--detach] [extra...]
agentlab gate [ws] --mode integration
agentlab integrate <ws...>
agentlab pi <ws>                # 在该 workstream 的工作树里交互式开 Pi
agentlab clean <ws...>          # 删 worktree，保留分支和日志
```

完整说明见 `docs/usage.md`。

### 平台自测

```bash
bash tests/platform_smoke.sh      # 33 项：脚本、CLI、安装生命周期
bash scripts/validate-harness.sh  # 16 项：完整门禁闭环，不调模型
```

想验证"worker 能改代码且门禁不骗人"，按 [`docs/validation.md`](docs/validation.md) 走。

## 首次审计（2026-11-01）

已在 OneFLOW 上完成两个只读审计，报告已合入 `dev`：

| Workstream | 交付 | 关键发现 |
|---|---|---|
| `runtime-io` | `.agentlab/reports/runtime-io.md`、`.agentlab/RFC/runtime-io-2026-11-01-shared-case-runtime-target.md` | `io_paths.txt` 在多 rank 下无写者过滤；`TeardownCase` 无测试；测试源清单重复导致构建事故 |
| `numerics` | `.agentlab/reports/numerics.md`、`.agentlab/RFC/numerics-2026-11-01-boundary-contracts.md` | `HybridRoe()` 空实现导致静默零通量；`linearTwoStepMethods` 越界退化；`SolverState::Converge()` 恒真；无数值循环被实例化测试 |

下一步是人工回答两份报告里的 `need_decision` 问题，确认代码 workstream 和 contracts，然后把 `.agentlab/target.env` 的 `AGENTLAB_MODE` 改为 `worker`。

## 已知边界

- 隔离是“约定 + 事后检查”，不是沙箱：有 bash 权限的 worker 技术上能改仓库外的文件。
- `platform/` 在目标仓库之外，worker 不能通过改仓库来改 gate。
- 验证关卡的有效性完全取决于注册的算例。
- v0.1 不支持隐式时间格式、MPI/GPU 性能优化、多项目、Web 面板。
- 详见 `IMPLEMENTATION_PLAN.md`。

## License

MIT（如后续依赖检查要求，可调整）。
