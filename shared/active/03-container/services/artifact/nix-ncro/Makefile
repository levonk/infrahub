# Makefile for ncro (Nix Cache Route Optimizer)
# Handles building Nix images and loading into Docker

PROJECT_DIR := ../../..
.PHONY: build build-debug help clean

help:
	@echo "Available commands:"
	@echo "  make build        - Build the production Docker image"
	@echo "  make build-debug  - Build the debug Docker image"
	@echo "  make clean        - Remove artifacts"

build:
	@echo "Building Production Image (localnet-nix-ncro)..."
	nix build .#docker-prod
	@echo "Loading image into Docker..."
	docker load < result

build-debug:
	@echo "Building Debug Image (localnet-nix-ncro-debug)..."
	nix build .#docker-debug
	@echo "Loading image into Docker..."
	docker load < result

clean:
	rm -f result
