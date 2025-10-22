# Verdaccio npm Registry Configuration Guide

**Feature**: Home Lab In-a-Box  
**Date**: 2025-01-21  
**Service**: Verdaccio Private npm Registry

## Overview

Verdaccio is a lightweight private npm registry that proxies npmjs.org and caches packages locally. This guide covers setup, LRU eviction configuration, and client configuration.

---

## Quick Start

### Access Verdaccio

```bash
# Web UI available at:
http://localhost:4873

# No default credentials - create user on first publish
```

### Create User Account

```bash
# Create user (interactive)
npm adduser --registry http://localhost:4873

# Prompts for:
# Username: your-username
# Password: your-password
# Email: your-email@example.com
```

---

## LRU Eviction Configuration (T071a)

Verdaccio automatically evicts least-recently-used packages when storage exceeds 80% of the configured limit.

### Configuration

Edit `configs/artifacts/verdaccio/config.yaml`:

```yaml
# Storage configuration with LRU eviction
max_storage_size: 50gb
storage_eviction:
  enabled: true
  threshold: 0.8  # Trigger eviction at 80% capacity
  policy: lru     # Least Recently Used eviction
  check_interval: 3600  # Check every hour (seconds)
```

### How It Works

1. **Monitoring**: Verdaccio checks storage usage every hour
2. **Threshold**: When storage exceeds 40GB (80% of 50GB), eviction starts
3. **Selection**: Packages are sorted by last access time
4. **Eviction**: Oldest packages are removed until storage drops below 70%
5. **Re-download**: Evicted packages are automatically re-downloaded from npmjs.org on next request

### Monitoring Storage

```bash
# Check current storage usage
docker compose exec verdaccio du -sh /verdaccio/storage/data

# View storage breakdown by package
docker compose exec verdaccio du -h --max-depth=2 /verdaccio/storage/data | sort -hr | head -20
```

---

## Client Configuration (T074)

### Option 1: Project-Specific (.npmrc in project)

Create `.npmrc` in your project root:

```ini
# Use Verdaccio for all packages
registry=http://localhost:4873/

# Authentication (after npm adduser)
//localhost:4873/:_authToken="YOUR_AUTH_TOKEN"
```

**Get auth token**:
```bash
# Login creates token automatically
npm login --registry http://localhost:4873

# View token
cat ~/.npmrc | grep localhost:4873
```

### Option 2: Global Configuration (~/.npmrc)

Edit `~/.npmrc`:

```ini
# Use Verdaccio globally
registry=http://localhost:4873/

# Authentication
//localhost:4873/:_authToken="YOUR_AUTH_TOKEN"
```

### Option 3: Per-Command

```bash
# Install from Verdaccio
npm install express --registry http://localhost:4873

# Publish to Verdaccio
npm publish --registry http://localhost:4873
```

---

## Usage Examples

### Installing Packages

```bash
# Install package (uses Verdaccio via .npmrc)
npm install lodash

# First request: Downloads from npmjs.org and caches
# Subsequent requests: Serves from cache
```

### Publishing Private Packages

```bash
# 1. Update package.json
{
  "name": "@mycompany/my-package",
  "version": "1.0.0",
  "publishConfig": {
    "registry": "http://localhost:4873"
  }
}

# 2. Login (if not already)
npm login --registry http://localhost:4873

# 3. Publish
npm publish

# 4. Install in other projects
npm install @mycompany/my-package
```

### Scoped Packages

Configure specific scopes to use Verdaccio:

```ini
# .npmrc
@mycompany:registry=http://localhost:4873/
registry=https://registry.npmjs.org/  # Default for other packages
```

---

## Package Access Control

### Public Packages (from npmjs.org)

```yaml
# configs/artifacts/verdaccio/config.yaml
packages:
  '**':
    access: $all          # Anyone can download
    publish: $authenticated  # Only authenticated users can publish
    proxy: npmjs          # Proxy to npmjs.org
```

### Private Scoped Packages

```yaml
packages:
  '@mycompany/*':
    access: $authenticated  # Only authenticated users can download
    publish: $authenticated
    # No proxy - hosted only in Verdaccio
```

---

## Authentication

### htpasswd File

Verdaccio uses htpasswd for user management:

```bash
# View users
docker compose exec verdaccio cat /verdaccio/storage/htpasswd

# Format: username:encrypted-password
```

### Add User Manually

```bash
# Generate password hash
docker compose exec verdaccio htpasswd -nB username

# Append to htpasswd file
docker compose exec verdaccio sh -c 'echo "username:$2y$..." >> /verdaccio/storage/htpasswd'
```

### Remove User

```bash
# Edit htpasswd file
docker compose exec verdaccio vi /verdaccio/storage/htpasswd

# Remove user line
```

---

## Monitoring and Metrics

### Web UI

Access at `http://localhost:4873`:
- Browse packages
- View package details
- Search packages
- View download statistics

### Logs

```bash
# View real-time logs
docker compose logs -f verdaccio

# Search for specific package
docker compose logs verdaccio | grep "package-name"

# View authentication attempts
docker compose logs verdaccio | grep "auth"
```

### Storage Metrics

```bash
# Total storage used
docker compose exec verdaccio du -sh /verdaccio/storage

# Package count
docker compose exec verdaccio find /verdaccio/storage/data -type d -name 'package.json' | wc -l

# Largest packages
docker compose exec verdaccio du -h /verdaccio/storage/data/* | sort -hr | head -10
```

---

## Troubleshooting

### Cannot Install Packages

**Check registry configuration**:
```bash
npm config get registry
# Should show: http://localhost:4873/
```

**Test connection**:
```bash
curl http://localhost:4873/
# Should return Verdaccio info
```

**Check Verdaccio logs**:
```bash
docker compose logs verdaccio | tail -50
```

### Cannot Publish Packages

**Verify authentication**:
```bash
npm whoami --registry http://localhost:4873
# Should show your username
```

**Check publish permissions**:
```yaml
# configs/artifacts/verdaccio/config.yaml
packages:
  '**':
    publish: $authenticated  # Must be authenticated
```

### Storage Full

**Check current usage**:
```bash
docker compose exec verdaccio df -h /verdaccio/storage
```

**Manually trigger eviction**:
```bash
# Restart Verdaccio to force storage check
docker compose restart verdaccio
```

**Increase storage limit**:
```yaml
# configs/artifacts/verdaccio/config.yaml
max_storage_size: 100gb  # Increase from 50gb
```

### Package Not Found

**Check if package exists**:
```bash
curl http://localhost:4873/package-name
```

**Force re-download from npmjs.org**:
```bash
# Clear package from cache
docker compose exec verdaccio rm -rf /verdaccio/storage/data/package-name

# Next install will re-download
npm install package-name
```

---

## Backup and Restore

### Backup Verdaccio Data

```bash
# Stop Verdaccio
docker compose stop verdaccio

# Backup storage volume
docker run --rm \
  -v homelab_verdaccio-data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/verdaccio-backup-$(date +%Y%m%d).tar.gz -C /data .

# Start Verdaccio
docker compose start verdaccio
```

### Restore Verdaccio Data

```bash
# Stop Verdaccio
docker compose stop verdaccio

# Restore storage volume
docker run --rm \
  -v homelab_verdaccio-data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar xzf /backup/verdaccio-backup-20250121.tar.gz -C /data

# Start Verdaccio
docker compose start verdaccio
```

---

## Advanced Configuration

### Custom Uplink Timeout

```yaml
# configs/artifacts/verdaccio/config.yaml
uplinks:
  npmjs:
    url: https://registry.npmjs.org/
    timeout: 60s  # Increase from default 30s
    max_fails: 5
    fail_timeout: 300
```

### Multiple Uplinks

```yaml
uplinks:
  npmjs:
    url: https://registry.npmjs.org/
  
  github:
    url: https://npm.pkg.github.com/
    
packages:
  '@github-org/*':
    proxy: github
  
  '**':
    proxy: npmjs
```

### Rate Limiting

```yaml
# Limit concurrent downloads
max_body_size: 100mb
max_age_in_sec: 86400

# Connection limits
server:
  keepAliveTimeout: 60
  maxHeaderSize: 8192
```

---

## Integration Examples

### Docker Build

```dockerfile
# Dockerfile
FROM node:18-alpine

WORKDIR /app

# Configure npm to use Verdaccio
RUN npm config set registry http://verdaccio:4873

# Copy package files
COPY package*.json ./

# Install dependencies (from Verdaccio cache)
RUN npm ci --only=production

COPY . .

CMD ["node", "index.js"]
```

### CI/CD (GitHub Actions)

```yaml
# .github/workflows/build.yml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
      
      - name: Configure npm registry
        run: npm config set registry http://verdaccio:4873
      
      - name: Install dependencies
        run: npm ci
      
      - name: Build
        run: npm run build
```

### pnpm Configuration

```ini
# .npmrc
registry=http://localhost:4873/
//localhost:4873/:_authToken="YOUR_AUTH_TOKEN"

# pnpm-specific
shamefully-hoist=true
strict-peer-dependencies=false
```

### Yarn Configuration

```yaml
# .yarnrc.yml
npmRegistryServer: "http://localhost:4873"
npmAuthToken: "YOUR_AUTH_TOKEN"
```

---

## Security Best Practices

### 1. Use Authentication

```yaml
# Require authentication for all operations
packages:
  '**':
    access: $authenticated
    publish: $authenticated
```

### 2. Secure Credentials

```bash
# Never commit .npmrc with tokens
echo ".npmrc" >> .gitignore

# Use environment variables
NPM_TOKEN=your-token npm install
```

### 3. Enable HTTPS (Production)

```yaml
# Use reverse proxy (nginx/traefik) for HTTPS
https:
  key: /path/to/key.pem
  cert: /path/to/cert.pem
```

### 4. Regular Updates

```bash
# Update Verdaccio image
docker compose pull verdaccio
docker compose up -d verdaccio
```

---

## Performance Optimization

### Cache Hit Rate

```bash
# Monitor cache effectiveness
docker compose logs verdaccio | grep -c "cached"
docker compose logs verdaccio | grep -c "downloading"
```

### Storage Performance

```bash
# Use SSD for storage volume
# Mount point: /verdaccio/storage

# Check I/O performance
docker compose exec verdaccio dd if=/dev/zero of=/verdaccio/storage/test bs=1M count=100
```

---

## References

- [Verdaccio Documentation](https://verdaccio.org/docs/what-is-verdaccio)
- [Configuration Reference](https://verdaccio.org/docs/configuration)
- [Authentication](https://verdaccio.org/docs/authentication)
- [Packages Access](https://verdaccio.org/docs/packages)
