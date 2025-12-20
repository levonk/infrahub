.PHONY: help build up deploy debug down restart logs logs-follow health-check clean clean-all test lint shell status

# Default target
.DEFAULT_GOAL := help

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

# Project configuration
SERVICE_NAME := jellyfin
SERVICE_PORT := 8096
SERVICE_HEALTH_ENDPOINT := /health
COMPOSE_FILE := docker-compose.yml
ENV_FILE := .env

help: ## Show this help message
	@echo "$(BLUE)Jellyfin - Build System$(NC)"
	@echo ""
	@echo "This Makefile provides easy commands to manage Jellyfin"
	@echo "Docker containers for the localnet environment."
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""

build: ## Build Jellyfin Docker images
	@echo "$(BLUE)Building Jellyfin Docker images...$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) build
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) --profile debug build
	@echo "$(GREEN)✓ Images built$(NC)"

up: ## Start Jellyfin services
	@echo "$(BLUE)Starting Jellyfin services...$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) up -d
	@echo "$(GREEN)✓ Services started$(NC)"
	@echo "Run 'make health-check' to verify service health"

deploy: ## Deploy Jellyfin services (alias for up)
	@$(MAKE) up

debug: ## Start Jellyfin debug container (opt-in)
	@echo "$(BLUE)Starting Jellyfin debug container...$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) --profile debug up -d
	@echo "$(GREEN)✓ Debug container started$(NC)"

down: ## Stop Jellyfin services
	@echo "$(YELLOW)Stopping Jellyfin services...$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) down
	@echo "$(GREEN)✓ Services stopped$(NC)"

restart: ## Restart Jellyfin services
	@echo "$(YELLOW)Restarting Jellyfin services...$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) restart
	@echo "$(GREEN)✓ Services restarted$(NC)"

logs: ## View logs from Jellyfin (last 100 lines)
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) logs --tail=100

logs-follow: ## Follow logs from Jellyfin
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) logs -f

health-check: ## Check health status of Jellyfin
	@echo "$(BLUE)Checking Jellyfin service health...$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) ps
	@echo ""
	@echo "$(BLUE)Running health checks...$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec -T $(SERVICE_NAME) curl -f http://localhost:$(SERVICE_PORT)$(SERVICE_HEALTH_ENDPOINT) 2>/dev/null && echo "$(GREEN)✓ Jellyfin healthy$(NC)" || echo "$(RED)✗ Jellyfin unhealthy$(NC)"
	@echo "$(GREEN)✓ Health check complete$(NC)"

test: ## Run tests for Jellyfin
	@echo "$(BLUE)Running Jellyfin service tests...$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) ps | grep -q "$(SERVICE_NAME)" && echo "$(GREEN)✓ Jellyfin service is running$(NC)" || (echo "$(RED)✗ Jellyfin service not running$(NC)"; exit 1)
	@echo "$(BLUE)Testing Jellyfin health...$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec -T $(SERVICE_NAME) curl -f http://localhost:$(SERVICE_PORT)$(SERVICE_HEALTH_ENDPOINT) >/dev/null 2>&1 && echo "$(GREEN)✓ Jellyfin healthy$(NC)" || echo "$(YELLOW)⚠ Jellyfin not responding$(NC)"
	@echo "$(GREEN)✓ Jellyfin tests complete$(NC)"


lint: ## Lint docker-compose.yml and configuration files
	@echo "$(BLUE)Linting configuration files...$(NC)"
	@docker compose -f $(COMPOSE_FILE) config > /dev/null && echo "$(GREEN)✓ docker-compose.yml syntax valid$(NC)" || (echo "$(RED)✗ docker-compose.yml syntax invalid$(NC)"; exit 1)
	@if command -v yamllint >/dev/null 2>&1; then \
		yamllint $(COMPOSE_FILE) || echo "$(YELLOW)⚠ yamllint issues found$(NC)"; \
	else \
		echo "$(YELLOW)⚠ yamllint not installed$(NC)"; \
	fi
	@echo "$(GREEN)✓ Lint complete$(NC)"

clean: ## Remove Jellyfin containers and networks (keeps volumes)
	@echo "$(RED)⚠ Removing Jellyfin containers and networks...$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) down --remove-orphans
	@echo "$(GREEN)✓ Containers and networks removed$(NC)"

clean-all: ## Remove Jellyfin containers, networks, and volumes (WARNING: destroys data!)
	@echo "$(RED)⚠ WARNING: This will destroy all Jellyfin data!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) down -v --remove-orphans; \
		echo "$(GREEN)✓ All data removed$(NC)"; \
	else \
		echo "$(YELLOW)Cancelled$(NC)"; \
	fi

status: ## Show status of Jellyfin containers
	@echo "$(BLUE)Jellyfin Service Status:$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) ps

backup: ## Create secure backup of service data and configuration
	@echo "$(BLUE)Creating backup of Jellyfin service...$(NC)"
	@./scripts/backup.sh
	@echo "$(GREEN)✓ Backup completed$(NC)"

security-scan: ## Run comprehensive security scans on the service
	@echo "$(BLUE)Running security scans on Jellyfin service...$(NC)"
	@./scripts/security-scan.sh
	@echo "$(GREEN)✓ Security scan completed$(NC)"
