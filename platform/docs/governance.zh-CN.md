[English](governance.md) | **中文**

# 治理模型（v0.1 实施状态）

## 授权

- **Campaign mandate**：当前由人工维护的 `TASKS.md` 和模块 `scope/` 文件承担。
- **Task mandate**：`TASKS.md` 中的一项任务加上对应模块的 scope。
- agent 不能通过创建子任务扩大授权。
  v0.1 通过 prompt 和 scope 检查执行；v0.2 将迁移到任务引擎。

## 四档权限

| 档位 | 含义 | v0.1 强制方式 |
|---|---|---|
| Autonomous | 读取代码、在自己的工作树中工作、运行本地测试 | 不拦截 |
| Conditional | 小型重构、草稿提交 | Scope + gate |
| Approval | 契约/数据布局/验证变更、合并 main、对外 PR、增加预算 | RFC + 人工合并；**无程序强制** |
| Forbidden | 跨项目访问、绕过验证、凭据泄露 | `scope_check` 阻止路径越界；其他动作需要 guard 或 sandbox |

## 原则

- 确定性程序做策略判断；模型只提出建议。
- lead/reviewer agent 的批准**不等于**人类批准。
- 数值验证和代码审查是两道独立门禁。

## v0.1 未实现（v0.2+）

租约/心跳、幂等执行、契约版本号、预算计量、审批队列、事件总线、任务状态机。
