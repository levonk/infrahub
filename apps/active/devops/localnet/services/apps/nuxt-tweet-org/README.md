# Nuxt Tweet Organizer Service

A Docker implementation of the [nuxt-tweet-organizer](https://github.com/leszekkrol/nuxt-tweet-organizer) application for efficient Twitter (X) follower management and analysis.

## Overview

This service provides a web-based tool for analyzing, organizing, and optimizing Twitter (X) follower lists with advanced filtering and data visualization features. It's built with Nuxt.js and runs as a containerized service in the LocalNet environment.

## Features

- **Follower Analysis**: Comprehensive analysis of Twitter followers
- **Advanced Filtering**: Filter followers by various criteria
- **Data Visualization**: Visual representations of follower data
- **Organization Tools**: Organize followers into lists and categories
- **Web Interface**: Modern, responsive web UI built with Nuxt.js

## Prerequisites

### X/Twitter API Access Required

This application requires X/Twitter API access to analyze follower data. Here's what you need to set up:

#### 1. Apply for X Developer Access

1. Go to [https://developer.twitter.com/](https://developer.twitter.com/)
2. Sign up for a developer account
3. Describe your use case (personal follower analysis tool)
4. Wait for approval (usually takes 1-3 days)

#### 2. Create an X App with OAuth 2.0

1. Go to [https://console.x.com](https://console.x.com) and sign in
2. Click "Create App"
3. Enter a name, description, and use case for your app
4. **IMPORTANT**: When configuring the app, select **OAuth 2.0** (not OAuth 1.0a)
5. Choose app type: **Web App** or **Automated App / Bot** (both are Confidential clients)
6. Set up callback URL: `http://localhost:3000/api/auth/callback/x`
7. Generate your **Client ID** and **Client Secret** (these are OAuth 2.0 credentials)

⚠️ **Important**: Make sure you're generating OAuth 2.0 credentials (Client ID & Secret), NOT OAuth 1.0a credentials (API Key & Secret). The app uses OAuth 2.0 with `nuxt-auth-utils`.

#### 3. API Access Tiers

- **Free Tier**: Limited API calls (usually sufficient for personal use)
- **Basic Tier**: ~$100/month for more frequent analysis
- **Higher Tiers**: Available for enterprise needs

#### 4. Configure Environment Variables

Create a `env.local` file in the localnet root (based on `env.template`):

```bash
# Add to env.local (this file is gitignored)
X_CLIENT_ID=your_client_id_here
X_CLIENT_SECRET=your_client_secret_here
NUXT_SESSION_PASSWORD=your_custom_generated_password
```

**Where to get each value:**

**X_CLIENT_ID & X_CLIENT_SECRET** (from X Developer Portal - OAuth 2.0):
1. Go to your X Developer App dashboard
2. Click on your app → "Keys and tokens" tab
3. Under "Authentication Tokens", you'll find:
   - **Client ID** (starts with something like `abc123def456...`)
   - **Client Secret** (longer string, only shown once - copy it immediately!)

⚠️ **Important**: The app uses OAuth 2.0, not OAuth 1.0a. Make sure your X Developer app is configured for OAuth 2.0 with the correct callback URL.

**NUXT_SESSION_PASSWORD** (YOU create this - NOT from X!):
This is a custom password that Nuxt.js uses to encrypt session cookies and data. Generate a secure random string:

```bash
# Option 1: Using openssl (recommended)
openssl rand -base64 32

# Option 2: Using date and random
date +%s | sha256sum | base64 | head -c 32

# Option 3: Make a long random string (20+ chars)
# Example: "MySecretNuxtSession2025!@#$%"
```

**Example completed configuration:**

```bash
X_CLIENT_ID=abc123def456ghi789jkl012mno345pqr
X_CLIENT_SECRET=stu678vwx901yzab234cde567fgh890ijk123lmn456opq789rst012uvw345xyz678
NUXT_SESSION_PASSWORD=MySuperSecretNuxtSessionPassword2025!@#$
```

**Important**: Never commit these credentials to version control. The `env.local` file is automatically gitignored.

## Service Details

- **Service Name**: `nuxt-tweet-org`
- **Container Name**: `localnet-apps-nuxt-tweet-org`
- **Base Image**: `localnet-base-alpine`
- **Package Manager**: `pnpm` (NO npm usage)
- **Network IP**: `172.20.255.71`
- **Host Port**: `3000` (configurable via `APPS_NUXT_TWEET_ORG_HOST_PORT`)
- **Container Port**: `3000` (configurable via `APPS_NUXT_TWEET_ORG_CONTAINER_PORT`)

## Dependencies

This service depends on:
- **pnpm-sidecar**: For shared pnpm cache and package management

## Usage

### Starting the Service

```bash
# Start all services (recommended)
cd apps/active/devops/localnet
just up

# Or start only apps services
just up-apps

# Or start specific service
just rebuild SERVICE=nuxt-tweet-org
```

### Accessing the Service

Once running, access the service at:

- **Local Access**: <http://localhost:3000>
- **Network Access**: <http://[YOUR_SERVER_IP]:3000>

### Testing the Service

Run the test suite to verify service functionality:

```bash
# Make sure you're in the localnet root directory
cd apps/active/devops/localnet

# Run the service test
./services/apps/nuxt-tweet-org/tests/test-nuxt-tweet-org.sh
```

### Viewing Logs

```bash
# View logs for all services
just logs

# View logs for this specific service
just logs SERVICE=nuxt-tweet-org

# Follow logs in real-time
just logs-follow SERVICE=nuxt-tweet-org
```

## Configuration

### Environment Variables

The service can be configured using the following environment variables in `env.template`:

```bash
# Network configuration
APPS_NUXT_TWEET_ORG_IP=172.20.255.71
APPS_NUXT_TWEET_ORG_HOST_PORT=3000
APPS_NUXT_TWEET_ORG_CONTAINER_PORT=3000
```

### Security Features

- **Non-root Execution**: Runs as `cuser` (UID/GID 1000)
- **Capability Dropping**: All capabilities dropped
- **Read-only Filesystem**: Root filesystem is read-only
- **No New Privileges**: Prevents privilege escalation
- **Health Checks**: Built-in health monitoring

## Development

### File Structure

```
nuxt-tweet-org/
├── Dockerfile.nuxt-tweet-org          # Main Dockerfile
├── docker-compose.nuxt-tweet-org.yml  # Docker Compose configuration
├── assets/static/
│   ├── entrypoint-nuxt-tweet-org.sh   # Container entrypoint script
│   └── healthcheck-nuxt-tweet-org.sh  # Health check script
├── tests/
│   └── test-nuxt-tweet-org.sh         # Service test script
└── README.md                          # This file
```

### Key Implementation Details

1. **pnpm-Only Policy**: The service uses `pnpm` exclusively for package management
2. **Shared Cache**: Leverages pnpm-sidecar for shared package cache
3. **Automated Setup**: Entrypoint script clones repository and builds automatically
4. **Graceful Shutdown**: Handles SIGTERM/SIGINT for clean shutdown
5. **Health Monitoring**: Custom health check script monitors service status

### Building from Source

```bash
# Build the Docker image
cd apps/active/devops/localnet
docker build -t localnet-apps-nuxt-tweet-org:latest \
  -f services/apps/nuxt-tweet-org/Dockerfile.nuxt-tweet-org \
  services/apps/nuxt-tweet-org/
```

## Troubleshooting

### Common Issues

1. **Service Won't Start**

   - Check if pnpm-sidecar is running: `docker ps | grep pnpm-sidecar`
   - Verify port availability: `netstat -tlnp | grep 3000`
   - Check logs: `just logs SERVICE=nuxt-tweet-org`

2. **Build Failures**
   - Ensure pnpm-sidecar is healthy before building
   - Check network connectivity to GitHub
   - Verify Docker build context

3. **Health Check Failures**
   - Wait longer for service to initialize (up to 60 seconds)
   - Check if the application is responding on port 3000
   - Verify environment variables are set correctly

4. **X/Twitter API Issues**
   - Verify API credentials are correctly set in `env.local`
   - Check if X Developer app is approved and active
   - Ensure callback URL matches: `http://localhost:3000/api/auth/callback`
   - Check API rate limits if getting rate limit errors
   - Verify OAuth 2.0 is properly configured in X Developer Portal

### Debug Commands

```bash
# Check container status
docker ps | grep nuxt-tweet-org

# Inspect container
docker inspect localnet-apps-nuxt-tweet-org

# Execute commands in container
docker exec -it localnet-apps-nuxt-tweet-org /bin/bash

# Check service logs
docker logs localnet-apps-nuxt-tweet-org
```

## Integration with LocalNet

This service is fully integrated into the LocalNet ecosystem:

- **Network**: Uses the `localnet` Docker network
- **Volumes**: Shares pnpm cache via `pnpm-cache` volume
- **Monitoring**: Health checks integrated with LocalNet monitoring
- **Logging**: Structured JSON logging with rotation
- **Security**: Follows LocalNet security standards

## Source Code

The original source code is available at:

- <https://github.com/leszekkrol/nuxt-tweet-organizer>

This Docker service automatically clones and builds the source code on startup.

## Support

For issues related to:

- **Docker Service**: Check LocalNet documentation and logs
- **Application Functionality**: Refer to the upstream GitHub repository
- **Integration**: Use `just health` to check overall system status
