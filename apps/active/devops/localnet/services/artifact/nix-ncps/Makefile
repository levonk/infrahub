# Makefile for NCPS
# Handles building Nix images and managing Docker services

.PHONY: build build-debug up down logs health-check clean help

help:
	@echo "Available commands:"
	@echo "  make build        - Build the production Docker image"
	@echo "  make build-debug  - Build the debug Docker image"
	@echo "  make up           - Start services"
	@echo "  make down         - Stop services"
	@echo "  make logs         - View logs"
	@echo "  make health-check - Check health"
	@echo "  make clean        - Remove artifacts"

build:
	@echo "Building Production Image (ncps)..."
	nix build .#docker-prod
	@echo "Loading image into Docker..."
	docker load < result

build-debug:
	@echo "Building Debug Image (ncps-debug)..."
	nix build .#docker-debug
	@echo "Loading image into Docker..."
	docker load < result

up:
	docker-compose up -d

down:
	docker-compose down

logs:
	docker-compose logs -f ncps

health-check:
	@echo "Checking health of ncps..."
	docker inspect --format='{{json .State.Health}}' localnet-proxy-ncps

clean:
	rm -f result
	docker-compose down -v
