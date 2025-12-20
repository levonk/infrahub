# Makefile for bentopdf
# Handles building Nix images and managing Docker services

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
	@echo "Building Production Image ()..."
	nix build .#docker-prod
	@echo "Loading image into Docker..."
	docker load < result

# Build Debug Image (With Tools)
build-debug:
	@echo "Building Debug Image (-debug)..."
	nix build .#docker-debug
	@echo "Loading image into Docker..."
	docker load < result

# Start Services
up:
	docker-compose up -d

# Stop Services
down:
	docker-compose down

# View Logs
logs:
	docker-compose logs -f 

# Health Check
health-check:
	@echo "Checking health of ..."
	docker inspect --format='{{json .State.Health}}' 

# Clean
clean:
	rm -f result
	docker-compose down -v
