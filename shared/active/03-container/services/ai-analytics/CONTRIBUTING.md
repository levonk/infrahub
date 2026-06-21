# Contributing to AI Analytics Pipeline

Thank you for your interest in contributing to the AI Analytics Pipeline! This document provides guidelines for contributing to the project.

## License and Dual Licensing

This project is dual-licensed:

- **AGPL 3.0** for open-source use
- **Commercial license** for multi-tenant, white-label, or proprietary use

### Open Source Contributions

All contributions to the open-source version are licensed under AGPL 3.0. By contributing, you agree that your contributions will be licensed under the same terms.

### Commercial Licensing

If you need to use this project under a commercial license (for multi-tenant deployments, white-labeling, or proprietary use), please contact licensing@levonk.com.

## Contributor License Agreement (CLA)

For significant contributions, we require a Contributor License Agreement (CLA). This helps us:

- Verify that you have the right to contribute the code
- Ensure the project can continue to be distributed under the chosen license
- Protect the project and its users from legal issues

### CLA Process

1. Submit your contribution via pull request
2. If your contribution is significant, we will send you a CLA to sign
3. Once the CLA is signed, we will review and merge your contribution

## Development Setup

### Prerequisites

- Docker and Docker Compose
- Python 3.11+ (for local development)
- Node.js 20+ (for dashboard development)
- Git

### Setting Up the Development Environment

```bash
# Clone the repository
git clone https://github.com/levonk/ai-analytics-pipeline.git
cd ai-analytics-pipeline

# Copy environment template
cp .env.example .env

# Start development services
docker-compose up -d

# Run database migrations
docker-compose exec analytics python scripts/migrate.py

# Verify installation
curl http://localhost:8080/health
```

## Code Style and Standards

### Python Code

- Follow PEP 8 style guidelines
- Use type hints for all functions
- Write docstrings for all public functions and classes
- Maximum line length: 100 characters
- Use `black` for formatting
- Use `flake8` for linting
- Use `mypy` for type checking

### JavaScript/TypeScript Code

- Follow the existing code style in the dashboard project
- Use ESLint and Prettier for formatting
- Write JSDoc comments for public APIs
- Use TypeScript for all new code

### Git Commit Messages

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
feat: add user attribution tracking
fix: resolve memory leak in collector
docs: update API documentation
refactor: simplify queue processing
test: add integration tests for API
chore: update dependencies
```

## Testing

### Running Tests

```bash
# Run all tests
docker-compose exec analytics pytest

# Run specific test file
docker-compose exec analytics pytest tests/test_collector.py

# Run with coverage
docker-compose exec analytics pytest --cov=analytics --cov-report=html
```

### Test Coverage

We aim for 80%+ test coverage. All new features must include:

- Unit tests for core logic
- Integration tests for API endpoints
- End-to-end tests for critical user flows

## Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests and linting
5. Commit your changes (following conventional commits)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a pull request

### Pull Request Checklist

- [ ] Code follows project style guidelines
- [ ] Tests pass locally
- [ ] New features include tests
- [ ] Documentation is updated
- [ ] Commit messages follow conventional commits
- [ ] CLA is signed (if required)

## Reporting Issues

When reporting issues, please include:

- A clear description of the problem
- Steps to reproduce the issue
- Expected behavior
- Actual behavior
- Environment details (OS, Python version, etc.)
- Relevant logs or error messages

## Feature Requests

For feature requests, please:

- Check existing issues to avoid duplicates
- Provide a clear use case
- Explain why the feature is needed
- Suggest a possible implementation (if you have ideas)

## Code of Conduct

Be respectful and constructive in all interactions. We are committed to providing a welcoming and inclusive environment for all contributors.

## Questions?

If you have questions about contributing, please:

- Open an issue on GitHub
- Contact the maintainers
- Join our community discussions

Thank you for contributing to the AI Analytics Pipeline!
