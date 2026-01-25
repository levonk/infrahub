#!/bin/bash
set -e

echo "🤖 HAPI Server starting..."
echo "Listen Host: ${HAPI_LISTEN_HOST:-0.0.0.0}"
echo "Listen Port: ${HAPI_LISTEN_PORT:-3006}"
echo "Public URL: ${HAPI_PUBLIC_URL:-none}"
echo "Data Directory: ${HAPI_HOME}"

# Install Node.js if not available
if ! command -v node >/dev/null 2>&1; then
    echo "🤖 HAPI Server: Installing Node.js..."
    apk add --no-cache nodejs npm
fi

# Install pnpm if not available
if ! command -v pnpm >/dev/null 2>&1; then
    echo "🤖 HAPI Server: Installing pnpm..."
    npm install -g pnpm
fi

# Install HAPI CLI if not available
if ! command -v hapi >/dev/null 2>&1; then
    echo "🤖 HAPI Server: Installing HAPI CLI..."
    pnpm install -g @twsxtd/hapi
fi

# Generate CLI API token if not provided
if [ -z "${CLI_API_TOKEN}" ]; then
    CLI_API_TOKEN=$(openssl rand -hex 32)
    echo "🔑 Generated CLI_API_TOKEN: ${CLI_API_TOKEN}"
fi

export CLI_API_TOKEN

# Start HAPI server
exec hapi server "$@"
