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
SERVICE_NAME := traefik
SERVICE_PORT := 8080
COMPOSE_FILE := ../docker-compose.proxy.yml
ENV_FILE := ../../.env

help: ## Show this help message
	@echo "$(BLUE)Traefik - Build System$(NC)"
	@echo ""
	@echo "This Makefile provides easy commands to manage the Traefik proxy service"
	@echo "Docker containers for the localnet environment."
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""

build: ## Build Traefik Docker images
	@echo "$(BLUE)Building Traefik Docker images...$(NC)"
	@docker compose --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE) --env-file $(ENV_FILE) build traefik
	@echo "$(GREEN)✓ Images built$(NC)"

up: ## Start Traefik services
	@echo "$(BLUE)Starting Traefik services...$(NC)"
	@docker compose --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE) --env-file $(ENV_FILE) up -d traefik
	@echo "$(GREEN)✓ Services started$(NC)"
	@echo "Run 'make health-check' to verify service health"

down: ## Stop Traefik services
	@echo "$(YELLOW)Stopping Traefik services...$(NC)"
	@docker compose --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE) --env-file $(ENV_FILE) down
	@echo "$(GREEN)✓ Services stopped$(NC)"

restart: ## Restart Traefik services
	@echo "$(YELLOW)Restarting Traefik services...$(NC)"
	@docker compose --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE) --env-file $(ENV_FILE) restart traefik
	@echo "$(GREEN)✓ Services restarted$(NC)"

logs: ## View logs from all Traefik services (last 100 lines)
	@docker compose --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE) --env-file $(ENV_FILE) logs --tail=100 traefik

logs-follow: ## Follow logs from all Traefik services
	@docker compose --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE) --env-file $(ENV_FILE) logs -f traefik

health-check: ## Check health status of Traefik services
	@echo "$(BLUE)Checking Traefik service health...$(NC)"
	@docker compose --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec traefik /usr/local/bin/check-health.sh
	@echo "$(GREEN)✓ Health check complete$(NC)"

test: ## Run tests for Traefik services
	@echo "$(BLUE)Running Traefik service tests...$(NC)"
	@docker compose --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec traefik /usr/local/bin/check-health.sh
	@echo "$(GREEN)✓ Traefik tests complete$(NC)"

lint: ## Lint docker-compose and configuration files
	@echo "$(BLUE)Linting configuration files...$(NC)"
	@docker compose --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE) config > /dev/null && echo "$(GREEN)✓ docker-compose --project-directory $(PROJECT_DIR) syntax valid$(NC)" || (echo "$(RED)✗ docker-compose --project-directory $(PROJECT_DIR) syntax invalid$(NC)"; exit 1)
	@echo "$(GREEN)✓ Lint complete$(NC)"

clean: ## Remove Traefik containers and networks (keeps volumes)
	@echo "$(RED)⚠ Removing Traefik containers and networks...$(NC)"
	@docker compose --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE) --env-file $(ENV_FILE) down --remove-orphans
	@echo "$(GREEN)✓ Containers and networks removed$(NC)"

clean-all: ## Remove Traefik containers, networks, and volumes (WARNING: destroys data!)
	@echo "$(RED)⚠ WARNING: This will destroy all Traefik data!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker compose --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE) --env-file $(ENV_FILE) down -v --remove-orphans; \
		echo "$(GREEN)✓ All data removed$(NC)"; \
	else \
		echo "$(YELLOW)Cancelled$(NC)"; \
	fi

status: ## Show status of Traefik containers
	@echo "$(BLUE)Traefik Service Status:$(NC)"
	@docker compose --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE) --env-file $(ENV_FILE) ps traefik

shell: ## Open shell in Traefik container
	@docker compose --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec traefik /bin/sh
