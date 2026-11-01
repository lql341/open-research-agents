# Open Research Agents

在 Pi 之上的“有边界的多智能体研发系统”。先服务 CFD，再扩展到 AI4S。

当前状态：**v0.1 scaffold**。平台脚本是 Bash；领域包是 Markdown + 脚本；`examples/cfd-mini` 是可编译的最小 CFD 目标仓库模板。

```text
platform/            通用内核：规则、preflight、scope、gate、worker 启动、集成、复现快照
domains/<domain>/    领域包：契约、scope、任务、验证算例、复现字段
examples/cfd-mini/   独立 git 仓库形态的最小 CFD 工程模板
```

求解器代码不在本仓库。领域包通过 `install_domain.sh` 装进目标仓库的 `.agentlab/`。

## 快速开始

```bash
cd open-research-agents
export AGENTLAB="$PWD"

# 1) 准备一个目标仓库（示例：把 cfd-mini 复制出去并初始化 git）
cp -R examples/cfd-mini /tmp/cfd-mini
cd /tmp/cfd-mini
git init -b main
git add .
git commit -m "init cfd-mini"

# 2) 安装 CFD 领域包到目标仓库
"$AGENTLAB/platform/scripts/install_domain.sh" cfd /tmp/cfd-mini

# 3) 编辑 .agentlab/domain.env 与 .agentlab/scope/*.txt（示例已填好）
# 4) 真实仓库需要填 .agentlab/contracts/data_layout.md 并确认 interfaces.md
# 5) 注册至少一个真实验证算例到 .agentlab/verification/
```

> 当前 `cfd-mini` 的 verification 是占位，gate 会返回 `UNVERIFIED`。这是故意的：**未做数值验证时不能报 PASS。**

## 单 Worker

```bash
cd /tmp/cfd-mini
"$AGENTLAB/platform/scripts/preflight.sh" spatial
"$AGENTLAB/platform/scripts/run_worker.sh" spatial
```

## 双 Worker 与集成

```bash
cd /tmp/cfd-mini
"$AGENTLAB/platform/scripts/run_worker.sh" spatial
"$AGENTLAB/platform/scripts/run_worker.sh" temporal
"$AGENTLAB/platform/scripts/integrate.sh"
```

集成 gate 使用 `GATE_MODE=integration`，要求 `G3 numerical = PASS`；没有真实验证算例时会失败。

## 已知边界

- 隔离是“约定 + 事后检查”，不是沙箱：有 bash 权限的 worker 技术上能改仓库外的文件。
- `platform/` 在目标仓库之外，worker 不能通过改仓库来改 gate。
- 验证关卡的有效性完全取决于注册的算例。
- v0.1 不支持隐式时间格式、MPI/GPU 性能优化、多项目、Web 面板。
- 详见 `IMPLEMENTATION_PLAN.md`。

## License

MIT（如后续依赖检查要求，可调整）。
