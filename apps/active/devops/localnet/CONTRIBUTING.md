# Contributing to Home Lab In-a-Box

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow

## How to Contribute

### Reporting Issues

- Check existing issues first
- Provide clear reproduction steps
- Include system information (OS, Docker version, etc.)
- Attach relevant logs

### Suggesting Features

- Open an issue with the `enhancement` label
- Describe the use case and benefits
- Consider implementation complexity

### Submitting Changes

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test thoroughly
5. Commit with clear messages
6. Push to your fork
7. Open a Pull Request

### Pull Request Guidelines

- Follow existing code style
- Update documentation
- Add tests if applicable
- Keep changes focused and atomic
- Reference related issues

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/homelab-in-a-box.git
cd homelab-in-a-box

# Configure environment
cp .env.example .env
nano .env

# Start services
make up

# Run tests
make test
```

## Testing

- Test all changes locally
- Verify health checks pass
- Run integration tests
- Check for breaking changes

## Documentation

- Update README.md for user-facing changes
- Update docs/ for technical changes
- Add inline comments for complex logic
- Update CHANGELOG.md

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.
