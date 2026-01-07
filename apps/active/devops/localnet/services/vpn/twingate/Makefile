# Makefile for Twingate VPN
# Handles building Nix images and managing Docker services

PROJECT_DIR := ../../..
.PHONY: build build-debug up down logs health-check clean help

# Default target
help:
	@echo "Available commands:"
	@echo "  make build        - Build the production Docker image (minimal)"
	@echo "  make build-debug  - Build the debug Docker image (with tools)"
	@echo "  make up           - Start services via Docker Compose"
	@echo "  make down         - Stop services"
	@echo "  make logs         - View service logs"
	@echo "  make health-check - Check service health"
	@echo "  make clean        - Remove build artifacts"

# Build Production Image (Minimal)
build:
	@echo "Building Production Image (twingate-vpn)..."
	nix build .#docker-prod
	@echo "Loading image into Docker..."
	docker load < result

# Build Debug Image (With Tools)
build-debug:
	@echo "Building Debug Image (twingate-vpn-debug)..."
	nix build .#docker-debug
	@echo "Loading image into Docker..."
	docker load < result

# Start Services
up:
	docker-compose --project-directory $(PROJECT_DIR) up -d

# Stop Services
down:
	docker-compose --project-directory $(PROJECT_DIR) down

# View Logs
logs:
	docker-compose --project-directory $(PROJECT_DIR) logs -f twingate-vpn

# Health Check
health-check:
	@echo "Checking health of twingate-vpn..."
	docker inspect --format='{{json .State.Health}}' twingate-vpn

# Clean
clean:
	rm -f result
	docker-compose --project-directory $(PROJECT_DIR) down -v
