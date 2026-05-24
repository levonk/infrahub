# RustFS Service Makefile
# Part of the LocalNet development environment

.PHONY: help up down logs health clean test

# Default target
help: ## Show this help message
	@echo "RustFS Service Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

up: ## Start RustFS service
	@echo "🚀 Starting RustFS service..."
	cd ../../../ && just up-cloud-rustfs

down: ## Stop RustFS service
	@echo "🛑 Stopping RustFS service..."
	cd ../../../ && just down-cloud-rustfs

logs: ## Show RustFS service logs
	@echo "📋 Showing RustFS logs..."
	docker logs -f localnet-rustfs

health: ## Check RustFS service health
	@echo "🏥 Checking RustFS health..."
	docker exec localnet-rustfs curl -f http://127.0.0.1:9000/health
	docker exec localnet-rustfs curl -f http://127.0.0.1:9001/rustfs/console/health

status: ## Show RustFS container status
	@echo "📊 RustFS container status:"
	docker ps --filter "name=localnet-rustfs" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

shell: ## Open shell in RustFS container
	@echo "🐚 Opening shell in RustFS container..."
	docker exec -it localnet-rustfs /bin/sh

clean: ## Clean up RustFS data and logs
	@echo "🧹 Cleaning RustFS data and logs..."
	@if [ -d "./data" ]; then \
		echo "Removing data directory..."; \
		rm -rf ./data; \
	fi
	@if [ -d "./logs" ]; then \
		echo "Removing logs directory..."; \
		rm -rf ./logs; \
	fi
	@echo "✅ Cleanup complete"

init: ## Initialize RustFS data directories
	@echo "📁 Initializing RustFS directories..."
	@mkdir -p ./data ./logs
	@echo "✅ Directories created"
	@echo "⚠️  Remember to set proper permissions (chown -R 10001:10001 ./data ./logs)"

test: ## Run RustFS health tests
	@echo "🧪 Running RustFS health tests..."
	@./healthcheck/check-health.sh

config: ## Show current configuration
	@echo "⚙️  RustFS Configuration:"
	@echo "=================="
	@if [ -f ".env" ]; then \
		grep -E '^CLOUD_RUSTFS_' .env || true; \
	else \
		echo "No .env file found. Use env.example as template."; \
	fi

version: ## Show RustFS version
	@echo "📦 RustFS version:"
	@docker exec localnet-rustfs rustfs --version || echo "Unable to get version"

# Integration with localnet justfile
build: ## Build RustFS service (placeholder)
	@echo "🔨 RustFS uses pre-built images from Docker Hub"
	@echo "To build from source, see: https://github.com/rustfs/rustfs"

# Development helpers
dev-setup: ## Set up development environment
	@echo "🛠️  Setting up RustFS development environment..."
	@cp env.example .env
	@$(MAKE) init
	@echo "✅ Development environment ready"
	@echo "📝 Edit .env to customize configuration"

# Production helpers
prod-setup: ## Set up production environment
	@echo "🏭 Setting up RustFS production environment..."
	@echo "⚠️  Remember to:"
	@echo "1. Change default credentials in .env"
	@echo "2. Configure TLS certificates"
	@echo "3. Set up proper backup strategy"
	@echo "4. Configure monitoring and alerting"
