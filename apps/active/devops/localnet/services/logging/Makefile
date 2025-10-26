.PHONY: help build up down restart status logs logs-follow health-check lint clean clean-all

.DEFAULT_GOAL := help

BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m

COMPOSE_FILE := docker-compose.logging.yml
ENV_ARGS :=

ENSURE_NETWORK := ../../scripts/ensure-network.py

ifneq (,$(wildcard .env))
ENV_ARGS += --env-file ./.env
endif

ifneq (,$(wildcard ../../.env))
ENV_ARGS += --env-file ../../.env
endif

COMPOSE := docker compose -f $(COMPOSE_FILE) $(ENV_ARGS)

help: ## Show available targets for the logging stack
	@echo "$(BLUE)Logging Stack - Command Reference$(NC)"
	@echo ""
	@echo "Manage Vector, Elasticsearch, Loki, and Promtail services for observability."
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-18s$(NC) %s\n", $$1, $$2}'
	@echo ""

build: ## Build local images (if any) for logging services
	@echo "$(BLUE)Building logging service images...$(NC)"
	@$(COMPOSE) build
	@echo "$(GREEN)✓ Images built$(NC)"

up: ## Start logging services in detached mode
	@echo "$(BLUE)Starting logging services...$(NC)"
	@$(ENSURE_NETWORK) -f $(COMPOSE_FILE)
	@$(COMPOSE) up -d
	@echo "$(GREEN)✓ Services started$(NC)"
	@echo "Run 'make health-check' after containers finish booting."

down: ## Stop logging services and remove containers
	@echo "$(YELLOW)Stopping logging services...$(NC)"
	@$(COMPOSE) down
	@echo "$(GREEN)✓ Services stopped$(NC)"

restart: ## Restart logging services without recreating volumes
	@echo "$(YELLOW)Restarting logging services...$(NC)"
	@$(ENSURE_NETWORK) -f $(COMPOSE_FILE)
	@$(COMPOSE) restart
	@echo "$(GREEN)✓ Services restarted$(NC)"

status: ## Show container status table
	@$(COMPOSE) ps

logs: ## Tail last 200 lines from all logging containers
	@$(COMPOSE) logs --tail=200

logs-follow: ## Follow logs from logging containers
	@$(COMPOSE) logs -f

health-check: ## Inspect container status for logging stack
	@echo "$(BLUE)Inspecting logging containers...$(NC)"
	@$(COMPOSE) ps

lint: ## Validate docker-compose.logging.yml syntax (and yamllint when available)
	@echo "$(BLUE)Linting docker-compose.logging.yml...$(NC)"
	@$(COMPOSE) config >/dev/null && echo "$(GREEN)✓ docker-compose configuration valid$(NC)"
	@if command -v yamllint >/dev/null 2>&1; then \
		yamllint $(COMPOSE_FILE); \
	else \
		echo "$(YELLOW)⚠ yamllint not installed$(NC)"; \
	fi

clean: ## Remove logging containers and networks (preserve volumes)
	@echo "$(RED)Removing logging containers and networks...$(NC)"
	@$(COMPOSE) down --remove-orphans
	@docker network prune -f >/dev/null
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

clean-all: ## Remove logging containers, networks, and volumes (data loss!)
	@echo "$(RED)⚠ This will delete logging data volumes$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; echo ""; \
	if echo "$$REPLY" | grep -Eq '^[Yy]$$'; then \
		$(COMPOSE) down -v --remove-orphans; \
		docker network prune -f >/dev/null; \
		echo "$(GREEN)✓ Logging volumes removed$(NC)"; \
	else \
		echo "$(YELLOW)Cancelled$(NC)"; \
	fi
