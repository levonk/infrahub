# Makefile for MediaManager
# Handles managing Docker services

PROJECT_DIR := ../../..
.PHONY: up down logs health-check clean help

# Default target
help:
	@echo "Available commands:"
	@echo "  make up           - Start services via Docker Compose"
	@echo "  make down         - Stop services"
	@echo "  make logs         - View service logs"
	@echo "  make health-check - Check service health"
	@echo "  make clean        - Remove build artifacts"

# Start Services
up:
	docker-compose --project-directory $(PROJECT_DIR) up -d

# Stop Services
down:
	docker-compose --project-directory $(PROJECT_DIR) down

# View Logs
logs:
	docker-compose --project-directory $(PROJECT_DIR) logs -f mediamanager

# Health Check
health-check:
	@echo "Checking health of mediamanager..."
	docker inspect --format='{{json .State.Health}}' localnet-media-mediamanager-standalone

# Clean
clean:
	docker-compose --project-directory $(PROJECT_DIR) down -v
