[English](README.md) | **中文**

# Open Research Agents

一个构建在 Pi 之上的有边界多智能体开发系统。平台本身是通用的；CFD 是第一个
domain，OneFLOW 是第一个完整示例。

状态：**v0.1 scaffold**。平台脚本使用 Bash，兼容 macOS 自带的 3.2 版本。
支持 macOS、Linux、WSL 和 Windows Git Bash；不支持原生 PowerShell。详见
[`docs/platform-support.zh-CN.md`](docs/platform-support.zh-CN.md)。

## 分层

```text
platform/               通用内核：规则、preflight、scope、gate、worker、集成、证据
domains/<domain>/       可复用的领域包：契约、scope、任务、验证、复现字段
targets/<target>/       单个仓库：真实路径、基线分支、命令、workstream
examples/validation/    可复制的验证用目标仓库（不是产品代码）
tests/fixtures/         平台 smoke test 使用的小型夹具
```

求解器代码不在本仓库中。domain 和 target 通过 `agentlab install` 安装到目标仓库的
`.agentlab/` 下。平台不包含任何具体仓库的路径、分支、构建命令或测试命令。

## 文档

英文是默认文档语言。每个文档页面顶部都有中文切换链接。worker 作为数据读取的运行
文件（`TASKS.md`、契约、`scope/`、模板、测试夹具）不做双语复制。

| 文档 | 读者 | 内容 |
|---|---|---|
| [`docs/README.zh-CN.md`](docs/README.zh-CN.md) | 所有人 | 文档索引与语言策略 |
| [`docs/quickstart.zh-CN.md`](docs/quickstart.zh-CN.md) | 人 | 五分钟完成第一次 worker 运行 |
| [`docs/workflow.zh-CN.md`](docs/workflow.zh-CN.md) | 人 | 任意目标仓库的完整流程 |
| [`docs/validation.zh-CN.md`](docs/validation.zh-CN.md) | 人 | 端到端验证实验 |
| [`docs/usage.zh-CN.md`](docs/usage.zh-CN.md) | 人 | 日常命令：status、run、gate、integrate、pi |
| [`docs/install-manual.zh-CN.md`](docs/install-manual.zh-CN.md) | 人 | 手动安装、验证、排错、卸载 |
| [`docs/install-agent.zh-CN.md`](docs/install-agent.zh-CN.md) | coding agent | 可执行安装协议 |
| [`docs/platform-support.zh-CN.md`](docs/platform-support.zh-CN.md) | 人 | macOS / Linux / Windows 支持矩阵 |
| [`platform/docs/target-pack-spec.zh-CN.md`](platform/docs/target-pack-spec.zh-CN.md) | 人 | target pack 字段与安装语义 |
| [`platform/docs/domain-pack-spec.zh-CN.md`](platform/docs/domain-pack-spec.zh-CN.md) | 人 | domain pack 规范 |
| [`platform/docs/governance.zh-CN.md`](platform/docs/governance.zh-CN.md) | 人 | 授权模型与当前强制程度 |
| [`platform/docs/verification.zh-CN.md`](platform/docs/verification.zh-CN.md) | 人 | 门禁分层与退出码 |
| [`IMPLEMENTATION_PLAN.zh-CN.md`](IMPLEMENTATION_PLAN.zh-CN.md) | 人 | 长期计划（规划文件） |

### 完整示例 target

| 文档 | 内容 |
|---|---|
| [`targets/oneflow/README.zh-CN.md`](targets/oneflow/README.zh-CN.md) | OneFLOW target pack 的安装与状态 |
| [`targets/oneflow/WORKFLOW.zh-CN.md`](targets/oneflow/WORKFLOW.zh-CN.md) | OneFLOW 的完整工作流 |

## 安装

```bash
cd open-research-agents
export AGENTLAB="$PWD"

# 独立的 worker Pi 配置目录；不修改日常使用的 ~/.pi/agent
mkdir -p ~/.pi/agentlab
PI_CODING_AGENT_DIR=~/.pi/agentlab pi /login

# 可选配置
mkdir -p ~/.config/agentlab
cp examples/agentlab.config.toml ~/.config/agentlab/config.toml

# 将 CLI 加入 PATH
ln -sf "$AGENTLAB/bin/agentlab" ~/.local/bin/agentlab

agentlab doctor
```

`agentlab` 只在启动的子进程中设置 `PI_CODING_AGENT_DIR`，不修改 shell 配置，
也不修改 `~/.pi/agent`。

## 任意目标仓库的首次运行

```bash
# 1. 将 domain 和 target 安装到目标仓库
agentlab install <domain> <target> <repo>

# 2. 检查并提交 .agentlab（scope_check 从 base ref 读取 scope）
cd <repo>
git status --short
git add .agentlab AGENTS.md
git commit -m "agentlab: add <target> pack"

# 3. 检查安装
agentlab doctor
agentlab status
```

如果对仓库尚不熟悉，先保持 `audit` 模式。该模式下 worker 只能写报告、RFC 和
repro 记录。等 scope、contracts 和真实验证算例准备好后，再切换到 `worker`。

完整流程见 [`docs/workflow.zh-CN.md`](docs/workflow.zh-CN.md)。

第一个可用 target 是 OneFLOW：

```bash
agentlab install cfd oneflow ~/OneFLOW
cd ~/OneFLOW
git add .agentlab AGENTS.md
git commit -m "agentlab: add OneFLOW target pack"
agentlab status
```

## 命令

```bash
agentlab install <domain> <target> <repo>   安装 pack
agentlab update                             更新工具并重新应用当前 pack
agentlab uninstall                          从当前仓库移除 .agentlab
agentlab doctor                             检查 Pi、profile、guard 和目标仓库
agentlab config                             显示解析后的配置
agentlab status [--json]                    workstream、报告、门禁、待决 RFC
agentlab preflight <ws>
agentlab run <ws> [--detach] [extra...]
agentlab gate <ws> [--here]                 默认在 worker 工作树中运行
agentlab integrate <ws...>
agentlab integrate-audit <ws...>
agentlab pi <ws>                            在该工作树中打开交互式 Pi
agentlab clean <ws...>                      删除工作树，保留分支和日志
```

详见 [`docs/usage.zh-CN.md`](docs/usage.zh-CN.md)。

## 平台测试

```bash
bash tests/platform_smoke.sh        # 48 项：脚本、CLI、安装生命周期、session guard
bash scripts/validate-harness.sh    # 27 项：完整门禁闭环，不调用模型
```

如需验证“worker 能修改代码，同时门禁能拒绝错误实现”，请按
[`docs/validation.zh-CN.md`](docs/validation.zh-CN.md) 执行。

## 已知边界

- 隔离由约定和事后检查实现，不是沙箱。拥有 shell 权限的 worker 仍可读取工作树之外的路径。
- `platform/` 位于目标仓库之外；worker 无法通过修改仓库来修改门禁。
- 验证门禁的有效性完全取决于 target 注册的算例。
- v0.1 不实现隐式时间积分、MPI/GPU 性能优化、多项目协调或 Web 面板。
- 长期计划见 [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md)。

## License

MIT。依赖审查后可能调整。
