# 手动安装

面向人，一步步执行。每一步都给了验证命令：验证不过就不要继续。

> 如果你更愿意让 coding agent 帮你装，用 [`install-agent.md`](install-agent.md)。

---

> 平台支持（macOS / Linux / WSL / Windows Git Bash）见 [`platform-support.md`](platform-support.md)。
> Windows 原生 PowerShell 不受支持。

## 0. 前置条件

```bash
bash --version | head -1     # 需要 4.0+
git --version                # 需要 2.32+
python3 --version            # 需要 3.8+（status / repro 用）；Windows 上 python 也可以
pi --version                 # 需要 1.x
```

目标仓库本身还需要它自己的构建与测试工具；只有 `worker` 模式和
`integration` gate 才会用到：

```bash
cmake --version | head -1
c++ --version | head -1
```

**没有 `pi` 就先装**（只装一次，全局）：

```bash
# 官方安装脚本
curl -fsSL https://pi.dev/install | sh
# 或 npm
npm install -g @earendil-works/pi-coding-agent
```

验证：

```bash
pi --version
```

应该打印一个 1.x 版本号。

---

## 1. 取到仓库

```bash
cd ~/Downloads/agent/repo        # 或你放项目的位置
git clone <this-repo-url> open-research-agents
cd open-research-agents
export AGENTLAB="$PWD"
```

验证：

```bash
ls platform/scripts bin docs
```

应该看到 `install_target.sh`、`agentlab`、`usage.md` 等。

---

## 2. 建一个独立的 worker Pi 配置目录

**这一步是整个安装里最重要的隔离**。worker 不能和你日常的 Pi 共用配置，否则你个人的
extensions、skills、MCP 会全部加载进每一个 worker。

```bash
mkdir -p ~/.pi/agentlab
PI_CODING_AGENT_DIR=~/.pi/agentlab pi /login
```

登录方式按你用的 provider 选（OAuth、API key 都行）。如果你已经有可用的
`~/.pi/agent/auth.json` 和 `models.json`，也可以只复制这两个文件：

```bash
cp ~/.pi/agent/auth.json ~/.pi/agentlab/ 2>/dev/null || true
cp ~/.pi/agent/models.json ~/.pi/agentlab/ 2>/dev/null || true
```

验证：

```bash
PI_CODING_AGENT_DIR=~/.pi/agentlab pi --list-models | head -5
ls ~/.pi/agentlab
```

`~/.pi/agentlab` 里**不应该有** `extensions/`、`skills/`、`mcp.json`。
有的话说明复制多了，删掉。

---

## 3. 写 CLI 配置

```bash
mkdir -p ~/.config/agentlab
cp examples/agentlab.config.toml ~/.config/agentlab/config.toml
```

打开确认这两项：

```toml
[pi]
bin = "pi"
profile = "~/.pi/agentlab"
```

可选：给 worker 指定更便宜的模型。

```toml
[pi]
args = "--model your-provider/your-cheap-model"
```

验证：

```bash
./bin/agentlab config
```

应该看到：

```text
pi.profile  /Users/<you>/.pi/agentlab
```

---

## 4. 放进 PATH

```bash
mkdir -p ~/.local/bin
ln -sf "$AGENTLAB/bin/agentlab" ~/.local/bin/agentlab
```

确认 `~/.local/bin` 在 PATH 里：

```bash
echo "$PATH" | tr ':' '\n' | grep -q "$HOME/.local/bin" && echo "in PATH" || echo "NOT in PATH"
```

如果不在，把下面这行加到 `~/.zshrc` 或 `~/.bashrc`：

```sh
export PATH="$HOME/.local/bin:$PATH"
```

验证：

```bash
agentlab version
```

---

## 5. 自检

```bash
cd ~/Downloads/agent/repo/open-research-agents
agentlab doctor
```

期望输出：

```text
tools
  ok    git ...
  ok    python3 ...
pi
  ok    pi 1.x
  ok    worker profile /Users/<you>/.pi/agentlab
guard
  ok    platform/extensions/guard.ts
```

末尾应该是 `doctor: PASS`。

如果这里已经有 `warn`，先看 [`troubleshooting`](#9-排错) 再继续。

---

## 6. 接到目标仓库

### 6.1 现有仓库（推荐）

以 OneFLOW 为例，仓库路径按你的实际路径改：

```bash
agentlab install cfd oneflow ~/OneFLOW
```

它会：

- 创建 `<repo>/.agentlab/`（规则、contracts 模板、scope、任务板、验证占位）；
- 如果 `<repo>/AGENTS.md` 不存在，创建一个指针文件；
- **不会**修改任何求解器代码、构建脚本或测试。

然后**必须提交**，因为 `scope_check.sh` 从 base ref 读取 scope：

```bash
cd ~/OneFLOW
git status --short
git add .agentlab AGENTS.md
git commit -m "agentlab: add collaboration target pack"
```

验证：

```bash
agentlab status
```

应该打印 workstream 表。第一次运行报告都是 `missing`，这是正常的。

### 6.2 从模板开始

```bash
cp -R "$AGENTLAB/tests/fixtures/mini-target" ~/my-cfd
cd ~/my-cfd
git init -b main
git add . && git commit -m "init"

agentlab install cfd oneflow ~/my-cfd
git add -A && git commit -m "agentlab install"
```

`tests/fixtures/mini-target` 只是给平台自测用的最小工程，不是 CFD 产品代码。

### 6.3 检查 base ref

`.agentlab/target.env` 里的 `BASE_REF` 必须和目标仓库真实分支一致：

```bash
cd <repo>
git branch --show-current
grep BASE_REF .agentlab/target.env
```

不一致就改掉再提交。`agentlab status` 在 base ref 不存在时会给出 warning。

---

## 7. 第一次运行

先跑 `audit` 模式：worker 只能写报告，不能改代码。

```bash
cd <repo>
grep AGENTLAB_MODE .agentlab/target.env    # 应为 audit
agentlab preflight runtime-io
agentlab run runtime-io
agentlab status
```

`agentlab run` 会真的调用 Pi、消耗 token。只想验证流程的话用假 Pi：

```bash
cat > /tmp/fake-pi.sh <<'SH'
#!/bin/sh
mkdir -p .agentlab/reports
printf '# Report\nstatus: ready\ncommit: deadbee\n' > .agentlab/reports/runtime-io.md
git add .agentlab/reports/runtime-io.md && git commit -q -m "fake report"
SH
chmod +x /tmp/fake-pi.sh
PI_BIN=/tmp/fake-pi.sh agentlab run runtime-io
agentlab status
```

---

## 8. 切到代码模式

只有在你确认真实边界之后才做。以 OneFLOW 为例：

1. 读 `.agentlab/reports/*.md` 和 `.agentlab/RFC/*.md`；
2. 回答报告里 `need_decision` 的问题；
3. 用真实的、互不重叠的路径重写 `.agentlab/scope/<workstream>.txt`；
4. 填 `.agentlab/contracts/`（替换模板内容）；
5. 把 `.agentlab/target.env` 的 `AGENTLAB_MODE` 改成 `worker`；
6. 校验 `BUILD_CMD` / `UNIT_CMD` 在本机能跑通；
7. 注册至少一个真实验证算例，替换 `verification/run_all.sh` 的占位。

然后：

```bash
agentlab preflight <workstream>
agentlab run <workstream>
agentlab gate <workstream> --mode integration   # 合并前必须 PASS
```

### 门槛语义

| 门 | 要求 |
|---|---|
| `audit` | 只跑 scope |
| `worker` | scope + build + tests + verification（允许 `UNVERIFIED`） |
| `integration` | 同上，但 verification 必须 `PASS` |
| `release` | 全部必须 `PASS` |

`gate.sh` 退出码：`0` PASS，`1` FAIL，`2` UNVERIFIED。

---

## 8.5 先跑一次验证实验

在接真实仓库之前，建议先在临时目录跑一遍完整闭环：

```bash
bash scripts/validate-harness.sh          # 零成本，验证脚手架
```

然后按 [`validation.md`](validation.md) 的方式 B，让真实 worker 做同一个任务。
这一步通过后，再考虑切到你的真实仓库。

## 9. 排错

| 现象 | 原因 | 处理 |
|---|---|---|
| `agentlab: .agentlab/ not found` | 还没安装，或不在目标仓库里 | `agentlab install ...`，或在仓库根目录运行 |
| `base ref 'dev' not found` | `BASE_REF` 和真实分支不一致 | 改 `.agentlab/target.env` 后提交 |
| `working tree is dirty` | 目标仓库有未提交改动 | worker 从 base ref 建工作树，不会带上未提交内容；建议先提交或 stash |
| `worker made no commit` | worker 没提交就退出 | 看 `agentlab status` 和工作树里的日志；报告里应有原因 |
| `OUT OF SCOPE: xxx` | 改动超出 scope | 改 scope（人工），或让 worker 写 RFC |
| gate 显示 `UNVERIFIED` | 验证算例还是占位 | 注册真实算例；`integration` 会拒绝 |
| `ctest` 报 0 个测试却成功 | 目标仓库没有对应 label | 不要用 `-L unit` 之类不存在的 label，直接跑 `ctest` |
| worker 用错了模型 | `~/.pi/agentlab` 没有模型配置 | 在那个目录里重新 `pi /login`，或在 `config.toml` 设 `pi.args` |
| 你日常的 Pi 变了 | 不该发生 | 检查是否把 `PI_CODING_AGENT_DIR` 写进了 shell profile，删掉 |

---

## 9.5 更新

```bash
cd <platform-repo>
agentlab update
```

它会依次做三件事：

1. 对 `open-research-agents` 做 `git pull --ff-only`（工作区脏或加 `--no-pull` 时跳过）；
2. 用 `.agentlab/.pack` 里记录的 domain/target 重新应用 pack，**只补新增文件，不覆盖已有文件**；
3. 重新生成 `.agentlab/AGENTS.md`，若与你当前的文件不同，会写 `.agentlab/AGENTS.md.new`
   并打印 diff，**不覆盖你的修改**。

更新后：

```bash
cd <repo>
git status --short
agentlab status
```

有新增文件就提交：

```bash
git add .agentlab && git commit -m "agentlab: apply pack updates"
```

如果看到 `.agentlab/AGENTS.md.new`，人工合并后再：

```bash
mv .agentlab/AGENTS.md.new .agentlab/AGENTS.md
git add .agentlab/AGENTS.md && git commit -m "agentlab: merge rule updates"
```

## 10. 卸载

```bash
cd <repo>
agentlab uninstall
```

它会：

- 删掉 `.agentlab/`（报告、RFC、repro 一并删除，先备份）；
- 只有在根 `AGENTS.md` 是本工具生成的那份指针时才删它，你自己写的会保留；
- 如果还有 worker 工作树，会**拒绝执行**，提示你先 `agentlab clean <ws>`；加 `--force` 可强制。

它会保留：`agent/*` 分支、`<repo>-wt/logs`、以及 worker 的 Pi 配置。

再清理剩下的：

```bash
agentlab clean <workstream...>
rm -rf <repo>-wt

# 可选：删 CLI 和配置
rm -f ~/.local/bin/agentlab
rm -rf ~/.config/agentlab

# 可选：删 worker 的 Pi 配置（会丢 worker 的登录状态）
rm -rf ~/.pi/agentlab
```

你的 `~/.pi/agent` 全程没有被修改，不需要回滚。

---

## 附：安装会写哪些文件

| 路径 | 由谁创建 | 内容 |
|---|---|---|
| `<repo>/.agentlab/` | `agentlab install` | 规则、contracts、scope、任务板、验证占位、模板 |
| `<repo>/AGENTS.md` | `agentlab install`（仅当不存在） | 指向 `.agentlab/AGENTS.md` 的指针 |
| `<repo>-wt/<ws>/` | `agentlab run` | git worktree |
| `<repo>-wt/logs/` | `agentlab run` | 每次 worker 的日志 |
| `<repo>-wt/sessions/` | `agentlab run` | worker 的 Pi 会话 |
| `<repo>/.agentlab/reports/` | worker | 每个 workstream 一份报告 |
| `<repo>/.agentlab/RFC/` | worker | 待人工批准的提案 |
| `<repo>/.agentlab/repro/` | gate / worker | 门禁与运行证据 |
| `~/.config/agentlab/config.toml` | 你 | CLI 配置 |
| `~/.pi/agentlab/` | 你 | worker 的 Pi 配置 |

**不会写**：`~/.pi/agent`、目标仓库的源码/构建/测试、任何全局 Pi 设置。
