# AI Analytics Pipeline

A comprehensive analytics pipeline for tracking AI usage across multiple dimensions: company clients, AI clients (Claude Code, Codex, Pi, Devin, etc.), teams, pipeline stages, AI model suppliers (Anthropic, OpenAI, Google, Microsoft, AWS, OpenRouter, etc.), models, and input types (text/chat, image, audio, etc.).

## Architecture

This project implements a dual-architecture analytics system:

- **Open-source version**: 2-service architecture (proxy + web) for single-tenant deployments
- **Commercial version**: 4-service architecture (proxy + collector + analytics + web) for multi-tenant scale

## Project Structure

```
ai-analytics/
├── collectors/          # Data collectors for various sources
├── queue/              # Message queue for async processing
├── processor/          # Background processing engine
├── database/           # SQLite schema and migrations
├── api/                # REST API for data access
├── config/             # Configuration files
└── docs/               # Documentation
```

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Python 3.11+ (for local development)
- Node.js 20+ (for dashboard)

### Development Setup

```bash
# Copy environment template
cp .env.example .env

# Start services
docker-compose up -d

# Run migrations
docker-compose exec analytics python scripts/migrate.py

# Verify health
curl http://localhost:8080/health
```

## License

This project is dual-licensed:

- **AGPL 3.0** for open-source use
- **Commercial license** for multi-tenant, white-label, or proprietary use

See [LICENSE.md](LICENSE.md) for details.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines and CLA requirements.

## Documentation

- [Architecture Overview](docs/architecture.md)
- [API Reference](docs/api.md)
- [Deployment Guide](docs/deployment.md)
