# 0x02 — Callus GUI 微信闲聊 Bot

**中文** | [English](README.en.md)

一套可自托管的**个人微信群闲聊 bot**：官方 **Linux 微信**跑在 Docker 里（Callus GUI 桥），闲聊脑跑在宿主机。

- **本仓（交付 SoT）**：[potatoblock-dev/0x02](https://github.com/potatoblock-dev/0x02)
- 产品定位：使用个人号为载体的bot接入微信方案。可以把bot的账号接入群聊。
- 个人号 GUI，不是官方 Bot API

---

## 相关仓库

| 仓库 | 角色 |
|------|------|
| [potatoblock-dev/0x02](https://github.com/potatoblock-dev/0x02) | **一体交付仓**：`bridge/` + `host/`，安装以本 README 为准 |
| [baitang-bt/Callus-Bridge](https://github.com/baitang-bt/Callus-Bridge) | GUI 桥上游开发仓（agent / AT-SPI / 容器） |
| [potatoblock-dev/WeJamBot](https://github.com/potatoblock-dev/WeJamBot) | 历史宿主 + 契约演进线（可与 host 对照） |
| [baitang-bt/0x01](https://github.com/baitang-bt/0x01) | QQ 官方机器人闲聊脑（同系列产品） |

日常推送 / 发版请以 **本仓 `0x02`** 为准；不要默认推到旧名 `WeJambBot_0x02`。

---

## 技术路线

```
┌─ Docker：callus-session（bridge/）──────────────┐
│  Xvfb + 官方 Linux 微信 + AT-SPI                 │
│  Callus agent：登录 / 会话 / 收发 / gRPC         │
│  卷 callus-data（登录态；勿随便 docker rm）       │
└────────────────────┬────────────────────────────┘
                     │ gRPC wejam.v1
                     │ 127.0.0.1:7701
┌────────────────────▼────────────────────────────┐
│  宿主：host/                                    │
│  wejam 客户端 · bot 脑 · 可选 PyQt 控制台         │
│  旁听 / 回复 / 印象·人设·策略（本机 host/data/）  │
└─────────────────────────────────────────────────┘
```

| 原则 | 说明 |
|------|------|
| 消息 SoT | **仅** Callus GUI（`:7701`）。可读个人微信群。 |
| 不用 OCR / 输入法读字 | 读 AT-SPI 节点树；发送用 Unicode keysym 注入。 |
| 图 / 语音 | 气泡像素裁剪 / 菜单「转文字」；宿主落盘后再交给多模态或文本 LLM。 |
| 契约 | gRPC `wejam.v1`（Callus 另有 ReadLatest / ReadContext / CaptureMessageMedia 等）。 |
| 登录态 | 存在 Docker 卷；**`docker start` / `restart` 复用**，不要无故 `rm` 容器。 |
| 隐私 | `host/data/`、`.env` **不入库**；本仓只带示例人设。 |

本仓**不包含** openclaw（ilink）默认路径：它不能稳定进个人微信群。

### 目录

```
bridge/     Callus GUI 桥：agent、docker、proto、wejam stub
host/       宿主大脑：bot、wejam 客户端、控制台、单测
examples/   示例人设（sample / template）
configs/    reply_policy 示例
```

---

## 环境要求（总览）

| 组件 | 要求 |
|------|------|
| Docker | Docker Desktop 或 Linux 引擎，能跑 **linux/amd64**（或 arm64）容器 |
| 宿主 Python | **≥ 3.11**（host 声明 ≥3.10；建议 3.11+） |
| LLM | OpenAI 兼容 HTTP API（如 DeepSeek）；识图需视觉模型 |
| 网络 | 构建镜像时需拉 Ubuntu base / 微信 deb |

---

## 部署方法

### A. macOS（推荐开发机）

1. 安装 [Docker Desktop](https://www.docker.com/products/docker-desktop/)，确认 `docker info` 正常。  
2. 克隆并起桥：

```bash
git clone https://github.com/potatoblock-dev/0x02.git
cd 0x02

cd bridge
# 若本地没有 wejam/ubuntu-base:24.04，先导入（x86_64 示例）：
# curl -O https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.5-base-amd64.tar.gz
# docker import ubuntu-base-24.04.5-base-amd64.tar.gz wejam/ubuntu-base:24.04

make build          # → callus/wechat:latest（或仓内约定镜像名）
make up             # callus-session → 127.0.0.1:7701
```

3. 登录：控制台「登录」页扫码，或：

```bash
cd bridge
python3 -m venv .venv && .venv/bin/pip install -e '.[dev]'
WEJAM_TARGET=127.0.0.1:7701 .venv/bin/python -m wejam.cli login --qr-out ../wejam-qr.png
```

等到 `login_phase=LOGGED_IN`。

4. 宿主：

```bash
cd ../host
python3 -m venv .venv
.venv/bin/pip install -e '.[bot]'
cp .env.example .env   # 填 LLM_API_KEY；WEJAM_TARGET=127.0.0.1:7701
```

5. 白名单 / 模式：编辑 `host/data/observe_chats.txt`、`allow_chats.txt`，`bot_mode.txt` 设为 `reply` 才会发言。  
6. 启动：

```bash
cd host
bash scripts/start-bot.sh
bash scripts/start-admin.sh          # 可选控制台
# macOS 桌面入口：bash scripts/install-desktop-app.sh
```

容器日常：

```bash
cd bridge
make status
make down            # 只 stop，保留登录卷
# 控制台「重启容器」= docker restart + 等 gRPC，不要 rm
```

---

### B. Linux（原生宿主机）

与 macOS 相同：**Docker 跑 bridge，本机 Python 跑 host**。

额外：

```bash
# 控制台 .desktop（需已建 host/.venv 并装好 PyQt6）
cd host
bash scripts/install-desktop-linux.sh

# 或打可拷贝的 Linux 包（非独立二进制，仍需本机 venv）
bash scripts/package-admin.sh
# → dist/linux/wejam-admin-desktop.tar.gz
```

建议：

- 用 `linux/amd64` 镜像跑微信容器（ARM 机器需确认微信 deb / 模拟层）。  
- 防火墙只暴露 `127.0.0.1:7701`，不要把 gRPC 绑到公网。  
- `host/data/`、`.env` 权限收紧（`chmod 700` / `600`）。

---

### C. Windows（经 WSL2 + Docker Desktop）

**没有「原生 Windows 微信 GUI 桥」**：微信客户端是 Linux 构建，必须跑在 **Linux 容器**里。

推荐路径：

1. Windows 11/10：安装 **WSL2**（Ubuntu）+ **Docker Desktop**，并开启 *Use the WSL 2 based engine*、把 Ubuntu 勾进 integration。  
2. **在 WSL2 里**克隆本仓，按上面 **Linux** 步骤 `make build` / `make up` / 装 `host/.venv`。  
3. 扫码：把 `wejam-qr.png` 拷到 Windows 资源管理器打开，或用控制台（WSL 内 PyQt 需 WSLg / 远程 X；更省事是 WSL 里 CLI 出码、Windows 看图）。  
4. 端口：容器 publish `127.0.0.1:7701` 时，WSL 与 Windows 本机通常都能访问该端口；host bot **优先放在 WSL 里**与 Docker 同网络命名空间，少踩路径/权限坑。

不推荐：

- 在纯 Windows 上跑 host、却指望容器路径 `/data/media` 直接当文件读（需 `docker cp` 或本仓已有的落盘逻辑）。  
- 用 Windows 版微信当 SoT（本产品不接入）。

---

## 安装清单（最短）

```bash
git clone https://github.com/potatoblock-dev/0x02.git && cd 0x02
make bridge-build && make bridge-up
# 扫码登录 …
make host-venv
# 编辑 host/.env、host/data/allow_chats.txt …
make host-bot
```

根目录 `Makefile` 只是快捷入口；细节以 `bridge/`、`host/` 内脚本为准。

---

## 运行时数据（勿提交）

| 路径 | 内容 |
|------|------|
| `host/data/bot.sqlite3` | 入站环缓冲等 |
| `host/data/impressions/` | 对用户印象 |
| `host/data/identity/` | person_id 别名 |
| `host/data/group_culture/` | 群氛围 |
| `host/data/media/` | 从容器拷出的气泡图 |
| `host/data/*.txt` | 白名单 / 旁听 / 模式 |
| `host/.env` | API Key |
| Docker 卷 `callus-data` | 微信登录与桥侧媒体 |

---

## 安全与风险（必读）

- 这是**个人号 GUI 自动化**，不是官方机器人接口；有封禁与设备异常风险。  
- 建议：人在时开、离开就停；白名单收敛；勿高频刷屏。  
- 不要把 `.env`、印象、聊天 sqlite、别名表推进公开仓库。

---

## 开发

```bash
cd bridge && make test
cd ../host && .venv/bin/python -m pytest tests/ -q
```

上游功能常先在 Callus-Bridge / WeJamBot 迭代，再合入本一体仓。**对外安装与部署说明以本 README 为准。**

## License / 归属

代码来自 Potatoblock / Callus / WeJam 相关工程整理；微信客户端版权归腾讯。使用前请遵守当地法律与微信软件许可。
