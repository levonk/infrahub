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
SERVICE_NAME := chronyd
COMPOSE_FILE := ../docker-compose.ntp.yml
ENV_FILE := ../../.env

help: ## Show this help message
	@echo "$(BLUE)Chronyd - Build System$(NC)"
	@echo ""
	@echo "This Makefile provides easy commands to manage the Chronyd NTP service"
	@echo "Docker containers for the localnet environment."
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""

build: ## Build Chronyd Docker images
	@echo "$(BLUE)Building Chronyd Docker images...$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) build chronyd
	@echo "$(GREEN)✓ Images built$(NC)"

up: ## Start Chronyd services
	@echo "$(BLUE)Starting Chronyd services...$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) up -d chronyd
	@echo "$(GREEN)✓ Services started$(NC)"
	@echo "Run 'make health-check' to verify service health"

down: ## Stop Chronyd services
	@echo "$(YELLOW)Stopping Chronyd services...$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) down
	@echo "$(GREEN)✓ Services stopped$(NC)"

restart: ## Restart Chronyd services
	@echo "$(YELLOW)Restarting Chronyd services...$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) restart chronyd
	@echo "$(GREEN)✓ Services restarted$(NC)"

logs: ## View logs from all Chronyd services (last 100 lines)
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) logs --tail=100 chronyd

logs-follow: ## Follow logs from all Chronyd services
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) logs -f chronyd

health-check: ## Check health status of Chronyd services
	@echo "$(BLUE)Checking Chronyd service health...$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec chronyd /healthcheck/check-health.sh
	@echo "$(GREEN)✓ Health check complete$(NC)"

test: ## Run tests for Chronyd services
	@echo "$(BLUE)Running Chronyd service tests...$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec chronyd /healthcheck/check-health.sh
	@echo "$(GREEN)✓ Chronyd tests complete$(NC)"

lint: ## Lint docker-compose.yml and configuration files
	@echo "$(BLUE)Linting configuration files...$(NC)"
	@docker compose -f $(COMPOSE_FILE) config > /dev/null && echo "$(GREEN)✓ docker-compose.yml syntax valid$(NC)" || (echo "$(RED)✗ docker-compose.yml syntax invalid$(NC)"; exit 1)
	@echo "$(GREEN)✓ Lint complete$(NC)"

clean: ## Remove Chronyd containers and networks (keeps volumes)
	@echo "$(RED)⚠ Removing Chronyd containers and networks...$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) down --remove-orphans
	@echo "$(GREEN)✓ Containers and networks removed$(NC)"

clean-all: ## Remove Chronyd containers, networks, and volumes (WARNING: destroys data!)
	@echo "$(RED)⚠ WARNING: This will destroy all Chronyd data!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) down -v --remove-orphans; \
		echo "$(GREEN)✓ All data removed$(NC)"; \
	else \
		echo "$(YELLOW)Cancelled$(NC)"; \
	fi

status: ## Show status of Chronyd containers
	@echo "$(BLUE)Chronyd Service Status:$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) ps chronyd

shell: ## Open shell in Chronyd container
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec chronyd /bin/sh
