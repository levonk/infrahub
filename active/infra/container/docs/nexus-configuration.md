# Nexus Repository Configuration Guide

**Feature**: Home Lab In-a-Box  
**Date**: 2025-01-21  
**Service**: Nexus Repository Manager 3

## Overview

Nexus Repository Manager provides centralized artifact storage and proxying for multiple package formats. This guide covers initial setup, repository configuration, and client configuration for Maven, npm, PyPI, and Docker.

---

## Initial Setup

### 1. Access Nexus Web UI

```bash
# Nexus is available at:
http://localhost:8081

# Default credentials (CHANGE IMMEDIATELY):
Username: admin
Password: Located in /nexus-data/admin.password inside container
```

### 2. Retrieve Initial Admin Password

```bash
# Get initial password
docker compose exec nexus cat /nexus-data/admin.password

# Or view logs for password
docker compose logs nexus | grep "admin password"
```

### 3. Complete Setup Wizard

1. Login with admin and initial password
2. Change admin password (store securely)
3. Configure anonymous access:
   - **Enable** for public repositories (Maven Central, npmjs.org)
   - **Disable** for private/internal repositories
4. Click "Finish"

---

## Repository Configuration

### Maven Repositories

#### 1. Maven Central Proxy

**Purpose**: Cache artifacts from Maven Central

```
Repository Type: maven2 (proxy)
Name: maven-central
Remote URL: https://repo1.maven.org/maven2/
Version Policy: Release
Layout Policy: Strict

Proxy Settings:
- Content Max Age: 1440 (24 hours)
- Metadata Max Age: 1440 (24 hours)

Storage:
- Blob Store: default
- Strict Content Type Validation: Enabled
```

#### 2. Maven Snapshots Proxy

**Purpose**: Cache SNAPSHOT artifacts

```
Repository Type: maven2 (proxy)
Name: maven-snapshots
Remote URL: https://oss.sonatype.org/content/repositories/snapshots/
Version Policy: Snapshot
Layout Policy: Strict
```

#### 3. Maven Hosted (Private)

**Purpose**: Host internal/private Maven artifacts

```
Repository Type: maven2 (hosted)
Name: maven-releases
Version Policy: Release
Layout Policy: Strict
Deployment Policy: Disable Redeploy
```

#### 4. Maven Group (Aggregator)

**Purpose**: Single endpoint for all Maven repositories

```
Repository Type: maven2 (group)
Name: maven-public
Member Repositories (in order):
  1. maven-releases (hosted)
  2. maven-central (proxy)
  3. maven-snapshots (proxy)
```

---

### npm Repositories

#### 1. npmjs.org Proxy

**Purpose**: Cache packages from npmjs.org

```
Repository Type: npm (proxy)
Name: npm-proxy
Remote URL: https://registry.npmjs.org
Negative Cache: Enabled
Negative Cache TTL: 1440

Storage:
- Blob Store: default
```

#### 2. npm Hosted (Private)

**Purpose**: Host internal npm packages

```
Repository Type: npm (hosted)
Name: npm-private
Deployment Policy: Allow Redeploy
```

#### 3. npm Group (Aggregator)

```
Repository Type: npm (group)
Name: npm-public
Member Repositories:
  1. npm-private (hosted)
  2. npm-proxy (proxy)
```

---

### PyPI Repositories

#### 1. PyPI Proxy

**Purpose**: Cache packages from pypi.org

```
Repository Type: pypi (proxy)
Name: pypi-proxy
Remote URL: https://pypi.org
```

#### 2. PyPI Hosted (Private)

```
Repository Type: pypi (hosted)
Name: pypi-private
```

#### 3. PyPI Group

```
Repository Type: pypi (group)
Name: pypi-public
Member Repositories:
  1. pypi-private (hosted)
  2. pypi-proxy (proxy)
```

---

### Docker Repositories

#### 1. Docker Hub Proxy

**Purpose**: Cache images from Docker Hub

```
Repository Type: docker (proxy)
Name: docker-hub
Remote URL: https://registry-1.docker.io
Docker Index: Use Docker Hub

HTTP Port: 8082 (for pull)
Enable Docker V1 API: No
```

#### 2. Docker Hosted (Private)

```
Repository Type: docker (hosted)
Name: docker-private
HTTP Port: 8083 (for push/pull)
Enable Docker V1 API: No
```

#### 3. Docker Group

```
Repository Type: docker (group)
Name: docker-public
HTTP Port: 8084
Member Repositories:
  1. docker-private (hosted)
  2. docker-hub (proxy)
```

---

## LRU Eviction Configuration (T067a-b)

### Storage Quota and Cleanup Policies

#### 1. Configure Blob Store Quota

```
Settings → Repository → Blob Stores → default

Soft Quota:
- Type: Space Remaining Quota
- Limit: 20% (triggers cleanup at 80% full)
```

#### 2. Create Cleanup Policy

```
Settings → Repository → Cleanup Policies → Create Cleanup Policy

Name: lru-eviction-policy
Format: All Formats
Criteria:
- Last Downloaded: 90 days
- Component Age: 180 days
- Asset Name Matcher: .* (all)

Action: Delete components
```

#### 3. Apply Policy to Repositories

For each proxy repository:
```
Settings → Repository → Repositories → [Select Repository]

Cleanup Policies:
- Add: lru-eviction-policy
```

#### 4. Configure Cleanup Task

```
Settings → System → Tasks → Create Task

Task Type: Admin - Compact blob store
Task Name: compact-blob-store-daily
Blob Store: default
Schedule: Daily at 2:00 AM
```

```
Task Type: Repository - Delete unused components
Task Name: cleanup-unused-components
Repository: All Repositories
Schedule: Daily at 3:00 AM
```

---

## Prometheus Metrics (T067b)

### Enable Metrics Endpoint

```
Settings → System → Capabilities → Prometheus Metrics

Enable: Yes
```

### Available Metrics

```
# Nexus exposes metrics at:
http://localhost:8081/service/metrics/prometheus

# Key metrics for eviction monitoring:
nexus_blobstore_total_size_bytes{blobstore="default"}
nexus_blobstore_available_space_bytes{blobstore="default"}
nexus_component_count{repository="maven-central"}
nexus_component_downloaded_count{repository="maven-central"}
```

### Add to Prometheus

Edit `configs/monitoring/prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'nexus'
    static_configs:
    - targets: ['nexus:8081']
      labels:
        service: 'artifacts'
    metrics_path: '/service/metrics/prometheus'
```

---

## Client Configuration

### Maven (settings.xml)

Create or edit `~/.m2/settings.xml`:

```xml
<settings>
  <mirrors>
    <mirror>
      <id>nexus</id>
      <mirrorOf>*</mirrorOf>
      <url>http://localhost:8081/repository/maven-public/</url>
    </mirror>
  </mirrors>
  
  <servers>
    <server>
      <id>nexus</id>
      <username>admin</username>
      <password>your-password</password>
    </server>
  </servers>
  
  <profiles>
    <profile>
      <id>nexus</id>
      <repositories>
        <repository>
          <id>central</id>
          <url>http://localhost:8081/repository/maven-public/</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </repository>
      </repositories>
    </profile>
  </profiles>
  
  <activeProfiles>
    <activeProfile>nexus</activeProfile>
  </activeProfiles>
</settings>
```

### npm (.npmrc)

Create or edit `~/.npmrc`:

```ini
# Use Nexus npm group
registry=http://localhost:8081/repository/npm-public/

# Authentication (if required)
# Generate token in Nexus UI: User → [username] → NuGet API Key
_auth=YWRtaW46cGFzc3dvcmQ=
email=your-email@example.com
always-auth=true

# Or use npm login
# npm login --registry=http://localhost:8081/repository/npm-public/
```

### pip (pip.conf)

**Linux/macOS**: `~/.pip/pip.conf`  
**Windows**: `%APPDATA%\pip\pip.ini`

```ini
[global]
index-url = http://localhost:8081/repository/pypi-public/simple
trusted-host = localhost
```

### Docker (daemon.json)

**Linux**: `/etc/docker/daemon.json`  
**Windows**: Docker Desktop Settings → Docker Engine

```json
{
  "insecure-registries": ["localhost:8082", "localhost:8083", "localhost:8084"],
  "registry-mirrors": ["http://localhost:8084"]
}
```

**Restart Docker**:
```bash
# Linux
sudo systemctl restart docker

# Windows/macOS
# Restart Docker Desktop
```

**Docker Login**:
```bash
docker login localhost:8083
Username: admin
Password: your-password
```

---

## Usage Examples

### Maven

```bash
# Build project (uses Nexus automatically via settings.xml)
mvn clean install

# Deploy to Nexus hosted repository
mvn deploy
```

### npm

```bash
# Install packages (uses Nexus automatically via .npmrc)
npm install express

# Publish to Nexus private registry
npm publish --registry=http://localhost:8081/repository/npm-private/
```

### pip

```bash
# Install packages (uses Nexus automatically via pip.conf)
pip install requests

# Upload to Nexus (requires twine)
twine upload --repository-url http://localhost:8081/repository/pypi-private/ dist/*
```

### Docker

```bash
# Pull from Docker Hub via Nexus
docker pull localhost:8082/nginx:latest

# Tag and push to Nexus private registry
docker tag myapp:latest localhost:8083/myapp:latest
docker push localhost:8083/myapp:latest

# Pull from Nexus group (tries private, then Hub)
docker pull localhost:8084/myapp:latest
```

---

## Monitoring and Maintenance

### Check Storage Usage

```bash
# Via Nexus UI
Settings → System → Support → System Information
Look for: "filestore.default.totalSpace" and "filestore.default.availableSpace"

# Via API
curl -u admin:password http://localhost:8081/service/rest/v1/status
```

### View Cleanup Logs

```
Settings → System → Tasks → [Select cleanup task] → View Log
```

### Manual Cleanup

```
Settings → Repository → Repositories → [Select Repository] → Repair - Rebuild repository metadata
```

---

## Troubleshooting

### Cannot Connect to Nexus

**Check container status**:
```bash
docker compose ps nexus
docker compose logs nexus
```

**Check port binding**:
```bash
netstat -an | grep 8081
```

### Maven Cannot Download Artifacts

**Verify repository configuration**:
```bash
curl http://localhost:8081/repository/maven-public/
```

**Check settings.xml**:
```bash
mvn help:effective-settings
```

### npm Cannot Install Packages

**Test registry**:
```bash
npm config get registry
curl http://localhost:8081/repository/npm-public/
```

**Clear npm cache**:
```bash
npm cache clean --force
```

### Docker Cannot Pull Images

**Verify insecure registry**:
```bash
docker info | grep "Insecure Registries"
```

**Test connection**:
```bash
curl http://localhost:8082/v2/_catalog
```

---

## Security Best Practices

### 1. Change Default Credentials

```
Settings → Security → Users → admin → Change Password
```

### 2. Create Service Accounts

```
Settings → Security → Users → Create User

For CI/CD:
- Username: ci-deploy
- Roles: nx-deploy (for deployments)

For Developers:
- Username: developer
- Roles: nx-anonymous (read-only)
```

### 3. Enable HTTPS (Production)

```
Settings → System → Capabilities → SSL Certificates

Upload certificate or use Let's Encrypt
```

### 4. Configure Access Control

```
Settings → Security → Realms
Active Realms:
- Local Authenticating Realm
- Docker Bearer Token Realm (for Docker)
```

---

## Backup and Restore

### Backup Nexus Data

```bash
# Stop Nexus
docker compose stop nexus

# Backup volume
docker run --rm \
  -v homelab_nexus-data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/nexus-backup-$(date +%Y%m%d).tar.gz -C /data .

# Start Nexus
docker compose start nexus
```

### Restore Nexus Data

```bash
# Stop Nexus
docker compose stop nexus

# Restore volume
docker run --rm \
  -v homelab_nexus-data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar xzf /backup/nexus-backup-20250121.tar.gz -C /data

# Start Nexus
docker compose start nexus
```

---

## References

- [Nexus Repository Manager Documentation](https://help.sonatype.com/repomanager3)
- [Repository Management Best Practices](https://help.sonatype.com/repomanager3/nexus-repository-administration/repository-management)
- [Cleanup Policies](https://help.sonatype.com/repomanager3/nexus-repository-administration/repository-management/cleanup-policies)
- [Docker Registry Configuration](https://help.sonatype.com/repomanager3/nexus-repository-administration/formats/docker-registry)
