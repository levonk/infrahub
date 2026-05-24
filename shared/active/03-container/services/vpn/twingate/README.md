# Twingate VPN - Twingate Connector Service
# Generated from boilerplate template

## Overview

Twingate Connector Service

This service runs the **Twingate Connector** to provide secure remote access to your private network.

## Quick Start

### Prerequisites

- Docker
- Docker Compose
- Twingate Account (Tenant URL, Access Token, Refresh Token)

### Build and Run

```bash
# 1. Start the service
make up

# 2. Check health
make health-check
```

## Configuration

### Environment Variables

| Variable | Description |
|----------|-------------|
| `TENANT_URL` | Your Twingate Tenant URL |
| `ACCESS_TOKEN` | Twingate Connector Access Token |
| `REFRESH_TOKEN` | Twingate Connector Refresh Token |
| `TWINGATE_LABEL_HOSTNAME` | Hostname label for the connector |

## Project Structure

- `docker-compose.yml`: Orchestrates the Twingate connector service.
- `Makefile`: Helper commands.
