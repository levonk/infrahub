PROJECT_DIR := ../..
.PHONY: help build up down restart status logs logs-follow logs-dnsdist logs-coredns logs-dnscrypt health-check lint clean clean-all shell shell-dnsdist shell-coredns shell-dnscrypt blocklists-refresh blocklists-view

.DEFAULT_GOAL := help

BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m

COMPOSE_FILE := docker-compose.dns.yml
ENV_ARGS :=

ENSURE_NETWORK := ../../scripts/ensure-network.py

ifeq (,$(wildcard .env))
ENV_ARGS +=
else
ENV_ARGS += --env-file ./.env
endif

ifeq (,$(wildcard ../../.env))
ENV_ARGS +=
else
ENV_ARGS += --env-file ../../.env
endif

COMPOSE := docker compose --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE) $(ENV_ARGS)

help: ## Show available targets
	@echo "$(BLUE)DNS Service Stack - Build System$(NC)"
	@echo ""
	@echo "This Makefile manages the DNS stack (dnsdist, CoreDNS, dnscrypt-proxy, blocklist compiler)."
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""

build: ## Build local Docker images for the DNS stack
	@echo "$(BLUE)Building DNS service images...$(NC)"
	@$(COMPOSE) build
	@echo "$(GREEN)✓ Images built$(NC)"

up: ## Start DNS services in detached mode
	@echo "$(BLUE)Starting DNS services...$(NC)"
	@$(ENSURE_NETWORK) --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE)
	@$(COMPOSE) up -d
	@echo "$(GREEN)✓ Services started$(NC)"
	@echo "Run 'make health-check' once the containers have finished booting."

down: ## Stop DNS services and remove containers
	@echo "$(YELLOW)Stopping DNS services...$(NC)"
	@$(COMPOSE) down
	@echo "$(GREEN)✓ Services stopped$(NC)"

restart: ## Restart DNS services
	@echo "$(YELLOW)Restarting DNS services...$(NC)"
	@$(ENSURE_NETWORK) --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE)
	@$(COMPOSE) restart dnsdist coredns dnscrypt-proxy
	@echo "$(GREEN)✓ Services restarted$(NC)"

status: ## Show container status
	@echo "$(BLUE)DNS container status$(NC)"
	@$(COMPOSE) ps

logs: ## Tail last 200 lines from all DNS containers
	@$(COMPOSE) logs --tail=200

logs-follow: ## Follow logs for all DNS containers
	@$(COMPOSE) logs -f

logs-dnsdist: ## Show dnsdist logs
	@$(COMPOSE) logs --tail=200 dnsdist

logs-coredns: ## Show CoreDNS logs
	@$(COMPOSE) logs --tail=200 coredns

logs-dnscrypt: ## Show dnscrypt-proxy logs
	@$(COMPOSE) logs --tail=200 dnscrypt-proxy

health-check: ## Run DNS health probes inside the stack
	@echo "$(BLUE)Inspecting container status...$(NC)"
	@$(COMPOSE) ps
	@echo ""
	@echo "$(BLUE)Running dnsdist resolution probe...$(NC)"
	@DNSDIST_OUTPUT="$$( $(COMPOSE) exec dnsdist dig +short health.check.local @127.0.0.1 2>/dev/null )"; \
	if [ -n "$$DNSDIST_OUTPUT" ]; then \
		echo "$(GREEN)✓ dnsdist responded to health.check.local$(NC)"; \
	else \
		echo "$(RED)✗ dnsdist failed to resolve health.check.local$(NC)"; \
	fi
	@echo "$(BLUE)Validating dnscrypt-proxy upstream resolution...$(NC)"
	@$(COMPOSE) exec dnscrypt-proxy dnscrypt-proxy -resolve cloudflare.com -config /etc/dnscrypt-proxy/dnscrypt-proxy.toml >/dev/null 2>&1 && \
		echo "$(GREEN)✓ dnscrypt-proxy resolved cloudflare.com$(NC)" || \
		echo "$(RED)✗ dnscrypt-proxy could not resolve cloudflare.com$(NC)"
	@echo "$(BLUE)Checking blocklist artifacts...$(NC)"
	@$(COMPOSE) exec dnsdist test -f /etc/dnsdist/blocklists/blocklist.cdb && \
		echo "$(GREEN)✓ Compiled blocklist available$(NC)" || \
		echo "$(RED)✗ Compiled blocklist missing$(NC)"

lint: ## Validate docker-compose configuration
	@echo "$(BLUE)Linting docker-compose --project-directory $(PROJECT_DIR) 
	@$(COMPOSE) config >/dev/null && echo "$(GREEN)✓ docker-compose --project-directory $(PROJECT_DIR) configuration valid$(NC)"
	@if command -v yamllint >/dev/null 2>&1; then \
		yamllint $(COMPOSE_FILE); \
	else \
		echo "$(YELLOW)⚠ yamllint not installed$(NC)"; \
	fi

clean: ## Remove containers and networks (keep volumes)
	@echo "$(RED)Removing DNS containers and networks...$(NC)"
	@$(COMPOSE) down --remove-orphans
	@docker network prune -f >/dev/null
	@echo "$(GREEN)✓ Containers and networks removed$(NC)"

clean-all: ## Remove containers, networks, and volumes (data loss!)
	@echo "$(RED)⚠ This will delete all DNS volumes and data$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; echo ""; \
	if echo "$$REPLY" | grep -Eq '^[Yy]$$'; then \
		$(COMPOSE) down -v --remove-orphans; \
		docker network prune -f >/dev/null; \
		echo "$(GREEN)✓ All DNS volumes removed$(NC)"; \
	else \
		echo "$(YELLOW)Cancelled$(NC)"; \
	fi

shell: shell-dnsdist ## Open a shell in the dnsdist container (default)

shell-dnsdist: ## Open a shell in the dnsdist container
	@$(COMPOSE) exec dnsdist /bin/sh

shell-coredns: ## Open a shell in the CoreDNS container
	@$(COMPOSE) exec coredns /bin/sh

shell-dnscrypt: ## Open a shell in the dnscrypt-proxy container
	@$(COMPOSE) exec dnscrypt-proxy /bin/sh

blocklists-refresh: ## Rebuild DNS blocklists using compiler container
	@echo "$(BLUE)Rebuilding DNS blocklists...$(NC)"
	@$(COMPOSE) run --rm blocklist-compiler
	@echo "$(GREEN)✓ Blocklists rebuilt$(NC)"

blocklists-view: ## List compiled blocklist entries summary
	@$(COMPOSE) exec dnsdist ls -lh /etc/dnsdist/blocklists
