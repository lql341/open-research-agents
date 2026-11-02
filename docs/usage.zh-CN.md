[English](usage.md) | **中文**

# 日常用法

日常只需要 `agentlab` 一个命令。它使用**独立的 Pi agent 目录**运行 worker，
因此不会修改日常使用的 `pi` 配置。

## 1. Worker Pi 配置目录（一次性）

```bash
mkdir -p ~/.pi/agentlab
PI_CODING_AGENT_DIR=~/.pi/agentlab pi /login     # 或复制 auth.json / models.json
```

不会向全局环境导出变量。`agentlab` 只在启动的子进程中设置 `PI_CODING_AGENT_DIR`。

## 2. 配置（可选）

`~/.config/agentlab/config.toml`：

```toml
[pi]
bin = "pi"
profile = "~/.pi/agentlab"
args = "--model openai/gpt-5"

[runtime]
worktree_root = "~/agentlab-wt"
```

环境变量 `PI_BIN`、`PI_PROFILE`、`PI_ARGS`、`WT_ROOT` 优先于配置文件。

## 3. 日常流程

```bash
agentlab doctor                  # 检查 Pi、profile、guard、目标仓库
agentlab status                  # workstream、报告、门禁、待决事项

agentlab run <ws>                # 一个 worker：规则 -> 代码 -> 门禁 -> 提交 -> 报告
agentlab run <ws> --detach       # 在后台运行

agentlab status                  # 查看门禁和报告状态
agentlab gate <ws>               # 在 worker 工作树中运行门禁
agentlab integrate <ws...>       # 合并并运行集成门禁
```

`agentlab` 不会合并 base 分支。需要人工审查 integration 分支后手动合并。

## 3.1 注意力收件箱（v0.2）

收件箱只回答一个问题：**现在什么需要人处理？**

```bash
agentlab inbox                 # pending 和 review
agentlab inbox --all           # 包含 fyi
agentlab inbox --json          # 机器可读
agentlab decide <id> --ack     # 确认条目
agentlab decide <id> --approve # 批准 RFC
agentlab decide <id> --reject  # 拒绝 RFC
agentlab decide <id> --note "决定理由"
```

条目来源：

- `reports/*.md` 中 `status: need_decision` 或 `status: blocked`；
- `RFC/*.md` 中 `Status: proposed`；
- 每个 workstream 最新的 gate 为 `FAIL` 或 `UNVERIFIED`；
- 最新的 worker 日志中存在可识别的失败。

分类和策略在 `.agentlab/target.env` 中配置：

```sh
ATTENTION_NEED_DECISION=pending   # pending | review | fyi | ignore
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

`pending` 优先显示，其次是 `review`；`fyi` 默认隐藏，使用 `--all` 显示。
`agentlab decide` 将决定记录在 `.agentlab/decisions/`。决定只对做出决定时的内容生效；
报告、RFC、gate 或日志变化后会产生新条目。批准或拒绝 RFC 时，也会修改其 `Status` 字段。

## 3.2 Ticket 账本（v0.3）

Ticket 是一个 workstream 任务的授权记录，记录任务为何被允许以及依赖的策略快照。
它不是执行调度器；worker 仍使用 workstream 的 scope 和 gate。

```bash
agentlab ticket new <id> --title "..." --workstream <ws>
agentlab ticket list [--status STATUS] [--json]
agentlab ticket show <id> [--json]
agentlab ticket authorize <id>
agentlab ticket reject <id> --reason "..."
agentlab ticket set <id> running|review|blocked|ended --reason "..."
agentlab ticket revalidate <id>
agentlab ticket resume <id>
```

新 ticket 状态为 `proposed`，会以 `ticket:<id>` 出现在收件箱中。
`agentlab decide ticket:<id> --approve` 授权；`--reject` 拒绝。

Ticket 字段：

```text
id、title、workstream
source、sender、strength、rule
policy_version、scope_ref、scope_hash
status、reason、created_at、updated_at、history
```

`policy_version` 对 `AGENTS.md`、contracts、scope 文件、mode、target 和 base ref 做哈希。
其中任何内容变化后，`ticket revalidate` 会将 ticket 标为 `stale`。
stale ticket 必须重新授权后才能恢复。

生命周期：

```text
proposed -> authorized -> running -> review -> ended
                   \-> blocked -> running
proposed/authorized/running -> stale -> authorized
任何非终态 -> stopped | rejected
```

`agentlab decide ticket:<id> --ack` 会被拒绝：ticket 必须明确批准或拒绝。

## 3.3 GitHub Source（v0.4）

GitHub source 通过已认证的 `gh` CLI 轮询通知，生成的是**候选**，不是 ticket。
候选出现在收件箱中；必须由人批准后才会创建工作授权。

```bash
agentlab source github status
agentlab source github poll
agentlab source github poll --repo lql341/OneFLOW --limit 20
agentlab source github poll --input tests/fixtures/github-notifications.json --repo lql341/OneFLOW
```

`--input` 读取已保存的通知列表，不调用 GitHub；平台测试和离线审查使用该方式。

仓库默认取 `.agentlab/target.env` 中的 `GITHUB_REPOSITORY`，否则使用 `gh repo view`。
轮询是只读的：不会把通知标记为已读。

批准候选时必须指定 workstream：

```bash
agentlab inbox
agentlab decide candidate:<id> --approve --workstream <ws> --note "..."
```

`--approve` 会创建一个 `source=github` 的已授权 ticket；`--reject` 将候选标记为拒绝。
`--ack` 会被拒绝，因为候选必须明确批准或拒绝。

Source 状态保存在 `.agentlab/sources/github.json`；候选保存在
`.agentlab/candidates/`。

## 4. 长时间运行与中断

使用 `thinking=high` 的 worker 可能运行数分钟。不要占用终端：

```bash
agentlab run <ws> --detach
```

该命令打印 pid 和日志路径后立即返回。使用以下命令跟踪：

```bash
agentlab status          # 显示 "Running in background: <ws> pid NNNN"
tail -f <repo>-wt/logs/<ws>-detached-*.log
kill <pid>               # 或 kill -TERM <pid> 进行干净中断
```

前台 worker 被 Ctrl-C 中断时，`run_worker` 会在退出前打印工作树状态：

```text
run_worker: interrupted
run_worker: worktree state: head=abc1234 commits_since_main=1 uncommitted=0
run_worker: the work is committed; only the report or the final gate may be missing
```

detach 的 worker 退出时会删除 pid 文件，`status` 不再显示该进程。

## 5. 调试 worker

`agentlab status` 会列出最新的 worker 日志和最后一条可识别的错误。恢复的会话会保留历史中
记录的模型。如果该模型已不可用，每次请求都会在 provider 调用中失败：

```text
OpenAI API error (400): model_not_found
```

`agentlab run` 会在消耗一次请求前检测该情况：

```text
run_worker: the <ws> session is pinned to an unavailable model: <provider>/<model>
run_worker: fix it with: agentlab run <ws> --reset-session
```

处理方法：

```bash
agentlab run <ws> --reset-session     # 只清除该 workstream 的会话
agentlab pi <ws> --reset-session      # 同样清除，然后打开交互式 Pi
```

需要进入 worker 的会话和工作树继续处理：

```bash
agentlab pi <ws>
```

## 6. 在正确的工作树中运行门禁

`agentlab gate <ws>` 默认在 **worker 工作树**中运行。base 检出可能仍包含未实现的桩，
在该检出上运行门禁会得到误导性的 `UNVERIFIED`。

强制在当前检出中运行：

```bash
agentlab gate <ws> --here
```

`agentlab integrate` 会拒绝脏的 base 检出。`.agentlab/repro/`、`.agentlab/decisions/`、
`.agentlab/tickets/`、`.agentlab/candidates/`、`.agentlab/sources/` 下的未跟踪记录是唯一例外；
它们会随 integration 一起提交。

当唯一未提交的文件是生成的 repro 或 decision 记录时，`agentlab status` 显示
`WORKTREE=repro`。`clean` 表示没有未提交内容。

## 7. 会话管理

`--reset-session` 只清除该 workstream 的 Pi 会话：

```bash
agentlab run <ws> --reset-session
agentlab pi <ws> --reset-session
```

当会话绑定到不可用模型，或新任务需要干净上下文时使用。

## 8. 安装、更新、卸载

```bash
agentlab install <domain> <target> <repo>   # 安装 pack；不覆盖已有文件
agentlab update                             # 更新工具，然后重新应用当前 pack
agentlab update --no-pull                   # 只重新应用 pack
agentlab uninstall                          # 从当前仓库移除 .agentlab
agentlab uninstall --force --yes            # 工作树仍存在时也执行
```

`update` 执行三步：

1. 对工具仓库执行 `git pull --ff-only`（工作区脏或使用 `--no-pull` 时跳过）；
2. 使用 `.agentlab/.pack` 中记录的 domain 和 target 重新运行 `install`，
   只添加不存在的文件；
3. 重新生成 `.agentlab/AGENTS.md`；如果内容不同，写入
   `.agentlab/AGENTS.md.new` 并打印 diff，不覆盖本地修改。

`uninstall` 删除 `.agentlab/` 和生成的根 `AGENTS.md` 指针。它保留 `agent/*` 分支、
`<repo>-wt/logs` 和 worker 的 Pi 配置。

## 9. 边界

`agentlab` 不会：

- 修改 `~/.pi/agent`（日常 Pi 配置）；
- 安装扩展或写入全局 Pi 设置；
- 自行修改目标仓库的源码、构建或测试布局；
- push、合并受保护分支或提交集群作业。

## 10. 写入的文件

| 路径 | 内容 |
|---|---|
| `<repo>/.agentlab/reports/` | 每个 workstream 一份报告 |
| `<repo>/.agentlab/RFC/` | 待人工批准的提案 |
| `<repo>/.agentlab/repro/` | 门禁和运行证据 |
| `<repo>-wt/<ws>/` | worker 的 git 工作树 |
| `<repo>-wt/logs/` | 每次 worker 运行的日志 |
| `<repo>-wt/sessions/` | worker 的 Pi 会话 |
| `<repo>-wt/run/` | detach worker 的 pid 文件 |

## 11. 模式

`.agentlab/target.env` 中的 `AGENTLAB_MODE`：

| 模式 | worker 可写 | 门禁执行 |
|---|---|---|
| `audit` | 仅报告、RFC、repro | 仅 scope |
| `worker` | 其 scope 路径 | scope + 构建 + 测试 + 验证 |

`integration` 和 `release` 是门禁模式，不是 worker 模式。
