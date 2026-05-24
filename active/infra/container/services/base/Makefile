PROJECT_DIR := ../..
.PHONY: help build up down restart logs logs-follow lint clean clean-all shell shell-alpine shell-debian health-check quality

.DEFAULT_GOAL := help

BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m

COMPOSE_FILE := docker-compose.base.yml
ENSURE_NETWORK := ../../scripts/ensure-network.py
ROOT_DIR := $(CURDIR)
PROJECT_DIR := $(abspath $(ROOT_DIR)/../..)
export LOCALNET_DIR := $(PROJECT_DIR)

ifeq (,$(wildcard .env))
ENV_ARGS :=
else
ENV_ARGS := --env-file ./.env
endif

ifeq (,$(wildcard ../../.env))
ENV_ARGS +=
else
ENV_ARGS += --env-file ../../.env
endif

COMPOSE := docker compose --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE) $(ENV_ARGS)
export CACHE_BASE_PATH=/opt/localnet/volumes/cache

help: ## Show available targets
	@echo "$(BLUE)LocalNet Base Images$(NC)"
	@echo ""
	@echo "This Makefile builds and manages the hardened Debian/Alpine base images."
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-16s$(NC) %s\n", $$1, $$2}'

build: ## Build both base images
	@echo "$(BLUE)Building base images...$(NC)"
	@$(COMPOSE) build
	@echo "$(GREEN)✓ base images built$(NC)"

base-up: ## Build and run base-dev and dependencies
	@$(ENSURE_NETWORK) --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE)
	@echo "$(BLUE)Building base01 (debian/alpine/sidecar)...$(NC)"
	@$(COMPOSE) --profile base01 build
	@echo "$(BLUE)Building base02 (debnix)...$(NC)"
	@$(COMPOSE) --profile base02 build
	@echo "$(BLUE)Building base03 (dev)...$(NC)"
	@$(COMPOSE) --profile base03 build
	@echo "$(BLUE)Recreating nix-sidecar...$(NC)"
	@$(COMPOSE) up -d --force-recreate nix-sidecar
	@echo "$(BLUE)Starting base-dev...$(NC)"
	@$(COMPOSE) --profile base03 up -d base-dev

down: ## Stop and remove base containers
	@$(COMPOSE) down

restart: ## Restart base containers
	@$(ENSURE_NETWORK) --project-directory $(PROJECT_DIR) -f $(COMPOSE_FILE)
	@$(COMPOSE) restart

logs: ## Tail last 200 lines for both containers
	@$(COMPOSE) logs --tail=200

logs-follow: ## Follow logs for both containers
	@$(COMPOSE) logs -f

shell: shell-alpine ## Default shell target (alpine)

shell-alpine: ## Open shell in base-alpine container
	@$(COMPOSE) exec base-alpine /bin/sh

shell-debian: ## Open shell in base-debian container
	@$(COMPOSE) exec base-debian /bin/bash

health-check: ## Simple smoke check inside containers
	@echo "$(BLUE)Checking base-alpine user & perms...$(NC)"
	@$(COMPOSE) exec base-alpine id
	@$(COMPOSE) exec base-alpine ls -ld /etc/service /healthcheck /tmp
	@echo "$(BLUE)Checking base-debian user & perms...$(NC)"
	@$(COMPOSE) exec base-debian id
	@$(COMPOSE) exec base-debian ls -ld /etc/service /healthcheck /tmp

lint: ## Run quality gates (yamllint, markdownlint, hadolint, checkov, trivy)
	@./scripts/run-quality-checks.sh

quality: lint ## Alias for lint/quality script

clean: ## Remove containers and networks
	@$(COMPOSE) down --remove-orphans

clean-all: ## Remove containers, networks, volumes
	@$(COMPOSE) down -v --remove-orphans
