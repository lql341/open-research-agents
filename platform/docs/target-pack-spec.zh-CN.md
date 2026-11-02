[English](target-pack-spec.md) | **中文**

# Target Pack 规范

**Domain pack** 可跨仓库复用；**target pack** 对应一个具体仓库。
`agentlab install <domain> <target> <repo>` 将两者安装到 `<repo>/.agentlab/`；
重叠部分由 target 覆盖。

平台不得包含仓库特有路径、分支名、构建命令或测试命令；这些属于 target pack。

---

## 目录结构

```text
targets/<target>/
  target.env            必需：标识、基线分支、模式、workstream、命令
  AGENTS.target.md      必需：仓库特有规则
  TASKS.md              必需：人工维护的任务板
  scope/<ws>.txt        必需：每个 workstream 的写入边界
  verification/         必需：run_all.sh，退出码 0/1/2
  contracts/            可选：仓库特有接口/数据布局
  repro_fields.yaml     可选：仓库特有证据字段
  README.md             推荐：安装方式与特殊说明
```

`install_target.sh` 先复制 target，再复制 domain，最后复制平台模板。已存在的文件不会
被覆盖。`.agentlab/.pack` 记录 domain 和 target，供 `agentlab update` 重新应用。

---

## `target.env`

该文件由平台脚本 source。仅使用 `KEY=value` 和注释。

| Key | 必需 | 含义 |
|---|---|---|
| `TARGET` | 是 | 简短名称，用于 worker prompt 和状态输出 |
| `BASE_REF` | 是 | worker 的基线 ref，例如 `main`、`dev`、`upstream/hexin` |
| `AGENTLAB_MODE` | 是 | `audit` 或 `worker` |
| `MODULES` | 是 | workstream 名称，空格分隔 |
| `BUILD_CMD` | worker | 配置 + 构建命令 |
| `UNIT_CMD` | worker | 单元/契约测试命令 |
| `VERIFY_CMD` | worker | 数值/回归门禁；必须退出 `0/1/2` |
| `REQUIRE_CORE` | 否 | `1`（默认）检查是否存在 `core/` 风格的基础目录 |
| `REQUIRE_CONTRACTS` | 否 | `1`（默认）拒绝 contracts 中的 `TODO` / `[CONFIRM]` |
| `REQUIRE_UNIT` | 否 | `1`（默认）要求存在 C++ 单元测试源 |
| `UNIT_DIR` | 否 | `REQUIRE_UNIT` 检查的目录（默认 `tests/unit`） |
| `BUILD_FILE` | 否 | 构建入口文件（默认 `CMakeLists.txt`） |
| `GITHUB_REPOSITORY` | 否 | 将 GitHub 通知过滤到 `owner/name`；默认使用 `gh repo view` |

允许其他 key；平台会忽略未知 key。target 自己的验证脚本可以读取 target 特有变量。

注意力策略 key 是可选的，控制收件箱分类，取值为 `pending`、`review`、`fyi` 或 `ignore`：

```sh
ATTENTION_NEED_DECISION=pending
ATTENTION_RFC=pending
ATTENTION_BLOCKED=pending
ATTENTION_GATE_FAIL=pending
ATTENTION_GATE_UNVERIFIED=review
ATTENTION_REPORT_READY=review
ATTENTION_WORKER_FAILURE=pending
ATTENTION_TICKET=pending
ATTENTION_TICKET_REVIEW=review
ATTENTION_CANDIDATE=pending
```

示例：

```sh
TARGET=oneflow
BASE_REF=dev
AGENTLAB_MODE=audit
MODULES="runtime-io numerics"

BUILD_CMD="cmake -S . -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build -j2"
UNIT_CMD="ctest --test-dir build --output-on-failure"
VERIFY_CMD="bash .agentlab/verification/run_all.sh"

REQUIRE_CORE=0
UNIT_DIR=tests
```

---

## `AGENTS.target.md`

用于记录通用平台和 domain 规则无法覆盖的仓库特有规则：

- 哪个分支是基线，哪些分支受保护；
- 哪些目录由人所有；
- 仓库特有的证据要求；
- 修改代码前必须阅读的内容；
- 该仓库禁止的操作。

`install_target.sh` 会在 `# --- target: <name> ---` 标记下将该文件追加到
`.agentlab/AGENTS.md`。不要重复通用平台规则。

---

## `scope/<workstream>.txt`

每行一个路径前缀或 glob；`#` 开始注释。

```text
codes/main/src/SomeFile.cpp
tests/main/some_test.cpp
.agentlab/reports/<ws>.md
.agentlab/RFC/<ws>-*
.agentlab/repro/<ws>-*
```

规则：

- 在任务允许的范围内尽量收窄。整个目录通常过宽。
- scope 文件从 `BASE_REF` 读取，因此 worker 启动前必须提交。
- 未跟踪的 `.agentlab/repro/*` 由门禁生成，`scope_check` 会忽略；已提交的 repro
  文件按普通路径检查。

---

## `verification/run_all.sh`

这是实际门禁，不是形式检查。

```text
exit 0  PASS
exit 1  FAIL
exit 2  UNVERIFIED（未构建、未注册或尚未实现）
```

`worker` 门禁可以返回 `UNVERIFIED`；`integration` 会拒绝。占位验证的 target
无法完成集成。

使用仓库已有的算例和基线。不要为了通过门禁而创建第二套数值参考。

---

## `TASKS.md`

人工维护。worker 读取本 workstream 第一个 `todo`。任务需要：

- 一个具体交付物；
- 精确的 scope 路径；
- 可观察的验收条件；
- 不允许修改的内容。

不要在此放置开放式探索请求。探索使用原生 Pi。

---

## 安装与更新

```bash
agentlab install <domain> <target> <repo>
agentlab update                 # 重新应用记录的 pack，仅新增文件
agentlab uninstall              # 从仓库移除 .agentlab
```

`update` 不会覆盖已有的 `.agentlab/` 文件。如果生成的 `.agentlab/AGENTS.md`
会变化，它会写入 `AGENTS.md.new` 并打印 diff，不覆盖人工修改的文件。

---

## 新增 target

1. 复制 `targets/oneflow/` 作为起点。
2. 设置 `target.env` 中的 `TARGET`、`BASE_REF`、`MODULES` 和命令。
3. 为仓库重写 `AGENTS.target.md`、`TASKS.md` 和 `scope/*.txt`。
4. 添加或替换 `contracts/` 和 `verification/`。
5. 先在临时 clone 中安装并运行 `agentlab preflight`，再安装到真实仓库。

如果新增 target 需要修改 `platform/`，这属于平台变更。应记录为决策，不得将仓库特有逻辑
隐藏在通用脚本中。
