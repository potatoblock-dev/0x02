# 0x02 — Callus GUI WeChat Chat Bot

[中文](README.md) | **English**

A self-hostable **personal WeChat group chat bot**: official **Linux WeChat** runs in Docker (Callus GUI bridge); the chat brain runs on the host.

- **This repo (delivery SoT):** [potatoblock-dev/0x02](https://github.com/potatoblock-dev/0x02)
- Product role: WeChat counterpart of the 0x01 text chat brain (personal account GUI — **not** the official Bot API)

---

## Related repositories

| Repo | Role |
|------|------|
| [potatoblock-dev/0x02](https://github.com/potatoblock-dev/0x02) | **Monorepo delivery:** `bridge/` + `host/`; install from this README |
| [baitang-bt/Callus-Bridge](https://github.com/baitang-bt/Callus-Bridge) | Upstream GUI bridge (agent / AT-SPI / container) |
| [potatoblock-dev/WeJamBot](https://github.com/potatoblock-dev/WeJamBot) | Historical host + contract evolution (compare with `host/`) |
| [baitang-bt/0x01](https://github.com/baitang-bt/0x01) | QQ official-bot chat brain (same product family) |

Day-to-day pushes and releases should target **this `0x02` repo**, not the legacy name `WeJambBot_0x02`.

---

## Architecture

```
┌─ Docker: callus-session (bridge/) ──────────────┐
│  Xvfb + official Linux WeChat + AT-SPI            │
│  Callus agent: login / sessions / send-recv / gRPC │
│  Volume callus-data (login state; do not casually docker rm) │
└────────────────────┬────────────────────────────┘
                     │ gRPC wejam.v1
                     │ 127.0.0.1:7701
┌────────────────────▼────────────────────────────┐
│  Host: host/                                    │
│  wejam client · bot brain · optional PyQt console │
│  observe / reply / impressions · personas · policy (host/data/) │
└─────────────────────────────────────────────────┘
```

| Principle | Detail |
|-----------|--------|
| Message SoT | **Only** Callus GUI (`:7701`). Can read personal WeChat groups. |
| No OCR / IME for text | Read the AT-SPI tree; send via Unicode keysym injection. |
| Image / voice | Bubble pixel crop / WeChat “convert to text”; host materializes files for multimodal or text LLM. |
| Contract | gRPC `wejam.v1` (also ReadLatest / ReadContext / CaptureMessageMedia, etc.). |
| Login state | Lives in a Docker volume; reuse with **`docker start` / `restart`** — do not `rm` the container without reason. |
| Privacy | `host/data/` and `.env` are **not** committed; this repo ships example personas only. |

This repo does **not** ship openclaw (ilink) as the default path: it cannot reliably enter personal WeChat groups.

### Layout

```
bridge/     Callus GUI bridge: agent, docker, proto, wejam stub
host/       Host brain: bot, wejam client, console, unit tests
examples/   Example personas (sample / template)
configs/    reply_policy examples
```

---

## Requirements

| Component | Requirement |
|-----------|-------------|
| Docker | Docker Desktop or a Linux engine that can run **linux/amd64** (or arm64) containers |
| Host Python | **≥ 3.11** (host declares ≥3.10; 3.11+ recommended) |
| LLM | OpenAI-compatible HTTP API (e.g. DeepSeek); vision model required for images |
| Network | Image build needs Ubuntu base / WeChat deb downloads |

---

## Deploy

### A. macOS (recommended for development)

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) and confirm `docker info` works.  
2. Clone and start the bridge:

```bash
git clone https://github.com/potatoblock-dev/0x02.git
cd 0x02

cd bridge
# If wejam/ubuntu-base:24.04 is missing locally, import it (x86_64 example):
# curl -O https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.5-base-amd64.tar.gz
# docker import ubuntu-base-24.04.5-base-amd64.tar.gz wejam/ubuntu-base:24.04

make build          # → callus/wechat:latest (or the image name defined in-repo)
make up             # callus-session → 127.0.0.1:7701
```

3. Log in via the console Login page, or:

```bash
cd bridge
python3 -m venv .venv && .venv/bin/pip install -e '.[dev]'
WEJAM_TARGET=127.0.0.1:7701 .venv/bin/python -m wejam.cli login --qr-out ../wejam-qr.png
```

Wait until `login_phase=LOGGED_IN`.

4. Host:

```bash
cd ../host
python3 -m venv .venv
.venv/bin/pip install -e '.[bot]'
cp .env.example .env   # set LLM_API_KEY; WEJAM_TARGET=127.0.0.1:7701
```

5. Allowlists / mode: edit `host/data/observe_chats.txt`, `allow_chats.txt`; set `bot_mode.txt` to `reply` before the bot speaks.  
6. Start:

```bash
cd host
bash scripts/start-bot.sh
bash scripts/start-admin.sh          # optional console
# macOS desktop entry: bash scripts/install-desktop-app.sh
```

Day-to-day container ops:

```bash
cd bridge
make status
make down            # stop only; keep the login volume
# Console “restart container” = docker restart + wait for gRPC; do not rm
```

---

### B. Linux (native host)

Same as macOS: **Docker runs the bridge; host Python runs on the machine.**

Extras:

```bash
# Console .desktop (requires host/.venv with PyQt6)
cd host
bash scripts/install-desktop-linux.sh

# Or package a copyable Linux bundle (not a standalone binary; still needs the local venv)
bash scripts/package-admin.sh
# → dist/linux/wejam-admin-desktop.tar.gz
```

Recommendations:

- Prefer `linux/amd64` WeChat images (on ARM, verify the WeChat deb / emulation layer).  
- Expose `127.0.0.1:7701` only — do not bind gRPC to the public internet.  
- Tighten permissions on `host/data/` and `.env` (`chmod 700` / `600`).

---

### C. Windows (via WSL2 + Docker Desktop)

There is **no native Windows WeChat GUI bridge**: the client is a Linux build and must run in a **Linux container**.

Recommended path:

1. On Windows 11/10: install **WSL2** (Ubuntu) + **Docker Desktop**, enable *Use the WSL 2 based engine*, and enable Ubuntu under integration.  
2. Clone this repo **inside WSL2** and follow the **Linux** steps (`make build` / `make up` / `host/.venv`).  
3. QR login: copy `wejam-qr.png` to Windows Explorer, or use the console (PyQt in WSL needs WSLg / remote X; easiest is CLI QR in WSL + view the image on Windows).  
4. Ports: with `127.0.0.1:7701` published, WSL and Windows can usually both reach it; keep the host bot **in WSL** next to Docker to avoid path/permission issues.

Not recommended:

- Running the host on bare Windows while expecting container paths like `/data/media` to be readable as local files (use `docker cp` or the in-repo materialize logic).  
- Using Windows WeChat as the message SoT (unsupported).

---

## Short install checklist

```bash
git clone https://github.com/potatoblock-dev/0x02.git && cd 0x02
make bridge-build && make bridge-up
# Scan QR to log in …
make host-venv
# Edit host/.env, host/data/allow_chats.txt …
make host-bot
```

The root `Makefile` is a thin shortcut; prefer scripts under `bridge/` and `host/` for details.

---

## Runtime data (do not commit)

| Path | Contents |
|------|----------|
| `host/data/bot.sqlite3` | Inbound ring buffer, etc. |
| `host/data/impressions/` | Per-user impressions |
| `host/data/identity/` | person_id aliases |
| `host/data/group_culture/` | Group culture notes |
| `host/data/media/` | Bubble crops copied out of the container |
| `host/data/*.txt` | Allowlists / observe lists / mode |
| `host/.env` | API keys |
| Docker volume `callus-data` | WeChat login + bridge-side media |

---

## Safety and risk (read this)

- This is **personal-account GUI automation**, not an official bot API — ban / device-risk applies.  
- Prefer: run only while you are present; keep allowlists tight; avoid high-frequency spam.  
- Never push `.env`, impressions, chat sqlite, or alias tables to a public remote.

---

## Development

```bash
cd bridge && make test
cd ../host && .venv/bin/python -m pytest tests/ -q
```

Upstream work often lands first in Callus-Bridge / WeJamBot, then merges here. **Public install and deploy docs are defined by this README pair.**

## License / attribution

Code is assembled from Potatoblock / Callus / WeJam-related work; WeChat client copyright belongs to Tencent. Comply with local law and WeChat’s software license before use.
