#!/bin/bash

# Base Kali+Nix Entrypoint Script
# This script initializes the Kali Linux environment with Nix package management

set -euo pipefail

# Function to log messages with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

# Function to handle signals
cleanup() {
    log "Received shutdown signal, cleaning up..."
    exit 0
}

# Set signal handlers
trap cleanup SIGTERM SIGINT SIGQUIT

# Ensure we're running as the correct user
if [ "$(id -u)" != "${PUID:-1000}" ]; then
    log "Warning: Running as user $(id -u), expected PUID=${PUID:-1000}"
fi

# Set up environment
export HOME="/home/${USERNAME:-cuser}"
export USER="${USERNAME:-cuser}"

# Initialize Nix environment
if [ ! -d "/nix/var/nix/profiles/default" ]; then
    log "Initializing Nix environment..."
    
    # Restore bootstrap if empty volume is mounted
    if [ -f "/base-kalinix/tmp/bootstrap-slash-nix.tar" ]; then
        log "Restoring Nix bootstrap environment..."
        tar -xf /base-kalinix/tmp/bootstrap-slash-nix.tar -C /
    fi
    
    # Initialize Nix profile
    if command -v nix >/dev/null 2>&1; then
        nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs
        nix-channel --update
        nix profile install nixpkgs#cowsay
        log "Nix environment initialized"
    else
        log "Warning: Nix not available"
    fi
fi

# Set up Nix environment variables
if [ -d "/nix/var/nix/profiles/default/bin" ]; then
    export PATH="/nix/var/nix/profiles/default/bin:$PATH"
    export NIX_PATH="nixpkgs=/nix/var/nix/profiles/default/channels/nixpkgs:/nix/var/nix/profiles/default/channels"
fi

# Create personal directories
mkdir -p "$HOME/.local/bin" "$HOME/.local/share" "$HOME/.config" "$HOME/tools" "$HOME/workspace" "$HOME/.nix-profile"

# Set up Python environment (inherited from base-kali)
if [ ! -d "$HOME/.local/venv" ]; then
    log "Creating Python virtual environment..."
    python3 -m venv "$HOME/.local/venv"
    "$HOME/.local/venv/bin/pip" install --upgrade pip
fi

# Activate Python virtual environment
source "$HOME/.local/venv/bin/activate"

# Install additional Python security tools via Nix
if command -v nix >/dev/null 2>&1; then
    log "Installing additional Python security tools via Nix..."
    
    # Security research tools available in Nix
    nix_profile_tools=(
        "nixpkgs#python3Packages.scapy"
        "nixpkgs#python3Packages.pwntools"
        "nixpkgs#python3Packages.cryptography"
        "nixpkgs#python3Packages.requests"
        "nixpkgs#python3Packages.beautifulsoup4"
        "nixpkgs#python3Packages.lxml"
    )
    
    for tool in "${nix_profile_tools[@]}"; do
        if ! nix profile list | grep -q "$tool"; then
            nix profile install "$tool" 2>/dev/null || log "Warning: Failed to install $tool"
        fi
    done
fi

# Install common Python security tools
log "Installing Python security tools..."
pip install --quiet \
    requests \
    beautifulsoup4 \
    lxml \
    paramiko \
    scapy \
    pycryptodome \
    cryptography \
    flask \
    fastapi \
    uvicorn \
    pwntools \
    mitmproxy

# Set up Go environment (inherited from base-kali)
if command -v go >/dev/null 2>&1; then
    export GOPATH="$HOME/go"
    export PATH="$PATH:$GOPATH/bin"
    mkdir -p "$GOPATH/bin" "$GOPATH/src"
    
    log "Go environment configured"
fi

# Set up Rust environment (inherited from base-kali)
if command -v cargo >/dev/null 2>&1; then
    export PATH="$HOME/.cargo/bin:$PATH"
    log "Rust environment configured"
fi

# Create enhanced tool shortcuts with Nix tools
cat > "$HOME/.local/bin/security-tools" << 'EOF'
#!/bin/bash
echo "=== Kali Linux + Nix Security Tools ==="
echo "Network Scanning:"
echo "  nmap - Network mapper"
echo "  tcpdump - Packet analyzer"
echo "  wireshark - Network protocol analyzer"
echo ""
echo "Web Security:"
echo "  burpsuite - Web application security testing"
echo "  gobuster - Directory/file brute forcing"
echo "  dirb - Directory brute forcing"
echo "  nikto - Web server scanner"
echo "  sqlmap - SQL injection testing"
echo ""
echo "Exploitation:"
echo "  msfconsole - Metasploit Framework console"
echo "  searchsploit - Exploit-DB search"
echo ""
echo "Password Cracking:"
echo "  john - John the Ripper password cracker"
echo "  hashcat - Advanced password recovery"
echo ""
echo "Forensics:"
echo "  autopsy - Digital forensics platform"
echo "  sleuthkit - Forensics toolkit"
echo ""
echo "Python Security (via Nix):"
echo "  scapy - Packet manipulation"
echo "  pwntools - CTF framework"
echo "  mitmproxy - HTTP/HTTPS proxy"
echo ""
echo "Nix Tools:"
if command -v nix >/dev/null 2>&1; then
    echo "  nix search <package> - Search Nix packages"
    echo "  nix shell <package> - Run package in temporary shell"
    echo "  nix profile install <package> - Install package permanently"
fi
EOF

chmod +x "$HOME/.local/bin/security-tools"

# Create Nix-specific helper scripts
cat > "$HOME/.local/bin/nix-security-tools" << 'EOF'
#!/bin/bash
echo "=== Installing Security Tools via Nix ==="

if ! command -v nix >/dev/null 2>&1; then
    echo "Error: Nix not available"
    exit 1
fi

echo "Installing common security tools..."

# Network security tools
nix profile install nixpkgs#nmap 2>/dev/null || echo "nmap already installed or failed"
nix profile install nixpkgs#wireshark-cli 2>/dev/null || echo "wireshark-cli already installed or failed"
nix profile install nixpkgs#tcpdump 2>/dev/null || echo "tcpdump already installed or failed"

# Web security tools
nix profile install nixpkgs#gobuster 2>/dev/null || echo "gobuster already installed or failed"
nix profile install nixpkgs#nikto 2>/dev/null || echo "nikto already installed or failed"

# Password tools
nix profile install nixpkgs#john 2>/dev/null || echo "john already installed or failed"
nix profile install nixpkgs#hashcat 2>/dev/null || echo "hashcat already installed or failed"

# Forensics
nix profile install nixpkgs#autopsy 2>/dev/null || echo "autopsy already installed or failed"
nix profile install nixpkgs#sleuthkit 2>/dev/null || echo "sleuthkit already installed or failed"

echo "Security tools installation complete!"
echo "Run 'security-tools' to see available tools."
EOF

chmod +x "$HOME/.local/bin/nix-security-tools"

# Create workspace initialization script
cat > "$HOME/.local/bin/init-workspace" << 'EOF'
#!/bin/bash
WORKSPACE="$HOME/workspace/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$WORKSPACE"
cd "$WORKSPACE"
echo "Created workspace: $WORKSPACE"
echo "Current directory: $(pwd)"

# Create basic project structure
mkdir -p {scans,exploits,reports,scripts,data}
echo "Created project structure: scans/, exploits/, reports/, scripts/, data/"
EOF

chmod +x "$HOME/.local/bin/init-workspace"

# Add tools to PATH
export PATH="$HOME/.local/bin:$PATH"

log "Base Kali+Nix environment initialized"
log "User: $USER ($(id -u):$(id -g))"
log "Home: $HOME"
log "Python: $(python3 --version)"
log "Nix: $(nix --version 2>/dev/null || echo 'Not available')"
log "Go: $(go version 2>/dev/null || echo 'Not installed')"
log "Rust: $(rustc --version 2>/dev/null || echo 'Not installed')"
log ""
log "Available commands:"
log "  security-tools - List available security tools"
log "  nix-security-tools - Install security tools via Nix"
log "  init-workspace - Create a new workspace directory"
log "  msfconsole - Launch Metasploit Framework"
log "  nmap - Network scanning"
log "  gobuster - Web directory brute forcing"
log ""
log "Kali Ready for Use with Nix package management!"

# Keep container running if no command is provided
if [ $# -eq 0 ]; then
    log "Starting container to view logs..."
    log "Container is ready for security testing!"
    log "Available commands:"
    log "  security-tools - List available security tools"
    log "  init-workspace - Create a new workspace directory"
    log "  msfconsole - Launch Metasploit Framework"
    log "  nmap - Network scanning"
    log "  gobuster - Web directory brute forcing"
    log ""
    log "Use 'docker exec -it localnet-base-kalinix /bin/bash' to get an interactive shell"
    
    # Keep container alive with sleep loop instead of interactive shell
    #while true; do
        sleep 600  # Sleep for 10 minutes
    #done
else
    log "Executing command: $*"
    exec "$@"
fi