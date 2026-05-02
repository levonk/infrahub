# Jellyseerr - Docker Service
# Generated from boilerplate template

## Overview

Request manager for Jellyfin.

## Features

- **Request Manager**: Manage media requests
- **Health Checks**: Built-in health monitoring
- **Logging**: Structured JSON logging

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Localnet infrastructure running

### Build and Run

```bash
# Start the service
make up

# Check health
make health-check

# View logs
make logs
```

### Development

```bash
# Clean up
make clean
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SERVICE_NAME` | Service identifier | `jellyfintv` |
| `SERVICE_PORT` | Port the service listens on | `5055` |
| `NODE_ENV` | Environment | `production` |

### Ports

- **5055**: Main service port

### Health Checks

- **Endpoint**: `/status`
- **Interval**: 30 seconds
- **Timeout**: 10 seconds
- **Retries**: 3

## Build System

The `Makefile` wraps Docker commands for convenience:

- `make up`: Runs `docker-compose up`.
- `make down`: Runs `docker-compose down`.
- `make logs`: View logs.
- `make health-check`: Check container health.

## Project Structure

- `docker-compose.yml`: Orchestrates the service.
- `Makefile`: Helper commands.

