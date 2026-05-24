# Nexus Entrypoint Fix

## Problem

The Dockerfile was failing with:
```
exec /opt/sonatype/docker-entrypoint.sh: no such file or directory
```

## Root Cause

The base image `sonatype/nexus3:3.85.0-alpine` does **not** have `/opt/sonatype/docker-entrypoint.sh`. It only has `/opt/sonatype/start-nexus-repository-manager.sh`, which is a simple wrapper that runs `nexus run`.

The custom entrypoint was trying to reference a non-existent file from the base image.

## Solution

The fix directly invokes Nexus startup after our custom setup:

### Changes Made

1. **Dockerfile** (lines 12-16):
   - Simplified to just copy our custom entrypoint
   - No need to preserve a non-existent base image entrypoint

2. **entrypoint.sh** (lines 16-18):
   - After running our custom setup (Java preferences, Docker proxy config), directly invoke Nexus
   - Uses `su-exec` to switch to the `nexus` user before running `./bin/nexus run`
   - This matches what the base image does, but with our setup steps first

### How It Works

```
Container Start
    ↓
Custom Entrypoint (/opt/sonatype/docker-entrypoint.sh)
    ├─ Create Java preferences directory (as root)
    ├─ Configure Docker proxy (if enabled)
    └─ Switch to nexus user and run ./bin/nexus run
```

## Files Modified

- `/home/micro/p/gh/lrepo52/job-aide/apps/active/devops/localnet/services/artifact/nexus/docker/Dockerfile`
- `/home/micro/p/gh/lrepo52/job-aide/apps/active/devops/localnet/services/artifact/nexus/docker/entrypoint.sh`

## Testing

Rebuild and start the Nexus container:

```bash
docker-compose -f docker-compose.yml build nexus && docker-compose up nexus
```

The container should now start successfully without the "no such file or directory" error.
