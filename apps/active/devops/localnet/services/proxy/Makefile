.PHONY: help build up down restart status logs logs-follow health-check lint clean clean-all

.DEFAULT_GOAL := help

BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m

COMPOSE_FILE := docker-compose.proxy.yml
ENV_ARGS :=

ENSURE_NETWORK := ../../scripts/ensure-network.py

ifneq (,$(wildcard .env))
ENV_ARGS += --env-file ./.env
endif

ifneq (,$(wildcard ../../.env))
ENV_ARGS += --env-file ../../.env
endif

COMPOSE := docker compose -f $(COMPOSE_FILE) $(ENV_ARGS)

help: ## Show available targets for the proxy stack
	@echo "$(BLUE)Proxy Stack - Command Reference$(NC)"
	@echo ""
	@echo "Manage edge proxy services (Traefik, Gost, and supporting gateways)."
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-18s$(NC) %s\n", $$1, $$2}'
	@echo ""

build: ## Build local images (if any) for proxy services
	@echo "$(BLUE)Building proxy service images...$(NC)"
	@$(COMPOSE) build
	@echo "$(GREEN)✓ Images built$(NC)"

up: ## Start proxy services in detached mode
	@echo "$(BLUE)Starting proxy services...$(NC)"
	@$(ENSURE_NETWORK) -f $(COMPOSE_FILE)
	@$(COMPOSE) up -d
	@echo "$(GREEN)✓ Services started$(NC)"
	@echo "Run 'make health-check' after containers finish booting."

down: ## Stop proxy services and remove containers
	@echo "$(YELLOW)Stopping proxy services...$(NC)"
	@$(COMPOSE) down
	@echo "$(GREEN)✓ Services stopped$(NC)"

restart: ## Restart proxy services without recreating volumes
	@echo "$(YELLOW)Restarting proxy services...$(NC)"
	@$(ENSURE_NETWORK) -f $(COMPOSE_FILE)
	@$(COMPOSE) restart
	@echo "$(GREEN)✓ Services restarted$(NC)"

status: ## Show container status table
	@$(COMPOSE) ps

logs: ## Tail last 200 lines from all proxy containers
	@$(COMPOSE) logs --tail=200

logs-follow: ## Follow logs from proxy containers
	@$(COMPOSE) logs -f

health-check: ## Inspect container status for proxy stack
	@echo "$(BLUE)Inspecting proxy containers...$(NC)"
	@$(COMPOSE) ps

lint: ## Validate docker-compose.proxy.yml syntax (and yamllint when available)
	@echo "$(BLUE)Linting docker-compose.proxy.yml...$(NC)"
	@$(COMPOSE) config >/dev/null && echo "$(GREEN)✓ docker-compose configuration valid$(NC)"
	@if command -v yamllint >/dev/null 2>&1; then \
		yamllint $(COMPOSE_FILE); \
	else \
		echo "$(YELLOW)⚠ yamllint not installed$(NC)"; \
	fi

clean: ## Remove proxy containers and networks (preserve volumes)
	@echo "$(RED)Removing proxy containers and networks...$(NC)"
	@$(COMPOSE) down --remove-orphans
	@docker network prune -f >/dev/null
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

clean-all: ## Remove proxy containers, networks, and volumes (data loss!)
	@echo "$(RED)⚠ This will delete proxy data volumes$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; echo ""; \
	if echo "$$REPLY" | grep -Eq '^[Yy]$$'; then \
		$(COMPOSE) down -v --remove-orphans; \
		docker network prune -f >/dev/null; \
		echo "$(GREEN)✓ Proxy volumes removed$(NC)"; \
	else \
		echo "$(YELLOW)Cancelled$(NC)"; \
	fi
