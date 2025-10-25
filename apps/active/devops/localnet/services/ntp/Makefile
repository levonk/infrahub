.PHONY: help build up down restart status logs logs-follow health-check lint clean clean-all shell-chronyd

.DEFAULT_GOAL := help

BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m

COMPOSE_FILE := docker-compose.ntp.yml
ENV_ARGS :=

ENSURE_NETWORK := ../../scripts/ensure-network.py

ifneq (,$(wildcard .env))
ENV_ARGS += --env-file ./.env
endif

ifneq (,$(wildcard ../../.env))
ENV_ARGS += --env-file ../../.env
endif

COMPOSE := docker compose -f $(COMPOSE_FILE) $(ENV_ARGS)

help: ## Show available targets and descriptions
	@echo "$(BLUE)Network Time Protocol Service$(NC)"
	@echo ""
	@echo "Manage the chronyd container that provides secure NTP for the localnet stack."
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-18s$(NC) %s\n", $$1, $$2}'
	@echo ""

build: ## Build the chronyd image defined in docker-compose.ntp.yml
	@echo "$(BLUE)Building chronyd image...$(NC)"
	@$(COMPOSE) build
	@echo "$(GREEN)✓ Image build complete$(NC)"

up: ## Start chronyd in detached mode
	@echo "$(BLUE)Starting chronyd service...$(NC)"
	@$(ENSURE_NETWORK) -f $(COMPOSE_FILE)
	@$(COMPOSE) up -d
	@echo "$(GREEN)✓ chronyd running$(NC)"
	@echo "Run 'make health-check' after the container is healthy to verify synchronization."

down: ## Stop chronyd and remove the container
	@echo "$(YELLOW)Stopping chronyd service...$(NC)"
	@$(COMPOSE) down
	@echo "$(GREEN)✓ chronyd stopped$(NC)"

restart: ## Restart chronyd without touching volumes
	@echo "$(YELLOW)Restarting chronyd...$(NC)"
	@$(ENSURE_NETWORK) -f $(COMPOSE_FILE)
	@$(COMPOSE) restart
	@echo "$(GREEN)✓ chronyd restarted$(NC)"

status: ## Show docker compose status table
	@$(COMPOSE) ps

logs: ## Tail the last 200 log lines from chronyd
	@$(COMPOSE) logs --tail=200

logs-follow: ## Stream chronyd logs
	@$(COMPOSE) logs -f

health-check: ## Validate chronyd responds to tracking and sources queries
	@echo "$(BLUE)Inspecting container status...$(NC)"
	@$(COMPOSE) ps
	@echo ""
	@echo "$(BLUE)Running chronyc tracking...$(NC)"
	@$(COMPOSE) exec chronyd chronyc tracking
	@echo "$(BLUE)Running chronyc sources...$(NC)"
	@$(COMPOSE) exec chronyd chronyc sources

lint: ## Validate docker-compose.ntp.yml and run yamllint when available
	@echo "$(BLUE)Linting docker-compose.ntp.yml...$(NC)"
	@$(COMPOSE) config >/dev/null && echo "$(GREEN)✓ docker-compose configuration valid$(NC)"
	@if command -v yamllint >/dev/null 2>&1; then \
		yamllint $(COMPOSE_FILE); \
	else \
		echo "$(YELLOW)⚠ yamllint not installed$(NC)"; \
	fi

clean: ## Remove chronyd container and dangling networks (retain data volume)
	@echo "$(RED)Removing chronyd container and networks...$(NC)"
	@$(COMPOSE) down --remove-orphans
	@docker network prune -f >/dev/null
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

clean-all: ## Destroy chronyd container, network, and volumes (data loss!)
	@echo "$(RED)⚠ This removes the chronyd-data volume and wipes drift history$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; echo ""; \
	if echo "$$REPLY" | grep -Eq '^[Yy]$$'; then \
		$(COMPOSE) down -v --remove-orphans; \
		docker network prune -f >/dev/null; \
		echo "$(GREEN)✓ All volumes removed$(NC)"; \
	else \
		echo "$(YELLOW)Cancelled$(NC)"; \
	fi

shell-chronyd: ## Open an interactive shell inside the chronyd container
	@$(COMPOSE) exec chronyd /bin/sh
