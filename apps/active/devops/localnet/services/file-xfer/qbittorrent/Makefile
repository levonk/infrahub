# Makefile for qBittorrent (file-xfer)
# Handles Docker Compose lifecycle and optional Nix image builds

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
	@echo "Building Production Image (qbittorrent)..."
	nix build .#docker-prod || (echo "Nix build optional; skipping if not configured"; exit 0)
	@if [ -f result ]; then echo "Loading image into Docker..."; docker load < result; fi

# Build Debug Image (With Tools)
build-debug:
	@echo "Building Debug Image (qbittorrent-debug)..."
	nix build .#docker-debug || (echo "Nix debug build optional; skipping if not configured"; exit 0)
	@if [ -f result ]; then echo "Loading debug image into Docker..."; docker load < result; fi

# Start Services
up:
	docker compose up -d

# Stop Services
down:
	docker compose down

# View Logs
logs:
	docker compose logs -f qbittorrent

# Health Check
health-check:
	@echo "Checking health of qbittorrent..."
	docker inspect --format='{{json .State.Health}}' localnet-file-xfer-qbittorrent || \
		curl -f "http://localhost:${QBIT_WEB_CONTAINER_PORT:-8701}/" || \
		( echo "Health check failed"; exit 1 )

# Clean
clean:
	rm -f result
	docker-compose down -v
