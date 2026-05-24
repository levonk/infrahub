# Nexus Java Preferences Directory Fix

## Problem

Nexus container startup produced warnings:

```log
2025-10-26 06:31:25,237+0000 WARN  [main] *SYSTEM java.util.prefs - Couldn't create user preferences directory. User preferences are unusable.
2025-10-26 06:31:25,240+0000 WARN  [main] *SYSTEM java.util.prefs - java.io.IOException: No such file or directory
```

## Root Cause

The `nexus` user (non-root) running inside the container lacked a writable Java preferences directory at `~/.java/.userPrefs`. When Java tried to create this directory at startup, it failed because:

- The directory structure didn't exist
- The `nexus` user didn't have write permissions to create it
- The base Sonatype image doesn't pre-create this directory

## Solution

Modified `Dockerfile` to pre-create the Java preferences directory with proper ownership and permissions before switching to the `nexus` user:

```dockerfile
# Ensure nexus user has proper home directory and Java preferences directory
RUN mkdir -p /opt/sonatype/nexus/.java/.userPrefs \
    && chown -R nexus:nexus /opt/sonatype/nexus/.java \
    && chmod -R 0755 /opt/sonatype/nexus/.java
```

This ensures:

- Directory exists before Nexus starts
- `nexus` user owns the directory
- Proper read/write/execute permissions are set

## Files Modified

- `/home/micro/p/gh/lrepo52/job-aide/apps/active/devops/localnet/services/artifact/nexus/docker/Dockerfile`
  - Lines 9-12: Added Java preferences directory creation

## Impact

- Eliminates Java preferences warnings on startup
- No functional impact on Nexus operation (warnings were non-fatal)
- Cleaner logs for debugging
- Follows container best practices (pre-create required directories)

## Verification

After rebuilding the image, Nexus should start without the Java preferences warnings.
