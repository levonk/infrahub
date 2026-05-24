# Base Development Environment

A comprehensive development container built on Debian with Nix package manager and an extensive collection of modern development tools. This container provides a complete, reproducible development environment suitable for various programming languages, workflows, and development tasks.

## Architecture

- **Base**: Debian Slim (from `localnet-base-debnix`)
- **Package Management**: Nix (with flakes) for reproducible environments
- **User**: Non-root `cuser` with sudo access
- **Shell**: Zsh with modern enhancements

## Core Development Tools

### Package Managers & Runtime
- **nix**: The Nix package manager for reproducible, declarative package management
- **nodejs**: JavaScript/TypeScript runtime for modern web development
- **python315** & **uv**: Python 3.15 with uv, the modern Python package installer
- **devbox**: Development environment management tool

### Version Control
- **git**: Distributed version control system
- **gh**: GitHub CLI for GitHub interactions
- **glab**: GitLab CLI for GitLab interactions
- **lazygit**: Terminal UI for git operations
- **git-extras**: Additional git utilities
- **git-lfs**: Git Large File Storage support
- **fzf-git-sh**: Fuzzy finder integration for git

## Shell & Terminal Experience

### Modern Shell Environment
- **zsh**: Powerful shell with extensive features
- **zellij**: Modern terminal multiplexer (alternative to tmux)
- **direnv**: Directory-based environment variable management
- **fzf**: Command-line fuzzy finder
- **ripgrep (rg)**: Fast text search tool
- **fd**: User-friendly alternative to `find`
- **bat**: `cat` clone with syntax highlighting and git integration
- **eza**: Modern replacement for `ls`
- **zoxide**: Smart directory navigation
- **rip**: Secure file deletion

### Terminal Enhancements
- **nerd-fonts.jetbrains-mono**: Programming font with icon support
- **tlrc**: TUI for tldr pages
- **pay-respects**: CLI tool for paying respects
- **atuin**: Shell history management with sync
- **sd**: Intuitive find & replace CLI

## Text Editing & IDE Tools

### Editors
- **vim**: Classic text editor
- **neovim**: Modern vim fork with Lua support

### AI Coding Assistants
- **opencode**: Open-source AI coding assistant
- **gemini-cli**: Google's Gemini AI CLI
- **github-copilot-cli**: GitHub Copilot command-line interface
- **cursor-cli**: Cursor AI editor CLI
- **qwen-code**: Qwen AI coding assistant
- **amp-cli**: Amp editor CLI
- **claude-code**: Anthropic's Claude Code CLI
- **claude-code-router**: Router for Claude Code services
- **claude-monitor**: Monitoring tool for Claude Code

### Vim Plugins
- **opencode-nvim**: OpenCode integration for Neovim
- **copilot-vim**: GitHub Copilot integration for Vim
- **claudecode-nvim**: Claude Code integration for Neovim

## Development Infrastructure

### Configuration Management
- **chezmoi**: Dotfile management system
- **universal-ctags**: Universal ctags implementation

### Databases
- **duckdb**: Analytical database system
- **sqlite**: Lightweight SQL database engine

### Web Development
- **tailwindcss_4**: Utility-first CSS framework (v4)
- **tailwindcss-language-server**: LSP for Tailwind CSS
- **vscode-extensions.bradlc.vscode-tailwindcss**: VS Code Tailwind extension
- **vimPlugins.tailwind-tools-nvim**: Tailwind tools for Neovim

### Browser & Testing
- **ungoogled-chromium**: Privacy-focused Chromium browser
- **python313Packages.playwright**: Browser automation framework
- **python313Packages.playwright-stealth**: Stealth mode for Playwright
- **playwright-test**: Playwright testing utilities

### Project Templates
- **python312Packages.copier**: Project templating tool

## File Management & Utilities

### File Managers
- **yazi**: Modern terminal file manager
- **trash-cli**: Command-line trash can (safer than `rm`)

### Archive Tools
- **p7zip**: 7-Zip file archiver
- **unzip**: ZIP extraction utility
- **zip**: ZIP creation utility
- **rsync**: Efficient file synchronization

### System Monitoring
- **htop**: Interactive process viewer
- **btop**: Modern resource monitor
- **bottom**: Modern cross-platform process monitor
- **procs**: Modern replacement for `ps`
- **dust**: Disk usage analyzer with visualization
- **duf**: Disk usage/free utility

## Text Processing & Data Tools

### Text Processing
- **yq-go**: YAML processor (Go implementation)
- **gron**: JSON flattening tool
- **fx**: JSON viewer and processor
- **tokei**: Code statistics tool

### Data Processing
- **jq**: JSON processor and query language
- **sd**: Stream-based find and replace

## Image & Document Processing

### Image Tools
- **imagemagick**: Image manipulation suite
- **chafa**: Terminal image viewer
- **jp2a**: JPEG to ASCII converter

### Document Tools
- **poppler-utils**: PDF utilities

## Comparison & Diff Tools

### Advanced Diff Tools
- **difftastic**: Structural diff tool
- **delta**: Enhanced diff viewer
- **mergiraf**: Smart 3-way merge tool
- **odiff**: Fast diff tool

## Diagramming & Visualization

### Diagram Tools
- **graphviz**: Graph visualization software
- **plantuml**: UML diagram generator
- **mermaid-cli**: Mermaid diagram CLI tool

## Network Tools

### Network Analysis
- **nmap**: Network exploration and security auditing
- **tcpdump**: Network packet analyzer
- **mtr**: Network diagnostic tool (traceroute + ping)
- **whois**: WHOIS client
- **rhash**: Hash calculation tool

## System Essentials

### Core Utilities
- **file**: File type detection utility
- **findutils**: File finding utilities
- **procps**: Process utilities
- **shadow**: Password shadow suite
- **gosu**: Tool for running commands as different user

### Security & Certificates
- **cacert**: CA certificates for HTTPS connections

## Development Environment Setup

### Nix Configuration
The container includes a Nix flake configuration (`/home/cuser/project/flake.nix`) that defines:

- **nixpkgs**: Unstable Nix packages collection
- **flake-utils**: Utilities for multi-system flakes
- **Development shell**: Pre-configured environment with all tools
- **Allow unfree**: Support for non-free packages when needed

### Direnv Integration
- `.envrc` file in project directory enables `use nix`
- Automatic activation of Nix development shell
- Environment variables loaded on directory entry

## Usage

### Starting the Container
```bash
# From the localnet root directory
make base-up
```

### Entering the Container
```bash
# Attach to the running container
docker exec -it localnet-base-dev-1 zsh
```

### Development Workflow
1. Navigate to `/home/cuser/project`
2. The Nix development shell is automatically activated via direnv
3. All tools are available in the PATH
4. Your home directory persists across container restarts

### Project Structure
```
/home/cuser/
├── project/          # Main development directory
│   ├── .envrc       # Direnv configuration
│   └── flake.nix    # Nix flake definition
├── .local/          # Local binaries and data
└── .nix-profile/    # Nix user profile
```

## Security Features

- **Non-root execution**: Runs as `cuser` with limited privileges
- **Sudo access**: Passwordless sudo for administrative tasks
- **Read-only filesystem**: Base filesystem is read-only (except user directories)
- **Health checks**: Container health monitoring
- **Secure entrypoint**: Proper UID/GID handling and permission setup

## Environment Variables

Key environment variables configured:
- `USERNAME=cuser`: Non-root user name
- `PUID=1000`: User ID (configurable)
- `PGID=1000`: Group ID (configurable)
- `PATH`: Includes Nix profile and user binaries
- `NIX_PATH`: Configured for Nix package access

## Integration with LocalNet

This container is part of the LocalNet development environment and integrates with:
- **nix-sidecar**: Shared Nix store and package management
- **DNS services**: Local DNS resolution
- **Other development services**: Via Docker networking

## Maintenance

### Updating Packages
```bash
# Update Nix packages
nix flake update
nix develop --refresh

# Rebuild container if needed
make rebuild SERVICE=base-dev
```

### Adding New Tools
Add tools to the `buildInputs` section in `/home/cuser/project/flake.nix`, then:
```bash
nix develop --rebuild
```

## Troubleshooting

### Common Issues
1. **Nix store not available**: Ensure nix-sidecar is running
2. **Permission denied**: Check UID/GID configuration
3. **Missing tools**: Activate development shell with `nix develop`

### Health Check
The container includes a health check that verifies:
- User permissions are correct
- Nix environment is accessible
- Basic system functionality

## License

This development environment is part of the LocalNet project and follows the same licensing terms.
