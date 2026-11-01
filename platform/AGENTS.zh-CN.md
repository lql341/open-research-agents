[English](AGENTS.md) | **中文**

# 平台规则（所有 agent、所有 domain）

1. 只修改 `.agentlab/scope/<module>.txt` 允许的文件。越界改动会使 `scope_check` 失败。
2. 不要修改 `.agentlab/contracts/`、`.agentlab/verification/`、平台脚本或验证基线/容差。
   需要变更时，写 `.agentlab/RFC/<date>-<module>-<topic>.md`，将报告状态设为
   `need_decision`，然后停止。
3. 完成条件是 `gate.sh <module>` 按当前模式通过，并在 `agent/<module>` 上**提交**。
4. 不得放宽容差、跳过测试、删除失败测试，或将未运行的测试标记为通过。
5. 如实报告：受阻时写 `blocked`，需要人工决定时写 `need_decision`。
6. 每次只提出一个具体问题，并给出建议和理由。
7. 不要猜测 contracts 中标记为 TODO 或 [CONFIRM] 的内容；写 `need_decision`。
8. 每个性能或精度结论都必须包含复现记录（参见报告模板）。
9. 不要创建当前任务之外的任务，也不要扩大自己的权限或预算。
10. 不要 push、合并受保护分支，或提交 HPC 作业（`sbatch`/`srun`）。
11. 不要重构目标的构建或测试架构。只按目标已有的模式新增测试。
    如果缺口需要构建变更，写 RFC 并停止。

## 工作流

阅读任务 -> 阅读契约 -> 编写测试 -> 实现 -> 门禁 -> 提交 -> 写报告 -> 停止。

只执行 `.agentlab/TASKS.md` 中本模块第一个 `todo` 任务。

## 提交

门禁通过后：

- 只 `git add` scope 内的文件；
- `git commit -m "<module>: <task> <short description>"`；
- **不要 push**；
- 在报告中记录 commit SHA。

## 报告状态

`ready` / `blocked` / `need_decision`

`ready` 表示“可以进入集成审查”，不表示“已完成数值验证”。
