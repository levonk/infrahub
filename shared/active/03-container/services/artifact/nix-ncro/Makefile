# Makefile for ncro
# Handles building Nix images and managing Docker services

PROJECT_DIR := ../../..
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
	@echo "Building Production Image (ncro)..."
	nix build .#docker-prod
	@echo "Loading image into Docker..."
	docker load < result

build-debug:
	@echo "Building Debug Image (ncro-debug)..."
	nix build .#docker-debug
	@echo "Loading image into Docker..."
	docker load < result

up:
	docker-compose --project-directory $(PROJECT_DIR) up -d

down:
	docker-compose --project-directory $(PROJECT_DIR) down

logs:
	docker-compose --project-directory $(PROJECT_DIR) logs -f ncro

health-check:
	@echo "Checking health of ncro..."
	docker inspect --format='{{json .State.Health}}' localnet-proxy-ncro

clean:
	rm -f result
	docker-compose --project-directory $(PROJECT_DIR) down -v
