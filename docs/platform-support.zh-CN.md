[English](platform-support.md) | **中文**

# 平台支持

结论：**macOS 和 Linux 原生支持；Windows 需要 Git Bash 或 WSL；不支持原生 PowerShell。**

## 支持矩阵

| 平台 | 状态 | 说明 |
|---|---|---|
| macOS（Intel / Apple Silicon） | ✅ 支持 | 使用系统自带 `/bin/bash` 3.2，脚本已在该版本验证 |
| Ubuntu / Debian | ✅ 支持 | bash 5.x，无需额外处理 |
| 其它 Linux（RHEL / Rocky / Arch / Alpine+glibc） | ✅ 支持 | 只需 `bash`、`git`、`python`、`coreutils` |
| WSL1 / WSL2 | ✅ 支持 | 等同 Linux；文件放在 WSL 文件系统里更快 |
| Windows + Git Bash（MSYS2） | ⚠️ 可用 | 见下方限制 |
| Windows + PowerShell / cmd | ❌ 不支持 | 没有 bash；需要 Git Bash 或 WSL |
| FreeBSD / OpenBSD | ❔ 未验证 | 脚本不用 GNU 专属参数，理论上可行，未测试 |
| Nix / Guix | ⚠️ 可用 | 需要把 `bash`、`python3`、`git` 加入环境 |

## 依赖

| 依赖 | 用途 | 缺失后果 |
|---|---|---|
| `bash` ≥ 3.2 | 所有平台脚本 | 无法运行 |
| `git` ≥ 2.32 | worktree、scope、集成 | 无法运行 |
| `python3` 或 `python` | `agentlab status`、repro 记录 | `status` 报错；其余命令可用 |
| `coreutils`（`find`/`sed`/`tr`/`cmp`/`diff`/`mktemp`） | 脚本基础设施 | macOS 自带，Linux 自带，Git Bash 自带 |
| `pi` ≥ 1.x | worker | 只能 `install` / `status` / `uninstall` |
| 目标仓库自己的构建工具（`cmake`、`c++` 等） | `worker` / `integration` gate | `audit` 模式不受影响 |

`agentlab doctor` 会逐项检查并打印它实际看到的内容。

## macOS

```bash
agentlab doctor
```

期望：

```text
host
  ok    bash 3.2.57(1)-release (/bin/bash)
  ok    macOS 14.x
```

不需要 Homebrew bash。脚本刻意避开了 bash 4+ 的构造（`declare -A`、
`${var^^}`、`mapfile`），也没有用 GNU 专属参数（`sed -i` 无后缀、
`readlink -f`、`date -d`、`grep -P`）。

## Linux（Ubuntu / Debian）

```bash
sudo apt-get install -y git python3
```

其余依赖（`bash`、`coreutils`）都在基础系统里。

## Windows

### 方案 A：Git Bash（推荐，改动最小）

1. 安装 [Git for Windows](https://git-scm.com/download/win)，它带 Git Bash。
2. 在 Git Bash 里运行：

```bash
git clone <this-repo> open-research-agents
cd open-research-agents
./bin/agentlab doctor
```

`doctor` 会明确提示：

```text
warn  Windows via x86_64-pc-msys (Git Bash/MSYS); native PowerShell is not supported, use Git Bash or WSL
```

限制：

- 路径要在 Git Bash 的 POSIX 形式下用（`/c/Users/...`），不要写 `C:\...`；
- 目标仓库也必须在同一套路径体系下，否则 `git worktree` 会建到奇怪的位置；
- `agentlab cleanup` / `uninstall` 的 `rm -rf` 走 MSYS 层，慢但正确。

### 方案 B：WSL（推荐用于正式运行 worker）

```bash
wsl
sudo apt-get install -y git python3
git clone <this-repo> ~/open-research-agents
~/open-research-agents/bin/agentlab doctor
```

要点：

- 目标仓库放在 WSL 文件系统（`~/...`），不要放 `/mnt/c/...`，否则 git 和编译都慢；
- 在 WSL 里安装并登录 `pi`：
  `mkdir -p ~/.pi/agentlab && PI_CODING_AGENT_DIR=~/.pi/agentlab pi /login`
- Windows 侧的 OneFLOW 检出和 WSL 侧的检出是两个仓库；不要让两边同时改同一份文件。

### 原生 PowerShell 为什么不支持

`agentlab` 是 bash 脚本集合（worktree 管理、scope glob、gate 串联、`trap` 清理）。
在 PowerShell 里重写等于第二套实现，两边会漂移。需要 Windows 原生时，正确做法是：
**让 worker 在 WSL 或 Git Bash 里**，而不是移植脚本。

## Windows 上的 worker 命令拦截

Pi 在原生 Windows 上可以用 `powershell` 工具而不是 `bash`。`guard.ts` 已经同时挂在
`bash` 和 `powershell` 两个工具上，所以

```text
git push / git merge / gh pr merge / sbatch / srun
```

在两种环境下都会被拦。

## 已知的平台差异

| 项目 | macOS / Linux | Windows（Git Bash） |
|---|---|---|
| `agentlab pi` 打开交互式 Pi | 正常 | 正常，但终端能力取决于 Git Bash |
| 文件锁 | 无 | Windows 上 `rm -rf` 偶尔因文件占用失败，重试即可 |
| repro 记录的硬件字段 | 有 CPU 型号 | `wmic` 可能缺失，字段为空 |
| 集群作业 | 被 guard 拦截 | 同左 |

## 兼容性验证方式

```bash
# 全部脚本在 bash 3.2 下的语法检查
for f in bin/agentlab scripts/*.sh platform/scripts/*.sh; do /bin/bash -n "$f"; done

# 完整平台自测（不调用模型、不联网）
bash tests/platform_smoke.sh
```

当前：**33 项通过，0 失败**，macOS `/bin/bash` 3.2 与 bash 5.x 均验证过。

## 如果某个平台无法运行

1. 运行 `agentlab doctor`，把输出贴出来；
2. 运行 `bash tests/platform_smoke.sh`，看是哪一项失败；
3. 不要改脚本去“适配”单台机器——先把输出记录下来，这通常是缺少依赖而不是代码问题。
