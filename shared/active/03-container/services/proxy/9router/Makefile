.PHONY: help build up down logs restart clean shell

help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

build: ## Build the Docker image
	docker-compose build

up: ## Start the service
	docker-compose up -d

down: ## Stop the service
	docker-compose down

logs: ## View service logs
	docker-compose logs -f

restart: ## Restart the service
	docker-compose restart

clean: ## Remove containers, volumes, and images
	docker-compose down -v
	docker-compose rm -f
	docker rmi localnet-9router

shell: ## Open a shell in the running container
	docker-compose exec 9router sh

ps: ## Show running containers
	docker-compose ps

stats: ## Show container resource usage
	docker stats localnet-9router
