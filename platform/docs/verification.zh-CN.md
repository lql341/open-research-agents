[English](verification.md) | **中文**

# 验证门禁

| 门 | 内容 | 结果 |
|---|---|---|
| G0 | Scope 检查：新增/删除/重命名/未跟踪文件 | PASS / FAIL |
| G1 | 构建与静态检查 | PASS / FAIL |
| G2 | 单元测试 | PASS / FAIL |
| G3 | 数值验证（MMS/ODE/守恒） | PASS / FAIL / **UNVERIFIED** |
| G4 | 集成回归 | PASS / FAIL |
| G5 | 性能基准 | PASS / FAIL / N/A |

规则：

- 未注册验证算例时必须为 `UNVERIFIED`，不能为 `PASS`。
- worker gate 可以返回 `UNVERIFIED`；报告必须明确说明。
- integration gate（`GATE_MODE=integration`）要求 `G3=PASS`。
- 只有 `G0–G4` 全部 PASS 才允许进入人工审批。
- 容差和基线由人所有；agent 不得放宽容差。
- 每个精度/性能结论都必须有 `.agentlab/repro/*.json` 记录。

`gate.sh` 退出码：`0` PASS，`1` FAIL，`2` UNVERIFIED。
