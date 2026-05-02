---
id: l-improvement-002
title: Standardize container user management patterns across LocalNet
status: open
deps: []
links: []
created: 2026-03-25T15:41:00Z
type: improvement
priority: medium
description: Create standardized patterns for container user privilege dropping and management across all LocalNet containers
---

# Standardize container user management patterns across LocalNet

Based on assessment from ticket l-11ebc2b4, create standardized container user management:

## Current State
- nix-sidecar: Uses PUID/PGID with proper privilege dropping
- Other containers: May have inconsistent user management

## Standardization Requirements

### 1. User Creation Pattern
- Use PUID/PGID environment variables consistently
- Create users with proper group membership
- Set up home directories with correct permissions

### 2. Privilege Dropping Pattern  
- Use numeric IDs (PUID/PGID) instead of usernames
- Implement secure setpriv/chroot user switching
- Add proper error handling and warnings

### 3. Healthcheck Pattern
- Use getent passwd for UID-to-username resolution
- Implement consistent user validation logic
- Add security boundary checks

### 4. Documentation Pattern
- Document user management approach in each container
- Create shared user management utilities
- Add security best practices documentation

## Containers to Review
- nix-sidecar ✅ (completed)
- base-debnix
- base-dev  
- hapi-client
- All other LocalNet containers

## Implementation Plan
1. Audit existing containers for user management patterns
2. Create shared user management scripts/templates
3. Update containers to use standardized patterns
4. Add automated tests for user privilege dropping
5. Document best practices in internal-docs/
