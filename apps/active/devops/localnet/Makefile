.PHONY: help up down restart logs logs-follow health-check flush-cache backup restore clean clean-configs fix-configs test test-all lint test-claude lint-claude

# Default target
.DEFAULT_GOAL := help

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(BLUE)Home Lab In-a-Box - Available Commands$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""

up: ## Start all services
	@echo "$(BLUE)Starting all services...$(NC)"
	docker compose up -d
	@echo "$(GREEN)✓ Services started$(NC)"
	@echo "Run 'make health-check' to verify service health"

down: ## Stop all services
	@echo "$(YELLOW)Stopping all services...$(NC)"
	docker compose down
	@echo "$(GREEN)✓ Services stopped$(NC)"

restart: ## Restart all services
	@echo "$(YELLOW)Restarting all services...$(NC)"
	docker compose restart
	@echo "$(GREEN)✓ Services restarted$(NC)"

logs: ## View logs from all services (last 100 lines)
	docker compose logs --tail=100

logs-follow: ## Follow logs from all services
	docker compose logs -f

health-check: ## Check health status of all services
	@echo "$(BLUE)Checking service health...$(NC)"
	@docker compose ps
	@echo ""
	@echo "$(BLUE)Running health checks...$(NC)"
	@./scripts/health-checks/nftables-check.sh || echo "$(YELLOW)⚠ nftables check failed$(NC)"
	@echo "$(GREEN)✓ Health check complete$(NC)"

flush-cache: ## Flush all caches (DNS, Web)
	@echo "$(YELLOW)Flushing DNS cache...$(NC)"
	docker compose exec coredns kill -SIGUSR1 1 || echo "CoreDNS not running"
	@echo "$(YELLOW)Flushing web cache...$(NC)"
	docker compose restart squid
	@echo "$(GREEN)✓ Caches flushed$(NC)"

backup: ## Backup all persistent volumes
	@echo "$(BLUE)Backing up volumes...$(NC)"
	@./scripts/backup-volumes.sh
	@echo "$(GREEN)✓ Backup complete$(NC)"

restore: ## Restore volumes from backup
	@echo "$(YELLOW)Restoring volumes...$(NC)"
	@./scripts/restore-volumes.sh
	@echo "$(GREEN)✓ Restore complete$(NC)"

test: ## Run E2E tests (quick subset)
	@echo "$(BLUE)Running E2E tests...$(NC)"
	@./scripts/tests/test-dns-services.sh
	@./scripts/tests/test-monitoring.sh
	@echo "$(GREEN)✓ Tests complete$(NC)"

test-all: ## Run all E2E tests (comprehensive)
	@echo "$(BLUE)Running all E2E tests...$(NC)"
	@./scripts/tests/run-all-tests.sh

update-blocklists: ## Update DNS/web blocklists
	@echo "$(BLUE)Updating blocklists...$(NC)"
	docker compose exec dnsdist /blocklists/update-blocklists.sh
	@echo "$(GREEN)✓ Blocklists updated$(NC)"

clean-configs: ## Remove Docker-created config directories (safe, no data loss)
	@echo "$(BLUE)Cleaning up Docker-created config directories...$(NC)"
	@docker run --rm -v "$$(pwd)/configs:/configs" alpine sh -c '\
		find /configs -type d \( \
			-name "*.conf" -o \
			-name "*.yaml" -o \
			-name "*.yml" -o \
			-name "config" -o \
			-name "config.yaml" \
		\) -exec rm -rf {} + 2>/dev/null || true'
	@echo "$(GREEN)✓ Config directories removed$(NC)"
	@echo "$(YELLOW)Run 'make fix-configs' to recreate config files$(NC)"

fix-configs: clean-configs ## Recreate all config files from templates
	@echo "$(BLUE)Recreating config files...$(NC)"
	@./scripts/create-configs.sh
	@echo "$(GREEN)✓ Config files created$(NC)"

clean: ## Remove all containers, volumes, and networks (WARNING: destroys data!)
	@echo "$(RED)⚠ WARNING: This will destroy all data!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker compose down -v; \
		echo "$(GREEN)✓ Cleanup complete$(NC)"; \
	else \
		echo "$(YELLOW)Cancelled$(NC)"; \
	fi

ps: ## Show running containers
	docker compose ps

stats: ## Show container resource usage
	docker stats --no-stream

pull: ## Pull latest container images
	@echo "$(BLUE)Pulling latest images...$(NC)"
	docker compose pull
	@echo "$(GREEN)✓ Images updated$(NC)"

config: ## Validate docker-compose.yml configuration
	@echo "$(BLUE)Validating configuration...$(NC)"
	docker compose config > /dev/null
	@echo "$(GREEN)✓ Configuration valid$(NC)"

lint: ## Lint docker-compose.yml and YAML files
	@echo "$(BLUE)Linting configuration files...$(NC)"
	@docker compose config > /dev/null && echo "$(GREEN)✓ docker-compose.yml syntax valid$(NC)" || (echo "$(RED)✗ docker-compose.yml syntax invalid$(NC)"; exit 1)
	@if command -v yamllint >/dev/null 2>&1; then \
		find . -name "*.yml" -o -name "*.yaml" | xargs yamllint --no-warnings || echo "$(YELLOW)⚠ yamllint not configured$(NC)"; \
	else \
		echo "$(YELLOW)⚠ yamllint not installed$(NC)"; \
	fi
	@echo "$(GREEN)✓ Lint complete$(NC)"

test-claude: ## Run tests for Claude Code services
	@echo "$(BLUE)Running Claude Code service tests...$(NC)"
	@docker compose --profile claude-code ps | grep -q "claude-code" && echo "$(GREEN)✓ Claude Code services are running$(NC)" || (echo "$(RED)✗ Claude Code services not running$(NC)"; exit 1)
	@echo "$(BLUE)Testing Claude Code API health...$(NC)"
	@docker compose exec -T claude-code curl -f http://localhost:8081/health >/dev/null 2>&1 && echo "$(GREEN)✓ Claude Code API healthy$(NC)" || echo "$(YELLOW)⚠ Claude Code API not responding$(NC)"
	@docker compose exec -T claude-code-ui curl -f http://localhost:3000/health >/dev/null 2>&1 && echo "$(GREEN)✓ Claude Code UI healthy$(NC)" || echo "$(YELLOW)⚠ Claude Code UI not responding$(NC)"
	@docker compose exec -T claude-code-auth curl -f http://localhost:8080/health >/dev/null 2>&1 && echo "$(GREEN)✓ Claude Code Auth healthy$(NC)" || echo "$(YELLOW)⚠ Claude Code Auth not responding$(NC)"
	@echo "$(GREEN)✓ Claude Code tests complete$(NC)"

lint-claude: ## Lint Claude Code docker-compose configuration
	@echo "$(BLUE)Linting Claude Code configuration...$(NC)"
	@docker compose -f services/ai-codeassist/claude-code/claude-code/docker-compose.claude-code.yml config > /dev/null && echo "$(GREEN)✓ Claude Code docker-compose.yml syntax valid$(NC)" || (echo "$(RED)✗ Claude Code docker-compose.yml syntax invalid$(NC)"; exit 1)
	@if command -v yamllint >/dev/null 2>&1; then \
		yamllint services/ai-codeassist/claude-code/claude-code/docker-compose.claude-code.yml || echo "$(YELLOW)⚠ yamllint issues found$(NC)"; \
	else \
		echo "$(YELLOW)⚠ yamllint not installed$(NC)"; \
	fi
	@echo "$(GREEN)✓ Claude Code lint complete$(NC)"
