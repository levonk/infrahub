# Docker Config Directory Issue

## Problem

When Docker Compose tries to mount a file that doesn't exist, it **creates a directory** instead of failing. This causes the following error when containers try to start:

```
Error: cannot create subdirectories in "/var/lib/docker/rootfs/.../config.yaml": not a directory
Are you trying to mount a directory onto a file (or vice-versa)?
```

## Root Cause

In `docker-compose.yml`, when you have a volume mount like:

```yaml
volumes:
  - ./configs/web/privoxy/config:/etc/privoxy/config:ro
```

If `./configs/web/privoxy/config` doesn't exist, Docker will:
1. Create it as a **directory** (not a file)
2. Try to mount this directory to `/etc/privoxy/config` in the container
3. Fail because the container expects a **file**, not a directory

## Affected Files

The following config files were created as directories by Docker:

- `configs/logging/loki.yaml`
- `configs/logging/promtail.yaml`
- `configs/monitoring/blackbox.yml`
- `configs/web/squid.conf`
- `configs/web/envoy.yaml`
- `configs/web/privoxy/config`
- `configs/artifacts/verdaccio/config.yaml`

## Solution

### Quick Fix

Use the new Makefile targets:

```bash
# Remove Docker-created config directories
make clean-configs

# Recreate all config files
make fix-configs
```

### Manual Fix

If you need to fix individual files:

```bash
# Remove the directory (may need Docker to do this if owned by root)
docker run --rm -v "$(pwd)/configs:/configs" alpine rm -rf /configs/web/privoxy/config

# Create the file
cat > configs/web/privoxy/config << 'EOF'
# Your config content here
EOF
```

### Prevention

**Always create config files BEFORE running `docker compose up`!**

1. Create all config files first:
   ```bash
   ./scripts/create-configs.sh
   ```

2. Then start services:
   ```bash
   make up
   ```

## Makefile Targets

### `make clean-configs`

Safely removes Docker-created config directories without affecting data volumes.

- Uses Alpine container to handle root-owned directories
- Finds and removes directories with config file names
- Safe to run - doesn't delete data volumes

### `make fix-configs`

Recreates all config files from templates.

- Runs `clean-configs` first
- Executes `scripts/create-configs.sh`
- Creates all required config files

## Technical Details

### Why Docker Creates Directories

Docker's volume mount behavior:
- If source path exists: Mount it as-is (file or directory)
- If source path doesn't exist: Create as **directory** and mount

This is by design for Docker volumes, but problematic for config files.

### Detection

Find Docker-created config directories:

```bash
find configs -type d \( \
  -name "*.conf" -o \
  -name "*.yaml" -o \
  -name "*.yml" -o \
  -name "config" \
\)
```

### Cleanup

Remove using Docker (handles permissions):

```bash
docker run --rm -v "$(pwd)/configs:/configs" alpine sh -c \
  'find /configs -type d \( \
    -name "*.conf" -o \
    -name "*.yaml" -o \
    -name "*.yml" -o \
    -name "config" \
  \) -exec rm -rf {} + 2>/dev/null || true'
```

## Best Practices

1. **Always create config files before first run**
   - Run `./scripts/create-configs.sh` in setup
   - Add to documentation/README

2. **Use `make fix-configs` after git clone**
   - Config files should be in `.gitignore` if they contain secrets
   - Recreate from templates after clone

3. **Check file types before starting**
   ```bash
   file configs/web/privoxy/config
   # Should output: ASCII text
   # Not: directory
   ```

4. **Add to CI/CD**
   - Run `scripts/create-configs.sh` in CI before tests
   - Validate config files exist and are files (not directories)

## Troubleshooting

### Error: "not a directory"

```bash
make clean-configs
make fix-configs
docker compose up -d
```

### Error: "Permission denied" when removing configs

Use Docker to remove (it runs as root):

```bash
make clean-configs
```

### Config file is empty after creation

Check the `scripts/create-configs.sh` script for the template content.

## References

- [Docker Compose Volumes Documentation](https://docs.docker.com/compose/compose-file/compose-file-v3/#volumes)
- [Docker Volume Mount Behavior](https://docs.docker.com/storage/volumes/)
