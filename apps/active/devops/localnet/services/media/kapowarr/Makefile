# Makefile for Kapowarr
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
	docker-compose logs -f kapowarr

# Health Check
health-check:
	@echo "Checking health of kapowarr..."
	docker inspect --format='{{json .State.Health}}' localnet-media-kapowarr-standalone

# Clean
clean:
	docker-compose down -v
