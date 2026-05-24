PROJECT_DIR := ../../..
.PHONY: help build up down restart logs logs-follow health-check clean clean-all test lint shell status

# Default target
.DEFAULT_GOAL := help

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

# Project configuration
SERVICE_NAME := gost
SERVICE_PORT := 1080
COMPOSE_FILE := ../docker-compose.proxy.yml
ENV_FILE := ../../.env

help: ## Show this help message
	@echo "$(BLUE)Gost - Build System$(NC)"
	@echo ""
	@echo "This Makefile provides easy commands to manage the Gost proxy service"
	@echo "Docker containers for the localnet environment."
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""

build: ## Build Gost Docker images
	@echo "$(BLUE)Building Gost Docker images...$(NC)"
	@docker compose --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE) --env-file $(ENV_FILE) build gost
	@echo "$(GREEN)✓ Images built$(NC)"

up: ## Start Gost services
	@echo "$(BLUE)Starting Gost services...$(NC)"
	@docker compose --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE) --env-file $(ENV_FILE) up -d gost
	@echo "$(GREEN)✓ Services started$(NC)"
	@echo "Run 'make health-check' to verify service health"

down: ## Stop Gost services
	@echo "$(YELLOW)Stopping Gost services...$(NC)"
	@docker compose --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE) --env-file $(ENV_FILE) down
	@echo "$(GREEN)✓ Services stopped$(NC)"

restart: ## Restart Gost services
	@echo "$(YELLOW)Restarting Gost services...$(NC)"
	@docker compose --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE) --env-file $(ENV_FILE) restart gost
	@echo "$(GREEN)✓ Services restarted$(NC)"

logs: ## View logs from all Gost services (last 100 lines)
	@docker compose --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE) --env-file $(ENV_FILE) logs --tail=100 gost

logs-follow: ## Follow logs from all Gost services
	@docker compose --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE) --env-file $(ENV_FILE) logs -f gost

health-check: ## Check health status of Gost services
	@echo "$(BLUE)Checking Gost service health...$(NC)"
	@docker compose --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec gost /healthcheck/check-gost.sh
	@echo "$(GREEN)✓ Health check complete$(NC)"

test: ## Run tests for Gost services
	@echo "$(BLUE)Running Gost service tests...$(NC)"
	@docker compose --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec gost /healthcheck/check-gost.sh
	@echo "$(GREEN)✓ Gost tests complete$(NC)"

lint: ## Lint docker-compose and configuration files
	@echo "$(BLUE)Linting configuration files...$(NC)"
	@docker compose --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE) config > /dev/null && echo "$(GREEN)✓ docker-compose --project-directory $(PROJECT_DIR) syntax valid$(NC)" || (echo "$(RED)✗ docker-compose --project-directory $(PROJECT_DIR) syntax invalid$(NC)"; exit 1)
	@echo "$(GREEN)✓ Lint complete$(NC)"

clean: ## Remove Gost containers and networks (keeps volumes)
	@echo "$(RED)⚠ Removing Gost containers and networks...$(NC)"
	@docker compose --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE) --env-file $(ENV_FILE) down --remove-orphans
	@echo "$(GREEN)✓ Containers and networks removed$(NC)"

clean-all: ## Remove Gost containers, networks, and volumes (WARNING: destroys data!)
	@echo "$(RED)⚠ WARNING: This will destroy all Gost data!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker compose --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE) --env-file $(ENV_FILE) down -v --remove-orphans; \
		echo "$(GREEN)✓ All data removed$(NC)"; \
	else \
		echo "$(YELLOW)Cancelled$(NC)"; \
	fi

status: ## Show status of Gost containers
	@echo "$(BLUE)Gost Service Status:$(NC)"
	@docker compose --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE) --env-file $(ENV_FILE) ps gost

shell: ## Open shell in Gost container
	@docker compose --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec gost /bin/sh
