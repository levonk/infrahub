#!/bin/bash

# Base Kali Linux Entrypoint Script
# This script initializes the Kali Linux environment for security testing

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

# Use /tmp-based HOME directory to avoid volume permission issues
# The mounted volume has root ownership, but we need user-writable directories
ORIGINAL_HOME="$HOME"
USER_HOME="/tmp/${USERNAME:-cuser}"

log "Using temporary HOME directory due to volume permissions..."
log "Original HOME: $ORIGINAL_HOME (permissions: $(stat -c '%a %U:%G' "$ORIGINAL_HOME" 2>/dev/null || echo 'unknown'))"
log "Temporary HOME: $USER_HOME"

# Create user-writable HOME directory
mkdir -p "$USER_HOME"
export HOME="$USER_HOME"

# Create personal directories with error handling
log "Creating personal directories in $HOME..."
for dir in "$HOME/.local/bin" "$HOME/.local/share" "$HOME/.config" "$HOME/tools" "$HOME/workspace"; do
    if [ ! -d "$dir" ]; then
        if ! mkdir -p "$dir" 2>/dev/null; then
            log "Error: Could not create directory $dir"
            log "Container running as user $(id -u):$(id -g)"
            exit 1
        fi
    fi
done

# Verify directories were created successfully
for dir in "$HOME/.local/bin" "$HOME/tools" "$HOME/workspace"; do
    if [ ! -d "$dir" ]; then
        log "Error: Required directory $dir does not exist and could not be created"
        exit 1
    fi
done
log "Personal directories created successfully"

# Set up Python environment
if [ ! -d "$HOME/.local/venv" ]; then
    log "Creating Python virtual environment..."
    python3 -m venv "$HOME/.local/venv"
    "$HOME/.local/venv/bin/pip" install --upgrade pip
fi

# Activate Python virtual environment
source "$HOME/.local/venv/bin/activate"

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
    uvicorn

# Set up Go environment
if command -v go >/dev/null 2>&1; then
    export GOPATH="$HOME/go"
    export PATH="$PATH:$GOPATH/bin"
    mkdir -p "$GOPATH/bin" "$GOPATH/src"
    
    log "Go environment configured"
fi

# Set up Rust environment
if command -v cargo >/dev/null 2>&1; then
    export PATH="$HOME/.cargo/bin:$PATH"
    log "Rust environment configured"
fi

# Create tool shortcuts
cat > "$HOME/.local/bin/security-tools" << 'EOF'
#!/bin/bash
echo "=== Kali Linux Security Tools ==="
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
echo "Reconnaissance:"
echo "  recon-ng - Web reconnaissance framework"
echo "  theharvester - OSINT tool"
echo "  maltego - Open source intelligence"
EOF

chmod +x "$HOME/.local/bin/security-tools"

# Create workspace initialization script
cat > "$HOME/.local/bin/init-workspace" << 'EOF'
#!/bin/bash
WORKSPACE="$HOME/workspace/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$WORKSPACE"
cd "$WORKSPACE"
echo "Created workspace: $WORKSPACE"
echo "Current directory: $(pwd)"
EOF

chmod +x "$HOME/.local/bin/init-workspace"

# Add tools to PATH
export PATH="$HOME/.local/bin:$PATH"

log "Base Kali Linux environment initialized"
log "User: $USER ($(id -u):$(id -g))"
log "Home: $HOME"
log "Python: $(python3 --version)"
log "Go: $(go version 2>/dev/null || echo 'Not installed')"
log "Rust: $(rustc --version 2>/dev/null || echo 'Not installed')"
log ""
log "Available commands:"
log "  security-tools - List available security tools"
log "  init-workspace - Create a new workspace directory"
log "  msfconsole - Launch Metasploit Framework"
log "  nmap - Network scanning"
log "  gobuster - Web directory brute forcing"
log ""
log "Ready for security testing!"

# Keep container running if no command is provided
if [ $# -eq 0 ]; then
    log "Starting interactive shell..."
    exec /bin/bash
else
    log "Executing command: $*"
    exec "$@"
fi
