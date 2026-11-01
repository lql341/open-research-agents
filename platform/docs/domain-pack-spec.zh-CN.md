[English](domain-pack-spec.md) | **中文**

# Domain Pack 规范

Domain pack 可跨仓库复用；**target pack** 对应一个具体仓库。仓库分层如下：

```text
platform/               通用规则、脚本、门禁、CLI
domains/<domain>/       可复用的领域规则
targets/<target>/       单个仓库：路径、分支、命令、scope
```

通过 `agentlab install <domain> <target> <repo>` 同时安装两者；重叠部分由 target 覆盖。
参见 [`target-pack-spec.zh-CN.md`](target-pack-spec.zh-CN.md)。

Domain pack 位于 `domains/<name>/`，必须提供：

| 文件/目录 | 用途 |
|---|---|
| `domain.env` | `DOMAIN`、`MODULES`、`BUILD_CMD`、`UNIT_CMD`、`VERIFY_CMD` |
| `AGENTS.domain.md` | 领域规则，安装时合并进 `.agentlab/AGENTS.md` |
| `contracts/` | 接口、数据布局、核心 API；TODO 项由人负责 |
| `scope/<ws>.txt` | 每个 workstream 的允许路径 |
| `TASKS.md` | 人工维护的任务板 |
| `verification/` | 数值算例和 `run_all.sh`；失败返回非零，未验证返回 2 |
| `repro_fields.yaml` | 领域特有的复现字段 |

## 规则

- 平台不得包含 target 特有的路径、分支、构建命令或测试命令；这些属于 target pack。
- 平台不得包含 CFD 特有逻辑。
- Domain pack 不应依赖特定求解器仓库布局；路径通过 `scope/` 配置。
- 如果第二个 domain 需要修改 `platform/`，应记录抽象缺陷后再修改。
- 验证算例和容差由人所有。agent 只能通过 RFC 新增算例。
