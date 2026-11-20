# 0x02 — Callus GUI 微信闲聊 Bot

一套可自托管的**个人微信群闲聊 bot**：Linux 微信跑在 Docker 里（Callus GUI 桥），大脑跑在宿主机。

仓库：[potatoblock-dev/0x02](https://github.com/potatoblock-dev/0x02)

## 技术路线

```
┌─ Docker：callus-session（bridge/）──────────────┐
│  Xvfb + 官方 Linux 微信 + AT-SPI                 │
│  Callus agent：登录 / 会话 / 收发 / gRPC         │
│  状态卷 callus-data（登录态，勿随便 docker rm）   │
└────────────────────┬────────────────────────────┘
                     │ gRPC wejam.v1
                     │ 127.0.0.1:7701
┌────────────────────▼────────────────────────────┐
│  宿主：host/                                    │
│  wejam 客户端 · bot 脑 · 可选 PyQt 控制台         │
│  旁听 / 回复 / 印象·人设·策略（本机 data/）       │
└─────────────────────────────────────────────────┘
```

| 原则 | 说明 |
|------|------|
| 消息 SoT | **仅** Callus GUI（`:7701`）。可读个人微信群。 |
| 不用 OCR / 输入法 | 读 AT-SPI 节点树；发送用 Unicode keysym 注入。 |
| 契约 | gRPC `wejam.v1`（与历史 WeJam 线兼容；Callus 另有 ReadContext 等增量）。 |
| 登录态 | 存在 Docker 卷；**启动容器用 `docker start` 复用**，不要无故 `docker rm`。 |
| 隐私 | `host/data/`（印象、别名、知识库、日志、sqlite）**不入库**；本仓只带示例人设。 |

本仓**不包含** openclaw（ilink）路径：它不能进个人微信群，不作默认。

### 目录

```
bridge/     Callus GUI 桥：agent、docker、proto、wejam stub
host/       宿主大脑：bot、wejam 客户端、控制台、单测
examples/   示例人设（sample / template）
configs/    reply_policy 示例
```

## 环境要求

- macOS 或 Linux 宿主机，已装 **Docker Desktop**（或等效引擎）
- Python **≥ 3.11**（建议 3.11+；host 声明 ≥3.10）
- 能拉取 Ubuntu base / 微信 deb（构建镜像时）
- 一个 **LLM HTTP API**（OpenAI 兼容，例如 DeepSeek）

## 安装

### 1. 克隆

```bash
git clone https://github.com/potatoblock-dev/0x02.git
cd 0x02
```

### 2. 构建并启动 Callus 桥（`:7701`）

```bash
cd bridge

# 若本地没有 wejam/ubuntu-base:24.04，先导入 Ubuntu base（示例 x86_64）：
# curl -O https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.5-base-amd64.tar.gz
# docker import ubuntu-base-24.04.5-base-amd64.tar.gz wejam/ubuntu-base:24.04

make build          # docker build → callus/wechat:latest
make up             # 创建或恢复 callus-session，端口 127.0.0.1:7701
```

常用：

```bash
make status         # 或：WEJAM_TARGET=127.0.0.1:7701 python -m wejam.cli status
make down           # 只 stop，保留登录卷
# make destroy      # 删容器（卷仍在；下次 up 可能要重登）
```

### 3. 登录 Linux 微信

在控制台「登录」页扫码，或：

```bash
cd bridge
python3 -m venv .venv && .venv/bin/pip install -e '.[dev]'
WEJAM_TARGET=127.0.0.1:7701 .venv/bin/python -m wejam.cli login --qr-out ../wejam-qr.png
```

手机扫码确认。`login_phase` 需到 **LOGGED_IN** 再开宿主 bot。

### 4. 安装宿主大脑

```bash
cd ../host
python3 -m venv .venv
.venv/bin/pip install -e '.[bot]'
cp .env.example .env
# 编辑 .env：填 LLM_API_KEY 等；WEJAM_TARGET=127.0.0.1:7701
```

可选：拷贝示例人设

```bash
mkdir -p data/personas
cp -R ../examples/personas/sample data/personas/
# 按需改 personas.toml / 控制台「人设」页启用
```

回复策略示例：

```bash
cp ../configs/reply_policy.example.toml reply_policy.toml
# 或沿用仓内 host/reply_policy.toml 再按需改
```

### 5. 旁听 / 回复

1. 编辑 `data/observe_chats.txt`：每行一个**会话显示名**（须与微信列表完全一致，含空格）。
2. 要发言时：把群写入 `data/allow_chats.txt`，模式设为 `reply`（`data/bot_mode.txt` 或控制台切换）。
3. 频率：`reply_policy.toml` 里 `min_interval_seconds`（例如 `120` = 同会话 2 分钟最多 1 条）。

启动 bot：

```bash
cd host
bash scripts/start-bot.sh
# 或：.venv/bin/python -m bot
```

控制台（可选）：

```bash
bash scripts/start-admin.sh
# 或：.venv/bin/python -m bot.admin.desktop
```

## 运行时数据（勿提交）

| 路径 | 内容 |
|------|------|
| `host/data/bot.sqlite3` | 入站环缓冲等 |
| `host/data/impressions/` | 对用户印象 |
| `host/data/identity/` | person_id 别名 |
| `host/data/group_culture/` | 群氛围 |
| `host/data/*.txt` | 白名单 / 旁听 / 模式 |
| `host/.env` | API Key |

卷 `callus-data` 在 Docker 内，存微信登录与媒体缓存。

## 安全与风险（必读）

- 这是**个人号 GUI 自动化**，不是官方机器人接口；有封禁与设备异常风险。
- 建议：人在时开、离开就停；白名单收敛；勿高频刷屏。
- 不要把 `.env`、印象、聊天记录 sqlite、别名表推进公开仓库。

## 开发

```bash
cd bridge && make test
cd ../host && .venv/bin/python -m pytest tests/ -q
```

上游演进仍可能拆在 WeJamBot / Callus-Bridge 等仓；**本仓是面向「0x02」交付的一体快照**，以本 README 安装步骤为准。

## License / 归属

代码来自 Potatoblock / Callus / WeJam 相关工程整理；微信客户端版权归腾讯。使用前请遵守当地法律与微信软件许可。
