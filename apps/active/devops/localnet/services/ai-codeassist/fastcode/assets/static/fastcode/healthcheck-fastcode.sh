#!/bin/bash
# FastCode Service Health Check Script
# Performs comprehensive health checks for FastCode container

set -euo pipefail

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

# Function to check if service is responding
check_service_response() {
    local max_attempts=3
    local attempt=1
    local timeout=5
    
    while [[ $attempt -le $max_attempts ]]; do
        log "Attempt $attempt/$max_attempts: Checking FastCode service response..."
        
        if curl -f -s --max-time "$timeout" \
            -H "User-Agent: FastCode-HealthCheck/1.0" \
            "http://localhost:5000/health" >/dev/null 2>&1; then
            log "Service response check passed"
            return 0
        fi
        
        log "Service response check failed (attempt $attempt/$max_attempts)"
        ((attempt++))
        
        if [[ $attempt -le $max_attempts ]]; then
            sleep 2
        fi
    done
    
    log "Service response check failed after $max_attempts attempts"
    return 1
}

# Function to check if FastCode process is running
check_process_health() {
    log "Checking FastCode process health..."
    
    # Check if the main process is running
    if pgrep -f "python.*web_app.py" >/dev/null 2>&1; then
        log "FastCode process is running"
        return 0
    else
        log "FastCode process is not running"
        return 1
    fi
}

# Function to check port availability
check_port_availability() {
    log "Checking port 5000 availability..."
    
    if netstat -ln | grep -q ":5000.*LISTEN" 2>/dev/null || \
       ss -ln | grep -q ":5000.*LISTEN" 2>/dev/null; then
        log "Port 5000 is listening"
        return 0
    else
        log "Port 5000 is not listening"
        return 1
    fi
}

# Function to check application dependencies
check_dependencies() {
    log "Checking application dependencies..."
    
    # Check Python environment
    if ! python --version >/dev/null 2>&1; then
        log "Python is not available"
        return 1
    fi
    
    # Check critical modules
    local modules=("fastapi" "uvicorn" "fastcode")
    for module in "${modules[@]}"; do
        if ! python -c "import $module" >/dev/null 2>&1; then
            log "Module $module is not available"
            return 1
        fi
    done
    
    log "All dependencies are available"
    return 0
}

# Function to check file system health
check_filesystem() {
    log "Checking file system health..."
    
    # Check critical directories
    local dirs=("/app" "/app/data" "/app/logs" "/app/repositories")
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log "Directory $dir does not exist"
            return 1
        fi
        
        # Check if directory is writable
        if [[ ! -w "$dir" ]]; then
            log "Directory $dir is not writable"
            return 1
        fi
    done
    
    log "File system check passed"
    return 0
}

# Function to check memory usage
check_memory_usage() {
    log "Checking memory usage..."
    
    # Get memory usage percentage
    local mem_usage
    mem_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}' 2>/dev/null || echo "0")
    
    # Check if memory usage is below 90%
    if [[ $mem_usage -lt 90 ]]; then
        log "Memory usage: ${mem_usage}% (OK)"
        return 0
    else
        log "Memory usage: ${mem_usage}% (HIGH)"
        return 1
    fi
}

# Function to check disk space
check_disk_space() {
    log "Checking disk space..."
    
    # Get disk usage percentage for /app
    local disk_usage
    disk_usage=$(df /app | awk 'NR==2{print $5}' | sed 's/%//' 2>/dev/null || echo "0")
    
    # Check if disk usage is below 90%
    if [[ $disk_usage -lt 90 ]]; then
        log "Disk usage: ${disk_usage}% (OK)"
        return 0
    else
        log "Disk usage: ${disk_usage}% (HIGH)"
        return 1
    fi
}

# Function to check environment variables
check_environment() {
    log "Checking critical environment variables..."
    
    # Check for required environment variables
    local required_vars=("PYTHONUNBUFFERED")
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log "Required environment variable $var is not set"
            return 1
        fi
    done
    
    log "Environment variables check passed"
    return 0
}

# Main health check function
main_health_check() {
    local failed_checks=0
    
    log "Starting FastCode comprehensive health check..."
    
    # Run all health checks
    local checks=(
        "check_process_health"
        "check_port_availability"
        "check_dependencies"
        "check_filesystem"
        "check_environment"
        "check_memory_usage"
        "check_disk_space"
        "check_service_response"
    )
    
    for check in "${checks[@]}"; do
        if ! $check; then
            ((failed_checks++))
        fi
    done
    
    # Final result
    if [[ $failed_checks -eq 0 ]]; then
        log "All health checks passed successfully"
        return 0
    else
        log "$failed_checks health checks failed"
        return 1
    fi
}

# Run health check if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_health_check
fi
