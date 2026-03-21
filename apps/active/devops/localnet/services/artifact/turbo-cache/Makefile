.PHONY: help build up down restart logs test security-scan clean shell

# Default target
help: ## Show this help
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Build targets
build: ## Build the turbo-cache Docker image
	docker build -t localnet-turbo-cache:latest -f docker/Dockerfile.turbo-cache .

build-nc: ## Build without cache
	docker build --no-cache -t localnet-turbo-cache:latest -f docker/Dockerfile.turbo-cache .

# Docker Compose targets
up: ## Start turbo-cache service
	docker compose -f docker-compose.turbo-cache.yml up -d

down: ## Stop turbo-cache service
	docker compose -f docker-compose.turbo-cache.yml down

restart: ## Restart turbo-cache service
	docker compose -f docker-compose.turbo-cache.yml restart

logs: ## Show turbo-cache logs
	docker compose -f docker-compose.turbo-cache.yml logs -f

logs-tail: ## Show last 100 lines of logs
	docker compose -f docker-compose.turbo-cache.yml logs --tail=100

# Testing targets
test: ## Run tests
	@echo "Running turbo-cache tests..."
	@echo "TODO: Implement test suite"

test-verbose: ## Run tests with verbose output
	@echo "Running turbo-cache tests (verbose)..."
	@echo "TODO: Implement test suite"

# Security targets
security-scan: ## Run security scans on the image
	@echo "Running security scans..."
	trivy image localnet-turbo-cache:latest || echo "Trivy not installed, skipping scan"
	hadolint docker/Dockerfile.turbo-cache || echo "Hadolint not installed, skipping lint"

# Health check targets
health: ## Check service health
	@echo "Checking turbo-cache health..."
	docker compose -f docker-compose.turbo-cache.yml exec turbo-cache /usr/local/bin/check-health.sh

shell: ## Open a shell in the container
	docker compose -f docker-compose.turbo-cache.yml exec turbo-cache /bin/sh

# Utility targets
clean: ## Remove stopped containers and unused images
	docker compose -f docker-compose.turbo-cache.yml down -v
	docker system prune -f

clean-all: ## Remove all containers, images, and volumes
	docker compose -f docker-compose.turbo-cache.yml down -v --rmi all
	docker system prune -af

status: ## Show container status
	docker compose -f docker-compose.turbo-cache.yml ps

# Development targets
dev-setup: ## Set up development environment
	@echo "Setting up development environment..."
	cp .env.example .env
	@echo "Edit .env file with your configuration"

# Integration targets (for use with main localnet stack)
integrate: ## Build and integrate with main localnet stack
	@echo "Building turbo-cache for integration..."
	cd ../../.. && docker compose -f services/artifact/docker-compose.artifact.yml build turbo-cache

integrate-up: ## Start turbo-cache in main localnet stack
	@echo "Starting turbo-cache in main stack..."
	cd ../../.. && docker compose -f services/artifact/docker-compose.artifact.yml up -d turbo-cache

integrate-down: ## Stop turbo-cache in main localnet stack
	@echo "Stopping turbo-cache in main stack..."
	cd ../../.. && docker compose -f services/artifact/docker-compose.artifact.yml down turbo-cache
