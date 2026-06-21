# AI Analytics Pipeline - Makefile
# Development and build scripts

.PHONY: help build test lint clean install up down logs migrate

# Default target
help:
	@echo "AI Analytics Pipeline - Development Commands"
	@echo ""
	@echo "Available targets:"
	@echo "  make build      - Build all services"
	@echo "  make test       - Run tests"
	@echo "  make lint       - Run linting"
	@echo "  make clean      - Clean build artifacts"
	@echo "  make install    - Install dependencies"
	@echo "  make up         - Start all services"
	@echo "  make down       - Stop all services"
	@echo "  make logs       - View service logs"
	@echo "  make migrate    - Run database migrations"
	@echo "  make shell      - Open shell in service"
	@echo ""

# Build all services
build:
	@echo "Building all services..."
	docker-compose -f docker-compose.analytics.yml build

# Run tests
test:
	@echo "Running tests..."
	docker-compose -f docker-compose.analytics.yml exec analytics-api pytest

# Run linting
lint:
	@echo "Running linting..."
	docker-compose -f docker-compose.analytics.yml exec analytics-api flake8
	docker-compose -f docker-compose.analytics.yml exec analytics-api mypy

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	docker-compose -f docker-compose.analytics.yml down -v
	rm -rf __pycache__ .pytest_cache .coverage htmlcov

# Install dependencies
install:
	@echo "Installing dependencies..."
	docker-compose -f docker-compose.analytics.yml exec analytics-api pip install -r requirements.txt

# Start all services
up:
	@echo "Starting all services..."
	docker-compose -f docker-compose.analytics.yml up -d

# Stop all services
down:
	@echo "Stopping all services..."
	docker-compose -f docker-compose.analytics.yml down

# View service logs
logs:
	docker-compose -f docker-compose.analytics.yml logs -f

# Run database migrations
migrate:
	@echo "Running database migrations..."
	docker-compose -f docker-compose.analytics.yml exec analytics-api python scripts/migrate.py

# Open shell in API service
shell:
	docker-compose -f docker-compose.analytics.yml exec analytics-api /bin/bash

# Development setup
dev-setup:
	@echo "Setting up development environment..."
	cp .env.example .env
	@echo "Please edit .env with your configuration"
	@echo "Then run: make up && make migrate"
