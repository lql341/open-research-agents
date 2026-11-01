# Agent 安装协议

**读者：一个 coding agent（Pi、Codex、Claude Code 或同类）。人类只需要回答问题和批准。**

这份文档是可执行协议。按顺序做，每一步都要运行验证命令并贴出真实输出。
不允许跳步、不允许假设、不允许把没跑过的东西写成通过。

---

## 任务

把 `open-research-agents` 装到这台机器上，并接到一个目标仓库，让 `agentlab` 命令可用，
且**不修改人类日常使用的 Pi 配置**。

## 硬约束

1. **不改 `~/.pi/agent`。** 那是人类日常 Pi 的配置目录。worker 用独立的
   `PI_CODING_AGENT_DIR`。
2. **不改目标仓库的源码、构建脚本、测试架构。** 只允许创建/修改 `.agentlab/`
   和（仅在不存在时）仓库根的 `AGENTS.md` 指针。
3. **不执行 `pi /login`。** 登录必须由人类完成，你只负责准备目录并提示命令。
4. **不装全局软件**，除非人类明确同意。检查已有工具优先。
5. **不执行 `git push`、`git merge` 到受保护分支、`sbatch`/`srun`。**
6. **不提交目标仓库里不属于 `.agentlab/` 的改动。** 提交前用
   `git status --short` 逐行确认。
7. **一次只问一个人一个问题**，给出推荐项和理由，不要一次抛出清单。
8. 任何一步失败就停下，报告失败的命令和输出，不要绕过去继续。

## 非目标

- 不实现新功能，不改平台代码，不优化性能。
- 不调整目标仓库的测试架构或 CMake 结构。
- 不配置集群、容器、CI。

---

## 第 0 步：勘察（只读）

先收集事实，不要改任何东西：

```bash
pwd
ls
git rev-parse --show-toplevel 2>/dev/null || echo "not a git repo"
bash --version | head -1
git --version
python3 --version
cmake --version 2>/dev/null | head -1
c++ --version 2>/dev/null | head -1
pi --version 2>/dev/null || echo "pi: not found"
echo "PI_CODING_AGENT_DIR=${PI_CODING_AGENT_DIR:-unset}"
ls ~/.pi 2>/dev/null
ls ~/.config/agentlab 2>/dev/null || echo "no agentlab config"
```

输出一份简短的勘察结论：

```text
Found:
  platform repo   : <path or "not found">
  target repo     : <path or "not chosen">
  pi              : <version or missing>
  worker profile  : <exists / missing>
  config          : <exists / missing>
Blocking issues : <none | list>
```

如果 `pi` 缺失，停下来问人类要不要安装，不要自己装。

### 平台判定

根据 `uname -s` 的输出来决定：

| 输出 | 处理 |
|---|---|
| `Darwin` / `Linux` | 继续 |
| `MINGW*` / `MSYS*` / `CYGWIN*` | 继续，但在报告里注明 Windows via Git Bash |
| 其它 | 停下，报告“未验证的平台”，不要尝试改脚本适配 |

如果当前是 Windows 且没有 bash（说明你在 PowerShell 里），
**停下**并告诉人类：请在 Git Bash 或 WSL 里重跑本协议。

---

## 第 1 步：确认两个路径

问人类一个问题（用 `ask_user_question` 或直接提问）：

> `open-research-agents` 在哪里，目标仓库是哪个？

推荐项：平台仓库是当前 clone；目标仓库是已经存在的、有 `AGENTS.md` 的那个。

不要猜。如果人类只给了一个，另一个也要问。

---

## 第 2 步：准备 worker 的 Pi 配置目录

```bash
mkdir -p ~/.pi/agentlab
ls -A ~/.pi/agentlab
```

如果目录里有 `extensions/`、`skills/`、`mcp.json`，**停下来告诉人类**：
这些会加载进每个 worker，建议清空。

如果目录里没有 `auth.json` 或 `models.json`，把登录这一步交给人类：

> 请在终端运行下面这条命令并完成登录，完成后告诉我：
> `PI_CODING_AGENT_DIR=~/.pi/agentlab pi /login`

人类确认后验证：

```bash
PI_CODING_AGENT_DIR=~/.pi/agentlab pi --list-models | head -5
```

必须能看到模型列表。看不到就停。

---

## 第 3 步：写 CLI 配置

```bash
mkdir -p ~/.config/agentlab
[ -f ~/.config/agentlab/config.toml ] || \
  cp <platform-repo>/examples/agentlab.config.toml ~/.config/agentlab/config.toml
```

确认 `profile` 指向 `~/.pi/agentlab`：读文件，不要盲改。

```bash
grep -E '^(bin|profile|args)' ~/.config/agentlab/config.toml
```

如果人类之前指定过模型，就在 `[pi]` 段写 `args = "--model <id>"`。

---

## 第 4 步：装 CLI 到 PATH

```bash
mkdir -p ~/.local/bin
ln -sf <platform-repo>/bin/agentlab ~/.local/bin/agentlab
command -v agentlab
agentlab version
```

`command -v agentlab` 无输出时，说明 `~/.local/bin` 不在 PATH：
**问人类**要不要把这行加到 shell 配置，不要自己改：

```sh
export PATH="$HOME/.local/bin:$PATH"
```

---

## 第 5 步：自检

```bash
cd <platform-repo>
agentlab doctor
```

要求 `doctor: PASS`。有 `warn` 就逐条解释给人类，不要忽略。

同时跑平台自测：

```bash
bash tests/platform_smoke.sh
```

要求 `smoke: N passed, 0 failed`。失败就停，把失败项贴出来。

---

## 第 6 步：安装到目标仓库

先看目标仓库现状：

```bash
cd <target-repo>
git branch --show-current
git status --short
ls .agentlab 2>/dev/null && echo "already installed" || echo "not installed"
```

如果已经装过，**不要覆盖**。`install_target.sh` 不会覆盖已有文件，可以安全重跑：

```bash
agentlab install <domain> <target> <target-repo>
```

当前可用的组合：

| domain | target | 说明 |
|---|---|---|
| `cfd` | `oneflow` | OneFLOW：只读审计模式，两个 workstream `runtime-io` / `numerics` |

装完立刻检查，确认只增加了预期文件：

```bash
cd <target-repo>
git status --short
```

期望只有 `.agentlab/`（以及可能新建的 `AGENTS.md`）。**出现其它路径就停下报告。**

然后校对 base ref：

```bash
git branch --show-current
grep BASE_REF .agentlab/target.env
```

不一致就改成真实分支，并在报告里说明改了什么。

---

## 第 7 步：提交（需要人类同意）

先给人类看将要提交的内容：

```bash
cd <target-repo>
git status --short
git diff --stat
```

问一个问题：

> 是否提交 `.agentlab/` 到当前分支？

推荐：是。理由：`scope_check` 从 base ref 读取 scope，不提交就无法生效。

批准后：

```bash
git add .agentlab
[ -f AGENTS.md ] && git add AGENTS.md
git status --short          # 再次确认没有多余文件
git commit -m "agentlab: add collaboration target pack"
```

**不要 push。**

---

## 第 8 步：验证可用

```bash
cd <target-repo>
agentlab status
agentlab preflight <workstream>
```

`status` 要打印 workstream 表；`preflight` 在 `audit` 模式下应该 PASS。

不要在这一步跑 `agentlab run`——那会真的调用 Pi。除非人类明确要求。

---

## 第 8.5 步：维护（只在人类要求时执行）

| 人类要求 | 你执行 | 注意 |
|---|---|---|
| 更新 | `cd <platform-repo> && agentlab update` | 先确认平台仓库工作区干净；有 `.agentlab/AGENTS.md.new` 时**不要**自动覆盖，把 diff 给人看 |
| 更新某个目标仓库 | `cd <target-repo> && agentlab update` | 只补新增文件；提交前 `git status --short` 确认只有 `.agentlab/` |
| 卸载 | `cd <target-repo> && agentlab uninstall` | 需要人类确认；有工作树时会拒绝，先 `agentlab clean` |
| 清理工作树 | `agentlab clean <ws...>` | 只删 worktree，保留分支和日志 |

不要自己决定“顺便清理一下”。卸载会删掉报告和 RFC。

## 第 9 步：交付报告

严格按这个格式输出，不要加别的章节：

```text
Summary
  <一句话说明装了什么，装在哪>

Installed
  platform repo   : <path> @ <commit>
  target repo     : <path> @ <branch> <commit>
  domain/target   : cfd / oneflow
  mode            : audit
  workstreams     : runtime-io numerics
  cli             : ~/.local/bin/agentlab
  worker profile  : ~/.pi/agentlab

Verification (real output only)
  agentlab doctor        : <PASS/FAIL>
  tests/platform_smoke   : <N passed / M failed>
  agentlab status        : <ok/error>
  agentlab preflight     : <PASS/FAIL>

Files changed
  <列出 .agentlab/ 下新增的文件，或 "git show --stat" 摘要>

Not changed
  ~/.pi/agent            : untouched
  target source/build    : untouched

Known risks
  <例如：worker 有 bash 权限，能读工作树之外的路径；这不是沙箱>

Pending human decisions
  <例如：先跑哪个 workstream；是否切 worker 模式>

Next step
  <一条最具体的下一步命令>
```

---

## 失败时的行为

| 失败点 | 你要做的 |
|---|---|
| `pi` 不存在 | 停下，问人类是否安装；不要自己装 |
| 没有模型可用 | 停下，让人类完成 `pi /login` |
| `doctor` FAIL | 贴出失败项，按 `docs/install-manual.md` 第 9 节排查 |
| `smoke` 有失败 | 停下报告，不要修改平台代码去"修好"它 |
| `git status` 出现 `.agentlab/` 之外的文件 | 停下，`git checkout -- <file>` 恢复后报告 |
| base ref 不存在 | 改 `.agentlab/target.env` 并说明；不要改 git 分支 |
| 人类要求的操作超出这份协议 | 拒绝，并说明该操作属于人工决策 |

---

## 复述给人类的最小命令集

装完之后，人类日常只需要这五条：

```bash
agentlab doctor        # 环境是否正常
agentlab status        # 现在卡在谁身上
agentlab run <ws>                  # 派活
agentlab integrate <ws...>         # 集成
agentlab pi <ws>                   # 排查
```
