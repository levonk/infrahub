PROJECT_DIR := ../..
.PHONY: help build up down restart status logs logs-follow health-check lint clean clean-all shell-nexus shell-verdaccio

.DEFAULT_GOAL := help

BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m

COMPOSE_FILE := docker-compose.artifact.yml
ENV_ARGS :=

ENSURE_NETWORK := ../../scripts/ensure-network.py

ifneq (,$(wildcard .env))
ENV_ARGS += --env-file ./.env
endif

ifneq (,$(wildcard ../../.env))
ENV_ARGS += --env-file ../../.env
endif

COMPOSE := docker compose --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE) $(ENV_ARGS)

help: ## Show available targets and descriptions
	@echo "$(BLUE)Artifact Repository Services$(NC)"
	@echo ""
	@echo "This Makefile wraps docker-compose --project-directory $(PROJECT_DIR) so you can manage Sonatype"
	@echo "Nexus and Verdaccio in the localnet environment without typing long commands."
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-18s$(NC) %s\n", $$1, $$2}'
	@echo ""

build: ## Build local Docker images (if any) for the artifact stack
	@echo "$(BLUE)Building artifact service images...$(NC)"
	@$(COMPOSE) build
	@echo "$(GREEN)✓ Images built$(NC)"

up: ## Start Nexus and Verdaccio in detached mode
	@echo "$(BLUE)Starting artifact services...$(NC)"
	@$(ENSURE_NETWORK) --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE)
	@$(COMPOSE) up -d
	@echo "$(GREEN)✓ Services started$(NC)"
	@echo "Run 'make health-check' once containers finish booting."

down: ## Stop artifact services and remove containers
	@echo "$(YELLOW)Stopping artifact services...$(NC)"
	@$(COMPOSE) down
	@echo "$(GREEN)✓ Services stopped$(NC)"

restart: ## Restart artifact services without recreating volumes
	@echo "$(YELLOW)Restarting artifact services...$(NC)"
	@$(ENSURE_NETWORK) --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE)
	@$(COMPOSE) restart
	@echo "$(GREEN)✓ Services restarted$(NC)"

status: ## Show container status table
	@$(COMPOSE) ps

logs: ## Tail last 200 log lines from all containers
	@$(COMPOSE) logs --tail=200

logs-follow: ## Stream container logs
	@$(COMPOSE) logs -f

health-check: ## Probe HTTP health endpoints for Nexus and Verdaccio
	@echo "$(BLUE)Inspecting container status...$(NC)"
	@$(COMPOSE) ps
	@echo ""
	@echo "$(BLUE)Checking Nexus status endpoint...$(NC)"
	@$(COMPOSE) exec nexus curl -fs http://localhost:8081/service/rest/v1/status >/dev/null && \
		echo "$(GREEN)✓ Nexus status reachable$(NC)" || echo "$(RED)✗ Nexus status failed$(NC)"
	@echo "$(BLUE)Checking Verdaccio ping endpoint...$(NC)"
	@$(COMPOSE) exec verdaccio wget --spider -q http://localhost:4873/-/ping && \
		echo "$(GREEN)✓ Verdaccio ping reachable$(NC)" || echo "$(RED)✗ Verdaccio ping failed$(NC)"

lint: ## Validate docker-compose syntax (and yamllint if present)
	@echo "$(BLUE)Linting docker-compose --project-directory $(PROJECT_DIR) 
	@$(COMPOSE) config >/dev/null && echo "$(GREEN)✓ docker-compose --project-directory $(PROJECT_DIR) configuration valid$(NC)"
	@if command -v yamllint >/dev/null 2>&1; then \
		yamllint $(COMPOSE_FILE); \
	else \
		echo "$(YELLOW)⚠ yamllint not installed$(NC)"; \
	fi

clean: ## Remove containers and networks (keep volumes intact)
	@echo "$(RED)Removing artifact containers and networks...$(NC)"
	@$(COMPOSE) down --remove-orphans
	@docker network prune -f >/dev/null
	@echo "$(GREEN)✓ Containers and networks removed$(NC)"

clean-all: ## Destroy containers, networks, and volumes (data loss!)
	@echo "$(RED)⚠ This will delete Nexus and Verdaccio data volumes$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; echo ""; \
	if echo "$$REPLY" | grep -Eq '^[Yy]$$'; then \
		$(COMPOSE) down -v --remove-orphans; \
		docker network prune -f >/dev/null; \
		echo "$(GREEN)✓ All volumes removed$(NC)"; \
	else \
		echo "$(YELLOW)Cancelled$(NC)"; \
	fi

shell-nexus: ## Open a shell inside the Nexus container
	@$(COMPOSE) exec nexus /bin/sh

shell-verdaccio: ## Open a shell inside the Verdaccio container
	@$(COMPOSE) exec verdaccio /bin/sh
