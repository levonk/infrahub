.PHONY: help up down restart logs logs-follow health-check flush-cache backup restore clean

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

test: ## Run integration tests
	@echo "$(BLUE)Running integration tests...$(NC)"
	@./tests/dns-leak-test.sh
	@./tests/ntp-accuracy-test.sh
	@./tests/proxy-chain-test.sh
	@echo "$(GREEN)✓ Tests complete$(NC)"

update-blocklists: ## Update DNS/web blocklists
	@echo "$(BLUE)Updating blocklists...$(NC)"
	docker compose exec dnsdist /blocklists/update-blocklists.sh
	@echo "$(GREEN)✓ Blocklists updated$(NC)"

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
