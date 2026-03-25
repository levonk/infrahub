#!/bin/bash

# Base Kali Linux Health Check Script
# This script checks if the Kali Linux environment is healthy and ready

set -euo pipefail

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

# Function to check basic system health
check_system() {
    log "Checking system health..."
    
    # Check if we're running as the correct user
    if [ "$(id -u)" != "${PUID:-1000}" ]; then
        log "Warning: Running as user $(id -u), expected PUID=${PUID:-1000}"
    else
        log "User check passed: $(id -u):$(id -g)"
    fi
    
    # Check home directory
    local home_dir="/home/${USERNAME:-cuser}"
    if [ -d "$home_dir" ] && [ -w "$home_dir" ]; then
        log "Home directory accessible: $home_dir"
    else
        log "Error: Home directory not accessible: $home_dir"
        return 1
    fi
    
    return 0
}

# Function to check security tools
check_security_tools() {
    log "Checking security tools..."
    
    local tools_ok=true
    
    # Check essential tools
    local essential_tools=("nmap" "python3" "curl" "wget" "git")
    for tool in "${essential_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            log "✓ $tool available"
        else
            log "✗ $tool not available"
            tools_ok=false
        fi
    done
    
    # Check security-specific tools
    local security_tools=("msfconsole" "burpsuite" "gobuster" "john" "hashcat")
    for tool in "${security_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            log "✓ $tool available"
        else
            log "! $tool not available (optional)"
        fi
    done
    
    if [ "$tools_ok" = true ]; then
        log "Essential tools check passed"
        return 0
    else
        log "Essential tools check failed"
        return 1
    fi
}

# Function to check Python environment
check_python_env() {
    log "Checking Python environment..."
    
    local home_dir="/home/${USERNAME:-cuser}"
    local venv_dir="$home_dir/.local/venv"
    
    if [ -d "$venv_dir" ] && [ -f "$venv_dir/bin/python" ]; then
        log "Python virtual environment found: $venv_dir"
        
        # Check if virtual environment can be activated
        if "$venv_dir/bin/python" --version >/dev/null 2>&1; then
            log "✓ Python virtual environment functional"
            return 0
        else
            log "✗ Python virtual environment not functional"
            return 1
        fi
    else
        log "! Python virtual environment not found"
        return 1
    fi
}

# Function to check development environments
check_dev_envs() {
    log "Checking development environments..."
    
    # Check Go
    if command -v go >/dev/null 2>&1; then
        local go_version=$(go version 2>/dev/null || echo "unknown")
        log "✓ Go available: $go_version"
    else
        log "! Go not available (optional)"
    fi
    
    # Check Rust
    if command -v cargo >/dev/null 2>&1; then
        local rust_version=$(rustc --version 2>/dev/null || echo "unknown")
        log "✓ Rust available: $rust_version"
    else
        log "! Rust not available (optional)"
    fi
    
    return 0
}

# Function to check user scripts
check_user_scripts() {
    log "Checking user scripts..."
    
    local home_dir="/home/${USERNAME:-cuser}"
    local scripts_dir="$home_dir/.local/bin"
    
    if [ -d "$scripts_dir" ]; then
        local scripts=("security-tools" "init-workspace")
        for script in "${scripts[@]}"; do
            if [ -f "$scripts_dir/$script" ] && [ -x "$scripts_dir/$script" ]; then
                log "✓ $script script available"
            else
                log "! $script script not available"
            fi
        done
    else
        log "! User scripts directory not found"
    fi
    
    return 0
}

# Function to check workspace
check_workspace() {
    log "Checking workspace..."
    
    local workspace_dir="/home/${USERNAME:-cuser}/workspace"
    
    if [ -d "$workspace_dir" ]; then
        local workspace_count=$(find "$workspace_dir" -maxdepth 1 -type d | wc -l)
        log "Workspace directory exists with $((workspace_count - 1)) workspace(s)"
    else
        log "! Workspace directory not found"
    fi
    
    return 0
}

# Main health check logic
main() {
    local exit_code=0
    
    log "Starting Base Kali Linux health check..."
    
    # Run all checks
    if ! check_system; then
        exit_code=1
    fi
    
    if ! check_security_tools; then
        exit_code=1
    fi
    
    if ! check_python_env; then
        exit_code=1
    fi
    
    # These are optional, so don't fail the health check
    check_dev_envs || true
    check_user_scripts || true
    check_workspace || true
    
    if [ $exit_code -eq 0 ]; then
        log "Base Kali Linux health check passed"
    else
        log "Base Kali Linux health check failed"
    fi
    
    exit $exit_code
}

# Run main function
main "$@"
