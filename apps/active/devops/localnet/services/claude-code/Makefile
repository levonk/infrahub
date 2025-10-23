.PHONY: help build up down restart logs logs-follow health-check clean clean-all test-mcp status

# Default target
.DEFAULT_GOAL := help

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

# Project paths
PROJECT_ROOT := ../../../../..
COMPOSE_FILE := $(PROJECT_ROOT)/apps/active/devops/localnet/services/claude-code/docker-compose.claude-code.yml
ENV_FILE := $(PROJECT_ROOT)/apps/active/devops/localnet/.env

help: ## Show this help message
	@echo "$(BLUE)Claude Code Integration - Build System$(NC)"
	@echo ""
	@echo "This Makefile provides easy commands to manage Claude Code Docker containers"
	@echo "for the localnet environment."
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""

build: ## Build all Claude Code Docker images
	@echo "$(BLUE)Building Claude Code Docker images...$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) build
	@echo "$(GREEN)✓ Images built$(NC)"

up: ## Start all Claude Code services
	@echo "$(BLUE)Starting Claude Code services...$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) up -d
	@echo "$(GREEN)✓ Services started$(NC)"
	@echo "Run 'make health-check' to verify service health"

down: ## Stop all Claude Code services
	@echo "$(YELLOW)Stopping Claude Code services...$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) down
	@echo "$(GREEN)✓ Services stopped$(NC)"

restart: ## Restart all Claude Code services
	@echo "$(YELLOW)Restarting Claude Code services...$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) restart
	@echo "$(GREEN)✓ Services restarted$(NC)"

logs: ## View logs from all Claude Code services (last 100 lines)
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) logs --tail=100

logs-follow: ## Follow logs from all Claude Code services
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) logs -f

health-check: ## Check health status of Claude Code services
	@echo "$(BLUE)Checking Claude Code service health...$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) ps
	@echo ""
	@echo "$(BLUE)Running health checks...$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec claude-code curl -f http://localhost:8081/health 2>/dev/null && echo "$(GREEN)✓ Claude Code healthy$(NC)" || echo "$(RED)✗ Claude Code unhealthy$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec claude-code-ui curl -f http://localhost:3000/health 2>/dev/null && echo "$(GREEN)✓ Claude Code UI healthy$(NC)" || echo "$(RED)✗ Claude Code UI unhealthy$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec claude-code-auth curl -f http://localhost:8080/health 2>/dev/null && echo "$(GREEN)✓ Claude Code Auth healthy$(NC)" || echo "$(RED)✗ Claude Code Auth unhealthy$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec claude-code-mcp curl -f http://localhost:8082/health 2>/dev/null && echo "$(GREEN)✓ Claude Code MCP healthy$(NC)" || echo "$(RED)✗ Claude Code MCP unhealthy$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec pluggedin-mcp-proxy curl -f http://localhost:8085/health 2>/dev/null && echo "$(GREEN)✓ MCP Proxy healthy$(NC)" || echo "$(RED)✗ MCP Proxy unhealthy$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec pluggedin-app curl -f http://localhost:8086/health 2>/dev/null && echo "$(GREEN)✓ PluggedIn App healthy$(NC)" || echo "$(RED)✗ PluggedIn App unhealthy$(NC)"
	@echo "$(GREEN)✓ Health check complete$(NC)"

clean: ## Remove Claude Code containers and networks (keeps volumes)
	@echo "$(RED)⚠ Removing Claude Code containers and networks...$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) down --remove-orphans
	@echo "$(GREEN)✓ Containers and networks removed$(NC)"

clean-all: ## Remove Claude Code containers, networks, and volumes (WARNING: destroys data!)
	@echo "$(RED)⚠ WARNING: This will destroy all Claude Code data!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) down -v --remove-orphans; \
		echo "$(GREEN)✓ All data removed$(NC)"; \
	else \
		echo "$(YELLOW)Cancelled$(NC)"; \
	fi

status: ## Show status of Claude Code containers
	@echo "$(BLUE)Claude Code Service Status:$(NC)"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) ps

test-mcp: ## Test MCP tool integration and functionality
	@echo "$(BLUE)Testing MCP tool integration...$(NC)"
	@echo "1. Checking MCP server connectivity..."
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec claude-code-mcp curl -f http://localhost:8082/tools 2>/dev/null && echo "$(GREEN)✓ MCP server tools endpoint accessible$(NC)" || echo "$(RED)✗ MCP server tools endpoint not accessible$(NC)"
	@echo "2. Testing MCP proxy connectivity..."
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec pluggedin-mcp-proxy curl -f http://localhost:8085/tools 2>/dev/null && echo "$(GREEN)✓ MCP proxy tools endpoint accessible$(NC)" || echo "$(RED)✗ MCP proxy tools endpoint not accessible$(NC)"
	@echo "3. Testing tool discovery..."
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec claude-code-mcp curl -s http://localhost:8082/tools | grep -q "file-system\|shell\|git" && echo "$(GREEN)✓ MCP tools discovered (file-system, shell, git)$(NC)" || echo "$(RED)✗ MCP tools not properly discovered$(NC)"
	@echo "4. Testing Claude Code integration..."
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec claude-code curl -s http://claude-code-mcp:8082/tools | grep -q "tools" && echo "$(GREEN)✓ Claude Code can reach MCP server$(NC)" || echo "$(RED)✗ Claude Code cannot reach MCP server$(NC)"
	@echo "$(GREEN)✓ MCP integration test complete$(NC)"
