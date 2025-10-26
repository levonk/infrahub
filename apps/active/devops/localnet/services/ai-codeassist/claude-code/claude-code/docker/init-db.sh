#!/bin/bash
# Database initialization script for Claude Code integration
# This script runs when the PostgreSQL container starts for the first time

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Wait for PostgreSQL to be ready
wait_for_postgres() {
    local retries=30
    local count=0

    log_info "Waiting for PostgreSQL to be ready..."
    while ! pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; do
        if [ $count -ge $retries ]; then
            log_error "PostgreSQL failed to start after $retries attempts"
            exit 1
        fi

        count=$((count + 1))
        log_info "PostgreSQL not ready yet, attempt $count/$retries. Waiting..."
        sleep 2
    done

    log_info "PostgreSQL is ready!"
}

# Check if database has already been initialized
is_initialized() {
    local result
    result=$(psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_sessions';" 2>/dev/null || echo "0")
    [ "$result" -gt 0 ]
}

# Initialize database schema
init_database() {
    log_info "Initializing Claude Code database schema..."

    if ! psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /docker-entrypoint-initdb.d/init-db.sql; then
        log_error "Failed to initialize database schema"
        exit 1
    fi

    log_info "Database schema initialized successfully"

    # Run post-initialization checks
    run_post_init_checks
}

# Run post-initialization checks
run_post_init_checks() {
    log_info "Running post-initialization checks..."

    # Check that all tables were created
    local expected_tables=("user_sessions" "conversations" "messages" "mcp_tools" "tool_usage" "user_preferences")
    local missing_tables=()

    for table in "${expected_tables[@]}"; do
        if ! psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '$table';" >/dev/null; then
            missing_tables+=("$table")
        fi
    done

    if [ ${#missing_tables[@]} -gt 0 ]; then
        log_error "Missing tables: ${missing_tables[*]}"
        exit 1
    fi

    log_info "All expected tables created successfully"

    # Check that default MCP tools were inserted
    local tool_count
    tool_count=$(psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT COUNT(*) FROM mcp_tools;" 2>/dev/null || echo "0")

    if [ "$tool_count" -eq 0 ]; then
        log_warn "No default MCP tools found. This may be expected if custom initialization is preferred."
    else
        log_info "Found $tool_count default MCP tools"
    fi

    # Verify functions were created
    local functions=("cleanup_expired_sessions" "archive_old_conversations")
    for func in "${functions[@]}"; do
        if psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT 1 FROM information_schema.routines WHERE routine_schema = 'public' AND routine_name = '$func';" >/dev/null; then
            log_info "Function '$func' created successfully"
        else
            log_warn "Function '$func' not found"
        fi
    done

    log_info "Post-initialization checks completed"
}

# Main execution
main() {
    # Set PostgreSQL environment variables if not already set
    export PGUSER="${PGUSER:-$POSTGRES_USER}"
    export PGDATABASE="${PGDATABASE:-$POSTGRES_DB}"
    export PGHOST="${PGHOST:-localhost}"
    export PGPORT="${PGPORT:-5432}"

    wait_for_postgres

    if is_initialized; then
        log_info "Database already initialized, skipping schema creation"
    else
        init_database
    fi

    log_info "Database initialization complete"
}

# Run main function
main "$@"
