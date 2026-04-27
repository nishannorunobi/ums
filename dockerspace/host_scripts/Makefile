COMPOSE = docker compose -f docker-compose.yml

.PHONY: up down restart build logs status ps

up:
	@if [ ! -f ../../.env ]; then cp ../../.env.example ../../.env; echo "[WARN] .env not found — copied from .env.example"; fi
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

down-v:
	$(COMPOSE) down --volumes

restart:
	$(COMPOSE) down
	$(COMPOSE) up -d --build

build:
	$(COMPOSE) build

logs:
	$(COMPOSE) logs -f $(service)

status:
	$(COMPOSE) ps

ps: status
