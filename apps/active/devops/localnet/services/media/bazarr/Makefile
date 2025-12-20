# Makefile for Bazarr
# Handles managing Docker services

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
	docker-compose up -d

# Stop Services
down:
	docker-compose down

# View Logs
logs:
	docker-compose logs -f bazarr

# Health Check
health-check:
	@echo "Checking health of bazarr..."
	docker inspect --format='{{json .State.Health}}' localnet-media-bazarr-standalone

# Clean
clean:
	docker-compose down -v
