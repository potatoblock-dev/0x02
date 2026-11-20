# 0x02 一体仓快捷入口（细节见 README）
.PHONY: bridge-build bridge-up bridge-down host-venv host-bot status

bridge-build:
	$(MAKE) -C bridge build

bridge-up:
	$(MAKE) -C bridge up

bridge-down:
	$(MAKE) -C bridge down

host-venv:
	cd host && python3 -m venv .venv && .venv/bin/pip install -e '.[bot]'

host-bot:
	cd host && bash scripts/start-bot.sh

status:
	$(MAKE) -C bridge status
