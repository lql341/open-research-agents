# Open Research Agents

在 Pi 之上的“有边界的多智能体研发系统”。平台本身是通用的；CFD 是第一个
domain，OneFLOW 是第一个 target。

当前状态：**v0.1 scaffold**。平台脚本是 Bash（兼容 macOS 自带 3.2）。
支持 macOS、Linux、WSL、Windows Git Bash；原生 PowerShell 不支持，详见
[`docs/platform-support.md`](docs/platform-support.md)。

## 分层

```text
platform/               通用内核：规则、preflight、scope、gate、worker 启动、集成、复现快照
domains/<domain>/       可复用的领域包：契约、scope、任务、验证算例、复现字段
targets/<target>/       单个仓库的覆盖层：真实路径、分支、命令、workstream
examples/validation/    可复制的验证用目标仓库（不是产品代码）
tests/fixtures/         平台 smoke test 用的小型 fixture
```

求解器代码不在本仓库。一个 domain + target 通过 `agentlab install` 装进目标仓库的
`.agentlab/`。平台内核不包含任何具体仓库的路径、分支或构建命令。

## 文档

| 文档 | 读者 | 内容 |
|---|---|---|
| [`docs/quickstart.md`](docs/quickstart.md) | 人 | 5 分钟跑通第一个 worker（English） |
| [`docs/quickstart.zh-CN.md`](docs/quickstart.zh-CN.md) | 人 | 5 分钟跑通第一个 worker（中文） |
| [`docs/workflow.md`](docs/workflow.md) | 人 | 用 agentlab 开发任意目标仓库（English） |
| [`docs/workflow.zh-CN.md`](docs/workflow.zh-CN.md) | 人 | 用 agentlab 开发任意目标仓库（中文） |
| [`platform/docs/target-pack-spec.md`](platform/docs/target-pack-spec.md) | 人 | target pack 的字段和安装语义 |
| [`platform/docs/domain-pack-spec.md`](platform/docs/domain-pack-spec.md) | 人 | domain pack 规范 |
| [`docs/validation.md`](docs/validation.md) | 人 | 验证实验：一次完整的代码改动闭环 |
| [`docs/platform-support.md`](docs/platform-support.md) | 人 | macOS / Linux / Windows 支持矩阵 |
| [`docs/install-manual.md`](docs/install-manual.md) | 人 | 手动安装，逐步验证，含排错和卸载 |
| [`docs/install-agent.md`](docs/install-agent.md) | coding agent | 可执行安装协议 |
| [`docs/usage.md`](docs/usage.md) | 人 | 日常用法：status / run / gate / integrate / pi |
| [`platform/docs/governance.md`](platform/docs/governance.md) | 人 | 授权模型与当前强制程度 |
| [`platform/docs/verification.md`](platform/docs/verification.md) | 人 | 门禁分层与退出码 |
| [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md) | 人 | 长周期路线 |

### 示例 target

| 文档 | 内容 |
|---|---|
| [`targets/oneflow/README.md`](targets/oneflow/README.md) | OneFLOW target pack 的安装与现状 |
| [`targets/oneflow/WORKFLOW.md`](targets/oneflow/WORKFLOW.md) | OneFLOW 完整工作流（English） |
| [`targets/oneflow/WORKFLOW.zh-CN.md`](targets/oneflow/WORKFLOW.zh-CN.md) | OneFLOW 完整工作流（中文） |

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

## 快速开始：任意目标仓库

```bash
# 1) 安装 domain + target 到目标仓库
agentlab install <domain> <target> <repo>

# 2) 检查并提交 .agentlab（scope_check 从 base ref 读取 scope）
cd <repo>
git status --short
git add .agentlab AGENTS.md
git commit -m "agentlab: add <target> pack"

# 3) 检查
agentlab doctor
agentlab status
```

第一次接触一个仓库时，先让 target 处于 `audit` 模式：worker 只写 reports/RFC/repro，
不改代码。审计完成、scope/contracts/verification 准备好之后，再切 `worker`。

完整流程见 [`docs/workflow.md`](docs/workflow.md) / [`docs/workflow.zh-CN.md`](docs/workflow.zh-CN.md)。

### 学习路径

```text
quickstart              第一次跑通（5 分钟，validation target）
  → workflow            通用流程：任务、scope、contracts、gate、集成
  → validation          完整验证实验，包括“错误实现会被抓住”
  → target-pack-spec    新增一个目标仓库需要提供什么
  → targets/oneflow     完整示例：OneFLOW
```

不需要一开始读完。先跑 quickstart，再按需要查 workflow。

第一个可用示例是 OneFLOW：

```bash
agentlab install cfd oneflow ~/OneFLOW
cd ~/OneFLOW
git add .agentlab AGENTS.md && git commit -m "agentlab: add OneFLOW target pack"
agentlab status
```

## 常用命令

```bash
agentlab install <domain> <target> <repo>   # 安装
agentlab update                             # 更新工具 + 重新应用 pack
agentlab uninstall                          # 卸载（保留分支与日志）
agentlab doctor                             # Pi、profile、guard、目标仓库
agentlab config                             # 解析后的配置
agentlab status [--json]                    # workstream / 报告 / gate / 待决 RFC
agentlab preflight <ws>
agentlab run <ws> [--detach] [extra...]
agentlab gate <ws> [--here]                 # 默认在 worker 工作树里跑
agentlab integrate <ws...>
agentlab integrate-audit <ws...>
agentlab pi <ws>                            # 在该 workstream 的工作树里交互式开 Pi
agentlab clean <ws...>                      # 删 worktree，保留分支和日志
```

完整说明见 [`docs/usage.md`](docs/usage.md)。

## 平台自测

```bash
bash tests/platform_smoke.sh      # 48 项：脚本、CLI、安装生命周期、session guard
bash scripts/validate-harness.sh  # 27 项：完整门禁闭环，不调模型
```

想验证“worker 能改代码且门禁不骗人”，按 [`docs/validation.md`](docs/validation.md) 走。

## 已知边界

- 隔离是“约定 + 事后检查”，不是沙箱：有 bash 权限的 worker 技术上能改仓库外的文件。
- `platform/` 在目标仓库之外，worker 不能通过改仓库来改 gate。
- 验证关卡的有效性完全取决于 target 注册的算例。
- v0.1 不支持隐式时间格式、MPI/GPU 性能优化、多项目、Web 面板。
- 详见 [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md)。

## License

MIT（如后续依赖检查要求，可调整）。
