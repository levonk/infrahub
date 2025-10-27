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
SERVICE_NAME := tor
SERVICE_PORT := 9050
COMPOSE_FILE := ../../docker-compose.yml
ENV_FILE := ../../.env

help: ## Show this help message
	@echo "$(BLUE)Tor - Build System$(NC)"
	@echo ""
	@echo "This Makefile provides easy commands to manage the Tor proxy service"
	@echo "Docker containers for the localnet environment."
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""

build: ## Build Tor Docker images
	@echo "$(BLUE)Building Tor Docker images...$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) build tor
	@echo "$(GREEN)✓ Images built$(NC)"

up: ## Start Tor services
	@echo "$(BLUE)Starting Tor services...$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) up -d tor
	@echo "$(GREEN)✓ Services started$(NC)"
	@echo "Run 'make health-check' to verify service health"

down: ## Stop Tor services
	@echo "$(YELLOW)Stopping Tor services...$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) down
	@echo "$(GREEN)✓ Services stopped$(NC)"

restart: ## Restart Tor services
	@echo "$(YELLOW)Restarting Tor services...$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) restart tor
	@echo "$(GREEN)✓ Services restarted$(NC)"

logs: ## View logs from all Tor services (last 100 lines)
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) logs --tail=100 tor

logs-follow: ## Follow logs from all Tor services
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) logs -f tor

health-check: ## Check health status of Tor services
	@echo "$(BLUE)Checking Tor service health...$(NC)"
	@./healthcheck/check-health.sh
	@echo "$(GREEN)✓ Health check complete$(NC)"

test: ## Run tests for Tor services
	@echo "$(BLUE)Running Tor service tests...$(NC)"
	@./healthcheck/check-health.sh
	@echo "$(GREEN)✓ Tor tests complete$(NC)"

lint: ## Lint docker-compose.yml and configuration files
	@echo "$(BLUE)Linting configuration files...$(NC)"
	@docker compose -f $(COMPOSE_FILE) config > /dev/null && echo "$(GREEN)✓ docker-compose.yml syntax valid$(NC)" || (echo "$(RED)✗ docker-compose.yml syntax invalid$(NC)"; exit 1)
	@echo "$(GREEN)✓ Lint complete$(NC)"

clean: ## Remove Tor containers and networks (keeps volumes)
	@echo "$(RED)⚠ Removing Tor containers and networks...$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) down --remove-orphans
	@echo "$(GREEN)✓ Containers and networks removed$(NC)"

clean-all: ## Remove Tor containers, networks, and volumes (WARNING: destroys data!)
	@echo "$(RED)⚠ WARNING: This will destroy all Tor data!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) down -v --remove-orphans; \
		echo "$(GREEN)✓ All data removed$(NC)"; \
	else \
		echo "$(YELLOW)Cancelled$(NC)"; \
	fi

status: ## Show status of Tor containers
	@echo "$(BLUE)Tor Service Status:$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) ps tor

shell: ## Open shell in Tor container
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec tor /bin/sh
