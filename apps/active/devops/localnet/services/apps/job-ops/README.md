# JobOps Service

A Docker implementation of [JobOps](https://github.com/DaKheera47/job-ops) - an AI-powered job application tracking and management system.

## Overview

JobOps is a comprehensive job application management tool that helps you:
- Track job applications across multiple platforms
- Use AI to analyze and match recruitment emails
- Manage resumes and tailor them for specific positions
- Monitor application pipelines and timelines
- Integrate with Gmail for email-based job tracking

## Features

- **AI-Powered Analysis**: Smart routing AI analyzes recruitment emails and matches them to job applications
- **Resume Management**: Import and tailor resumes for specific job applications
- **Pipeline Tracking**: Monitor application status through customizable pipelines
- **Gmail Integration**: OAuth-based Gmail integration for tracking inbox emails
- **Multi-User Support**: Create multiple users with isolated workspaces
- **PDF Generation**: Generate tailored resumes using LaTeX or Reactive Resume

## Prerequisites

### LLM Provider (Required)

JobOps requires an LLM provider for AI-powered features. Configure one of the following during onboarding:

- **OpenRouter** (default): Get an API key from [https://openrouter.ai/](https://openrouter.ai/)
- **OpenAI**: Get an API key from [https://platform.openai.com/](https://platform.openai.com/)
- **Gemini**: Get an API key from [https://makersuite.google.com/](https://makersuite.google.com/)
- **Local URL**: Use a local LLM endpoint (e.g., Ollama)

### Gmail OAuth (Optional)

For Gmail integration (tracking inbox), you need to configure OAuth credentials:

#### 1. Create Google OAuth Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Configure OAuth consent screen
3. Enable Gmail API
4. Create OAuth client ID (Web application)
5. Add redirect URI:
   - Local: `http://localhost:3005/oauth/gmail/callback`
   - Production: `https://your-domain.com/oauth/gmail/callback`

#### 2. Configure Environment Variables

Add to your localnet `env.local` file:

```bash
APPS_JOB_OPS_GMAIL_OAUTH_CLIENT_ID=your_client_id_here
APPS_JOB_OPS_GMAIL_OAUTH_CLIENT_SECRET=your_client_secret_here
APPS_JOB_OPS_GMAIL_OAUTH_REDIRECT_URI=http://localhost:3005/oauth/gmail/callback
```

For detailed setup instructions, see: [Gmail OAuth Setup](https://jobops.dakheera47.com/docs/getting-started/gmail-oauth-setup)

### Reactive Resume (Optional)

If you self-host Reactive Resume, configure:

```bash
APPS_JOB_OPS_RXRESUME_URL=http://rxresume.local.net
APPS_JOB_OPS_RXRESUME_API_KEY=your_api_key_here
```

## Service Details

- **Service Name**: `job-ops`
- **Container Name**: `localnet-apps-job-ops`
- **Base Image**: `ghcr.io/dakheera47/job-ops:latest`
- **Network IP**: `172.20.255.72`
- **Host Port**: `3005` (configurable via `APPS_JOB_OPS_HOST_PORT`)
- **Container Port**: `3005` (configurable via `APPS_JOB_OPS_CONTAINER_PORT`)

## Usage

### Starting the Service

```bash
# Start all services (recommended)
cd apps/active/devops/localnet
just up

# Or start only apps services
just up-apps

# Or start specific service
just rebuild SERVICE=job-ops
```

### Accessing the Service

Once running, access the service at:

- **Local Access**: <http://localhost:3005>
- **Network Access**: <http://[YOUR_SERVER_IP]:3005>

### Initial Setup

On first access, JobOps will guide you through an onboarding wizard:

1. **LLM Provider**: Select and configure your LLM provider (OpenRouter, OpenAI, Gemini, or local)
2. **Resume Import**: Upload a PDF/DOCX resume or connect to Reactive Resume
3. **Search Terms**: Review and edit job title search terms generated from your resume
4. **Account Creation**: Create the first username/password account (becomes system admin)

### Viewing Logs

```bash
# View logs for all services
just logs

# View logs for this specific service
just logs SERVICE=job-ops

# Follow logs in real-time
just logs-follow SERVICE=job-ops
```

## Configuration

### Environment Variables

The service can be configured using the following environment variables in `env.template`:

```bash
# Network configuration
APPS_JOB_OPS_IP=172.20.255.72
APPS_JOB_OPS_HOST_PORT=3005
APPS_JOB_OPS_CONTAINER_PORT=3005

# Demo mode (sandbox deployments)
APPS_JOB_OPS_DEMO_MODE=false

# Gmail OAuth (optional)
APPS_JOB_OPS_GMAIL_OAUTH_CLIENT_ID=
APPS_JOB_OPS_GMAIL_OAUTH_CLIENT_SECRET=
APPS_JOB_OPS_GMAIL_OAUTH_REDIRECT_URI=http://localhost:3005/oauth/gmail/callback

# Basic auth (for older single-user installs)
APPS_JOB_OPS_BASIC_AUTH_USER=
APPS_JOB_OPS_BASIC_AUTH_PASSWORD=

# Self-hosted Reactive Resume (optional)
APPS_JOB_OPS_RXRESUME_URL=
APPS_JOB_OPS_RXRESUME_API_KEY=
```

### Demo Mode

Set `APPS_JOB_OPS_DEMO_MODE=true` for sandbox deployments:

- Works locally: browsing/filtering/status/timeline edits
- Simulated: pipeline run/summarize/process/rescore/pdf/apply
- Blocked: settings writes, DB clear, backups
- Auto-reset: every 6 hours

### Persistent Data

The `job-ops-data` volume stores:

- SQLite DB: `data/jobs.db`
- Generated PDFs: `data/pdfs/`
- Cloudflare challenge cookies: `data/cloudflare-cookies/`

### Security Features

- **Non-root Execution**: Runs as user with UID/GID 1000
- **Capability Dropping**: All capabilities dropped
- **No New Privileges**: Prevents privilege escalation
- **Health Checks**: Built-in health monitoring

## Email-to-Job Matching

JobOps includes an AI-powered email-to-job matching system:

1. Recruitment email arrives in Gmail
2. Smart Router AI analyzes content
3. Based on confidence:
   - **95-100%**: Auto-linked to job, timeline updated automatically
   - **50-94%**: Goes to Inbox for review with suggested job match
   - **<50%**: Goes to Inbox as orphan (if relevant) or ignored
4. User review: Approve (link + timeline update) or Ignore

For more details, see: [JobOps Documentation](https://jobops.dakheera47.com/docs/getting-started/self-hosting/)

## Development

### File Structure

```
job-ops/
├── docker-compose.job-ops.yml    # Docker Compose configuration
├── .env.example                   # Environment variables template
└── README.md                      # This file
```

### Building from Source

To build locally instead of using the pre-built image:

```bash
# Set GITHUB_TOKEN to avoid rate limits during Camoufox download
export GITHUB_TOKEN=ghp_your_token_here

# Build with local build
docker compose -f services/apps/job-ops/docker-compose.job-ops.yml up -d --build
```

The GITHUB_TOKEN is passed as a BuildKit secret only for the Camoufox download step and is not stored in the runtime container environment.

## Troubleshooting

### Common Issues

1. **Service Won't Start**
   - Check container status: `docker ps | grep job-ops`
   - Verify port availability: `netstat -tlnp | grep 3005`
   - Check logs: `just logs SERVICE=job-ops`

2. **LLM Provider Issues**
   - Verify API key is correctly configured during onboarding
   - Check if API key has sufficient credits/quota
   - Try switching to a different LLM provider

3. **Gmail OAuth Fails**
   - Verify OAuth credentials are correctly set in `env.local`
   - Check redirect URI matches: `http://localhost:3005/oauth/gmail/callback`
   - Ensure Gmail API is enabled in Google Cloud Console

4. **Health Check Failures**
   - Wait longer for service to initialize (up to 60 seconds)
   - Check if the application is responding on port 3005
   - Verify environment variables are set correctly

### Debug Commands

```bash
# Check container status
docker ps | grep job-ops

# Inspect container
docker inspect localnet-apps-job-ops

# Execute commands in container
docker exec -it localnet-apps-job-ops /bin/sh

# Check service logs
docker logs localnet-apps-job-ops
```

## Integration with LocalNet

This service is fully integrated into the LocalNet ecosystem:

- **Network**: Uses the `localnet` Docker network
- **Volumes**: Persistent data storage via `job-ops-data` volume
- **Monitoring**: Health checks integrated with LocalNet monitoring
- **Logging**: Structured JSON logging with rotation
- **Security**: Follows LocalNet security standards

## Source Code

The original source code is available at:

- <https://github.com/DaKheera47/job-ops>
- Documentation: <https://jobops.dakheera47.com/docs/>

## Support

For issues related to:

- **Docker Service**: Check LocalNet documentation and logs
- **Application Functionality**: Refer to the [JobOps Documentation](https://jobops.dakheera47.com/docs/)
- **Integration**: Use `just health` to check overall system status

## Updating

To update to the latest version:

```bash
cd apps/active/devops/localnet
docker compose -f services/apps/job-ops/docker-compose.job-ops.yml pull
docker compose -f services/apps/job-ops/docker-compose.job-ops.yml up -d
```

## PDF Rendering Options

JobOps supports two PDF renderers:

1. **rxresume**: Export the final PDF through RxResume (default)
2. **latex**: Render locally from tailored resume data using LaTeX and tectonic

When using the LaTeX renderer, the Docker image includes tectonic automatically. For non-Docker local runs, install tectonic yourself.

RxResume remains the source of truth for base resume data, project visibility, and tailoring inputs in both modes.
