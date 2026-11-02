[English](README.md) | **中文**

# 文档

agentlab 是一个构建在 Pi 之上的有边界多智能体开发系统。平台本身是通用的；
CFD 是第一个 domain，OneFLOW 是第一个完整示例。

英文是默认文档语言。每个页面顶部都有中文切换链接。英文页面是权威版本：
两者不一致时，以英文描述当前行为。

worker 作为数据读取的运行文件不做双语复制：

- `.agentlab/TASKS.md`
- `.agentlab/contracts/`
- `.agentlab/scope/`
- `.agentlab/templates/`
- 测试夹具和生成的 `.agentlab/` 包

这些文件属于目标仓库，并跟随目标仓库的语言。它们是配置和证据，不是文档页面。

## 从这里开始

| 文档 | 用途 |
|---|---|
| [Living TODO](living-todo.zh-CN.md) | 短期交接：现在、下一步、待决问题 |
| [快速开始](quickstart.zh-CN.md) | 五分钟完成第一次 worker 运行，使用内置 validation target |
| [注意力演示](../scripts/demo-attention.sh) | 一条命令：candidate -> inbox -> 批准 -> authorized ticket；不调用模型、不联网 |
| [工作流](workflow.zh-CN.md) | 任意目标仓库的完整流程：审计、任务、scope、门禁、集成 |
| [验证](validation.zh-CN.md) | 端到端验证实验，包括反例 |

## 运行 agentlab

| 文档 | 用途 |
|---|---|
| [日常用法](usage.zh-CN.md) | status、inbox、decide、ticket、source、run、gate、integrate、pi、clean |
| [手动安装](install-manual.zh-CN.md) | 分步安装、验证、排错、卸载 |
| [Agent 安装协议](install-agent.zh-CN.md) | 供 coding agent 执行的可执行协议 |
| [平台支持](platform-support.zh-CN.md) | macOS、Linux、WSL、Windows Git Bash；不支持原生 PowerShell |

## 参考

| 文档 | 用途 |
|---|---|
| [Target pack 规范](../platform/docs/target-pack-spec.zh-CN.md) | 单个仓库的文件、字段、安装与更新语义 |
| [Domain pack 规范](../platform/docs/domain-pack-spec.zh-CN.md) | 可复用领域规则与验证 |
| [治理模型](../platform/docs/governance.zh-CN.md) | 授权模型与当前强制程度 |
| [验证门禁](../platform/docs/verification.zh-CN.md) | 门禁分层与退出码 |

## 完整示例

| 文档 | 用途 |
|---|---|
| [OneFLOW target](../targets/oneflow/README.zh-CN.md) | 第一个 target 的安装、状态与决策 |
| [OneFLOW 工作流](../targets/oneflow/WORKFLOW.zh-CN.md) | OneFLOW 的具体命令与决策 |

## 语言策略

- 英文是默认且权威的语言。
- 每个文档页面都有 `.zh-CN.md` 对应版本，并在顶部提供语言切换。
- 代码、配置、任务、契约、scope、模板和测试夹具不做翻译。它们由 worker 读取，
  必须保持无歧义。
- `IMPLEMENTATION_PLAN.md` 是持续更新的路线图；v0.1 部分记录初始实施。当前行为以本目录和
  目标指南为准。
