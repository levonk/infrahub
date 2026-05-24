# Iron-Proxy - Egress Firewall for Untrusted Workloads

## Overview

Iron-Proxy is a MITM egress proxy with a built-in DNS server that sits between your untrusted workload and the internet. It enforces default-deny at the network boundary, so the workload can only reach domains you explicitly allow.

**Key Features:**
- **Default-deny egress**: Every outbound request is blocked unless the destination matches your allowlist
- **Boundary-level secret injection**: Workloads send proxy tokens; iron-proxy swaps in real credentials at egress
- **Per-request audit trail**: Every request logged as structured JSON with full transform pipeline result
- **Streaming-aware**: WebSocket upgrades and Server-Sent Events are proxied natively
- **CONNECT and SOCKS5 support**: Optional tunnel listener for tools with native proxy configuration

**Source**: https://github.com/ironsh/iron-proxy

## Quick Start

### Prerequisites

- Docker and Docker Compose
- CA certificates for TLS termination (see below)

### Generate CA Certificates

Iron-Proxy terminates TLS by generating leaf certificates on the fly, signed by a CA you provide. Client containers must trust this CA.

```bash
mkdir -p certs
openssl genrsa -out certs/ca.key 4096
openssl req -x509 -new -nodes \
  -key certs/ca.key \
  -sha256 -days 3650 \
  -subj "/CN=iron-proxy CA" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign" \
  -out certs/ca.crt
```

### Configure Allowlist

Edit `proxy.yaml` to configure the domains you want to allow:

```yaml
allowlist:
  - "github.com"
  - "api.github.com"
  - "registry.npmjs.org"
  - "pypi.org"
```

### Build and Run

```bash
# Build the service
just build

# Start the service
just up

# View logs
just logs
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `OPENAI_API_KEY` | OpenAI API key for secret injection | (required) |
| `ANTHROPIC_API_KEY` | Anthropic API key for secret injection | (optional) |

### Ports

- **8080**: HTTP proxy port
- **53**: DNS server port

### Configuration File

The main configuration is in `proxy.yaml`:
- `listen_addr`: Proxy listening address
- `dns`: DNS server configuration
- `allowlist`: List of allowed domains
- `secrets`: Secret injection rules
- `tls`: TLS/CA certificate paths

## Usage

### Route Containers Through Proxy

The simplest approach is DNS-based routing:

```bash
# Create a Docker network with fixed IP for iron-proxy
docker network create --subnet=172.20.0.0/24 iron-proxy

# Start iron-proxy
docker run -d --name iron-proxy \
  --network iron-proxy --ip 172.20.0.2 \
  -v $(pwd)/proxy.yaml:/etc/iron-proxy/proxy.yaml:ro \
  -v $(pwd)/certs/ca.crt:/etc/iron-proxy/ca.crt:ro \
  -v $(pwd)/certs/ca.key:/etc/iron-proxy/ca.key:ro \
  --env-file .env \
  ironsh/iron-proxy:latest -config /etc/iron-proxy/proxy.yaml

# Route containers through the proxy
docker run --rm \
  --network iron-proxy \
  --dns 172.20.0.2 \
  -v $(pwd)/certs/ca.crt:/certs/ca.crt:ro \
  curlimages/curl --cacert /certs/ca.crt https://httpbin.org/get
```

### Secret Injection

Workloads use proxy tokens instead of real secrets:

```bash
# In workload environment
export OPENAI_API_KEY="proxy-token-abc123"

# Iron-proxy automatically swaps to real value from its environment
# The compromised workload gets a token that's useless outside the proxy
```

## Monitoring

### Logs

View structured JSON logs:

```bash
just logs
```

Each request produces an audit entry with:
- Host, method, path, action, status code
- Request transforms (allowlist, secrets)
- Rejection reasons

### Health Check

The container includes a process-based health check:

```bash
just health-check
```

## Build System

The justfile provides convenient commands:

### Core Commands
- `build` - Build Docker images
- `up` - Start services
- `down` - Stop services
- `restart` - Restart services
- `logs` - View logs
- `health-check` - Verify health

### Development Commands
- `test` - Run test suite
- `lint` - Lint configuration files
- `shell` - Access container shell
- `clean` - Remove containers (keep data)
- `clean-all` - Remove everything (WARNING: destroys data)

## Linting & Security Checks

The boilerplate now ships with containerized tooling so every contributor can run the same checks without installing extra CLIs locally. The most common targets are:

| Command | What it does |
|---------|--------------|
| `just lint` | Runs the full lint suite (`yamllint`, `markdownlint`, `hadolint`, and Checkov) inside pinned Docker images. |
| `just lint-yaml` | Validates `docker-compose*.yml` syntax with `yamllint`. |
| `just lint-md` | Ensures project docs follow `markdownlint` rules (ignores `node_modules` and `.git`). |
| `just lint-docker` | Runs `hadolint` against `Dockerfile.iron-proxy` to catch Dockerfile anti-patterns. |
| `just lint-iac` | Executes Checkov against the repo to surface IaC misconfigurations early. |
| `just docker-scout` | Generates a CVE report for the local image tag via Docker Scout (requires the Docker CLI plugin). |
| `just trivy` | Runs Trivy config scans by default and image scans when `TRIVY_IMAGE_TARGET` is set. |
| `just dockle` | Runs Dockle image linting against the local image (default `latest` tag) to check for CIS benchmarks and best practices. |
| `just runtime-scan` | Launches a Falco container with modern eBPF sensors to detect suspicious runtime activity (requires elevated kernel capabilities). |
| `just audit` | Executes `docker-bench-security` with read-only mounts to audit the local Docker daemon hardening. |
| `just security-scan` | Convenience wrapper that runs `just lint`, `just trivy`, `just dockle`, `just docker-scout`, and the templated `scripts/security-scan.sh` report. |

All scanners run with `--security-opt=no-new-privileges` (where supported) and use the `.cache/` directory for offline artifacts so repeated runs stay fast on CI and developer laptops alike.


## Security

### Container Hardening

- **Base Image**: `base-debian` (hardened Debian 12-slim)
- **User**: Non-root (`appuser:appuser`)
- **Capabilities**: Dropped all capabilities
- **Filesystem**: Read-only root filesystem
- **Networks**: Isolated network with explicit rules

### Best Practices

- No privileged containers
- No host network access
- No Docker socket mounting
- Resource limits enforced
- Secrets mounted at runtime

## Monitoring

### Health Checks

The service includes comprehensive health checks:
- Application health via HTTP endpoint
- Resource usage monitoring
- Dependency availability

### Logging

- Structured JSON logs
- Correlation IDs for request tracing
- Error logging with stack traces
- Audit logging for security events

### Metrics

- Prometheus metrics endpoint
- Application performance metrics
- System resource metrics
- Custom business metrics

## Deployment

### Docker Compose

```yaml
services:
  iron-proxy:
    build:
      context: .
      dockerfile: Dockerfile.iron-proxy
    container_name: iron-proxy
    restart: unless-stopped
    ports:
      - "8080:8080"
    environment:
      - NODE_ENV=production
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

### Kubernetes

For Kubernetes deployment, use the provided Helm chart in `k8s/` directory.

## Development

### Local Development

```bash
# Install dependencies
npm ci

# Run tests
npm test

# Start development server
npm run dev
```

### Testing

```bash
# Run all tests
make test

# Run specific test suite
npm test -- --grep "authentication"

# Run linting
make lint
```

## Troubleshooting

### Common Issues

1. **Port already in use**
   ```bash
   # Find what's using the port
   lsof -i :8080

   # Change port in docker-compose.yml
   ```

2. **Health check failures**
   ```bash
   # Check service logs
   make logs

   # Test health endpoint manually
   curl http://localhost:8080/health
   ```

3. **Permission denied**
   ```bash
   # Check user permissions
   make shell
   whoami
   id
   ```

## Contributing

1. Follow the established patterns
2. Add tests for new features
3. Update documentation
4. Ensure security best practices

## License

See LICENSE file in the project root.
