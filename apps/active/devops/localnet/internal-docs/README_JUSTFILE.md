# LocalNet Development Environment - Now with Just

## Quick Start

The LocalNet development environment now uses **Just** instead of Make for better cross-platform compatibility and modern features.

### Prerequisites

Install Just: <https://github.com/casey/just#installation>

```bash
# On macOS with Homebrew
brew install just

# On Ubuntu/Debian
sudo apt-get install just

# On Windows with Scoop
scoop install just
```

### Basic Commands

```bash
# Show all available commands
just help

# Start all services
just up

# Stop all services
just down

# View logs
just logs

# Check service health
just health-check

# Clean restart
just clean
```

## Migration Complete

✅ **All Makefile commands migrated to Just**
✅ **Colored output preserved**
✅ **Cross-platform compatibility improved**
✅ **Documentation updated**

See `MIGRATION_SUMMARY.md` for detailed migration information.

## Key Benefits

- **Faster**: Just executes commands more efficiently than Make
- **Cross-platform**: Works consistently on Windows, macOS, and Linux
- **Modern syntax**: Cleaner, more readable task definitions
- **Better dependencies**: Improved task dependency management
- **Active development**: Just is actively maintained and improving

## Need Help?

Run `just help` to see all available commands, or check the comprehensive documentation in `AGENTS.md`.
