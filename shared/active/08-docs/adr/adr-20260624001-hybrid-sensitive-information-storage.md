---
modeline: "vim: set ft=markdown:"
title: "ADR: Hybrid Sensitive Information Storage Strategy"
adr-id: "20260624001"
slug: "hybrid-sensitive-information-storage"
url: "https://github.com/levonk/infrahub/blob/main/shared/active/08-docs/adr/adr-20260624001-hybrid-sensitive-information-storage.md"
synopsis: "Centralized per-client vault storage for shared secrets with in-service storage for service-specific transient secrets"
author: "https://github.com/levonk"
date-created: "2026-06-24"
date-updated: "2026-06-24"
date-review: "2026-12-24"
date-triggers: ["2026-06-24"]
version: "1.0.0"
status: "accepted"
aliases: []
tags: [doc/architecture/adr]
supersedes: []
superseded-by: []
related-to: []
scope:
  impact-scope: [ansible-vault, secret-management, security, client-configurations]
  excluded-scope: [public-documentation, shared-service-definitions]
client-scope: [levonk]
---

# Decision Record: Hybrid Sensitive Information Storage Strategy

- belongs in `shared/active/08-docs/adr/adr-*.md`

---

## Context

The infrahub repository manages infrastructure configurations for multiple clients while maintaining a shared service library. We need a strategy for handling sensitive information (passwords, API keys, tokens) that balances:

1. **Security**: Proper protection of secrets
2. **Maintainability**: Easy secret rotation and updates
3. **Scalability**: Support for multiple clients without duplication
4. **Consistency**: Single source of truth for shared secrets

**Current Challenge**: 
- Need to determine whether to distribute secrets at point of use (service-specific) or centralize per client
- Must ensure shared/ path never contains sensitive information
- Must support per-client isolation (currently only levonk/ client exists)

## Constraints

- **Security**: Sensitive information must never be committed to git in plaintext
- **Client Isolation**: Each client's secrets must be isolated from other clients
- **Shared Path Cleanliness**: The `shared/` directory must remain free of any client-specific sensitive data
- **Ansible Compatibility**: Must work with Ansible's vault system
- **Operational Efficiency**: Secret rotation should be simple and reliable

## Decision

**Adopt a hybrid approach with centralized per-client vault storage for shared secrets and in-service storage for service-specific transient secrets.**

### Core Principles

1. **Per-Client Central Vault**: All shared secrets stored in client-specific vault files
2. **Shared Path Clean**: `shared/` directory contains no sensitive information
3. **In-Service Transient Secrets**: Service-specific transient secrets (JWT tokens, session keys) stored within service configurations
4. **Ansible Variable Distribution**: Use Ansible vault variables for secure distribution at runtime

## Rationale

### Why Central Per-Client Vault?

**Benefits:**
- **Single Source of Truth**: One location to rotate shared secrets
- **Consistency**: All services using the same secret get updates simultaneously
- **Auditability**: Easy to see what secrets exist per client
- **Operational Efficiency**: Change once, deploy everywhere
- **Ansible Native**: Leverages existing Ansible vault infrastructure

**Trade-offs:**
- **Blast Radius**: Vault compromise exposes all client secrets (mitigated by strong access controls)
- **Access Control**: Need to manage vault file permissions per client

### Why In-Service Storage for Transient Secrets?

**Benefits:**
- **Service Isolation**: Each service manages its own transient secrets
- **Lifecycle Alignment**: Secrets live and die with the service
- **Reduced Vault Bloat**: Transient secrets don't clutter central vault
- **Service Autonomy**: Services can generate/rotate their own transient secrets

**Trade-offs:**
- **Distribution Complexity**: Need mechanisms for secure in-service secret generation
- **Audit Challenges**: Harder to track transient secret lifecycle

### Why Shared Path Must Remain Clean

The `shared/` directory contains reusable service definitions, roles, and configurations that should work across any client deployment. Including client-specific secrets would:

1. **Break Reusability**: Shared services couldn't be used by other clients
2. **Create Security Risk**: Accidental exposure of one client's secrets to another
3. **Violate Separation of Concerns**: Mix client-specific with generic configurations
4. **Compromise Multi-Tenancy**: Prevent clean client isolation

## Technical Approach

### 1. Per-Client Vault Structure

```
levonk/active/02-config/ansible/group_vars/infrahub-levonk-all.vault.yml
```

**Contains:**
- Database passwords (PostgreSQL, Redis, etc.)
- API keys (Cloudflare, external services)
- Authentication credentials (admin passwords, service accounts)
- Encryption keys (JWT secrets, session secrets, storage encryption)
- VPN credentials (NordVPN, Tailscale auth keys)
- Service integration secrets (AI services, monitoring stack)

**Example:**
```yaml
# Database Secrets
vault_authelia_postgres_password: "secure-generated-password"
vault_authelia_redis_password: "secure-generated-password"

# Authentication Secrets
vault_authelia_admin_password: "$argon2id$v=19$m=65536,t=3,p=4$hash"
vault_authelia_jwt_secret: "secure-random-32-char-string"
vault_authelia_session_secret: "secure-random-32-char-string"
vault_authelia_storage_encryption_key: "secure-random-32-char-string"

# External API Secrets
vault_cloudflare_api_token: "secure-api-token"
vault_cloudflare_zone_id: "zone-id"

# VPN Secrets
vault_nordvpn_openvpn_user: "username"
vault_nordvpn_openvpn_pass: "password"
vault_tailscale_auth_key: "tskey-auth-key"

# Monitoring Stack
vault_grafana_admin_password: "secure-password"
vault_elasticsearch_password: "secure-password"

# AI Services
vault_ai_postgres_password: "secure-password"
vault_ai_neo4j_password: "secure-password"
```

### 2. In-Service Transient Secrets

**Stored in:** Service-specific configuration files or generated at runtime

**Examples:**
- **JWT Tokens**: Generated by Authelia for user sessions, stored in Redis
- **Session Keys**: Generated by web applications, stored in session storage
- **OAuth Tokens**: Generated during OAuth flows, stored in service databases
- **API Session Tokens**: Generated by external APIs, cached by services
- **Temporary Encryption Keys**: Generated for specific operations, rotated regularly

**Implementation Pattern:**
```yaml
# Service configuration (in client-specific path)
service:
  jwt:
    secret: "{{ vault_service_jwt_secret }}"  # From vault for signing
    expiration: "1h"
  session:
    storage: "redis"
    key_prefix: "service:session:"
    # Session tokens generated and stored in Redis at runtime
```

### 3. Ansible Variable Distribution

**Reference Pattern:**
```yaml
# In client-specific host_vars or inventory
proxy_authelia_postgres_password: "{{ vault_authelia_postgres_password }}"
proxy_authelia_redis_password: "{{ vault_authelia_redis_password }}"
proxy_authelia_jwt_secret: "{{ vault_authelia_jwt_secret }}"
```

**Benefits:**
- Single definition in vault
- Multiple references across services
- Ansible handles secure distribution
- Easy rotation (update vault, redeploy)

### 4. Shared Path Cleanliness Enforcement

**Rules:**
1. No vault files in `shared/` directory
2. No hardcoded secrets in `shared/` service definitions
3. All secrets must use vault variable references
4. Client-specific configurations only in client paths (`levonk/`, future clients)

**Validation:**
```bash
# Pre-commit hook to check for secrets in shared/
grep -r "password\|secret\|token\|api_key" shared/ --include="*.yml" --include="*.yaml"
```

## Affected Components

### People
- **DevOps Engineers**: Need to follow vault structure for new clients
- **Security Team**: Need to audit vault access and rotation procedures
- **Service Developers**: Need to use vault variables instead of hardcoded secrets

### Processes
- **Secret Rotation**: Update vault file, redeploy affected services
- **Client Onboarding**: Create new client vault file following structure
- **Security Audits**: Review vault files and access logs
- **Service Deployment**: Ensure vault variables are properly referenced

### Components
- **Ansible Vault**: Central secret storage mechanism
- **Service Configurations**: Updated to use vault variable references
- **CI/CD Pipelines**: Must handle vault password securely
- **Monitoring**: Alert on vault access anomalies

## Consequences

### Positive

**Security:**
- Centralized secret management with proper encryption
- Clear separation between shared and client-specific data
- Audit trail for secret access and changes
- Consistent secret handling across all services

**Operations:**
- Single location for secret rotation
- Easy to add new clients with isolated secrets
- Reduced risk of secret duplication errors
- Simplified secret inventory management

**Development:**
- Clear pattern for handling secrets in new services
- Shared services remain truly reusable
- Reduced cognitive load for secret management
- Better onboarding experience for new team members

### Negative

**Security:**
- Single point of compromise (mitigated by strong vault password and access controls)
- Need to manage vault file permissions carefully
- Vault password management becomes critical

**Operations:**
- Need to establish vault access procedures
- Initial setup requires vault password generation and distribution
- Must ensure vault files are properly backed up

**Development:**
- Additional complexity for service-specific transient secrets
- Need to document in-service secret generation patterns
- Learning curve for proper vault variable usage

### Neutral

**Performance:**
- Minimal impact from Ansible variable resolution
- Vault decryption overhead is negligible for typical deployments
- In-service secret generation may have small performance cost

**Scalability:**
- Vault approach scales well to multiple clients
- In-service secrets scale with service count
- No significant performance degradation expected

## Alternatives Considered

### Option A: Point-of-Use Distribution

**Description:** Store each secret in the service configuration that uses it

**Pros:**
- Principle of least privilege
- Smaller blast radius if one service is compromised
- Services are self-contained

**Cons:**
- Secret duplication across services
- Rotation requires updating multiple locations
- Inconsistent secret management
- Harder to audit all secrets
- **REJECTED**: Operational complexity outweighs security benefits

### Option B: External Secret Management System

**Description:** Use HashiCorp Vault, AWS Secrets Manager, or similar

**Pros:**
- Advanced secret management features
- Dynamic secret generation
- Fine-grained access controls
- Audit logging

**Cons:**
- Additional infrastructure dependency
- Complexity increase
- Cost for managed solutions
- Overkill for current scale
- **REJECTED**: Ansible vault provides sufficient functionality for current needs

### Option C: Environment Variables Only

**Description:** Store all secrets in environment variables

**Pros:**
- Simple to implement
- Language-agnostic
- No Ansible dependency

**Cons:**
- Harder to manage across multiple services
- No built-in encryption
- Environment file security challenges
- **REJECTED**: Lacks encryption and audit capabilities of Ansible vault

## Rollout / Migration

### Phase 1: Documentation (Current)
- ✅ Create ADR documenting hybrid approach
- ✅ Define vault structure and naming conventions
- ✅ Establish shared path cleanliness rules

### Phase 2: Implementation
- [ ] Update existing levonk/ vault to follow new structure
- [ ] Remove hardcoded secrets from all configurations
- [ ] Add vault variable references to all services
- [ ] Implement shared path validation hooks

### Phase 3: Process Setup
- [ ] Document secret rotation procedures
- [ ] Set up vault access controls
- [ ] Configure vault backup procedures
- [ ] Train team on new secret management approach

### Phase 4: Validation
- [ ] Audit all configurations for compliance
- [ ] Test secret rotation process
- [ ] Validate shared path cleanliness
- [ ] Review access controls and logging

### Rollback Plan
If issues arise:
1. Revert to previous secret storage approach
2. Document issues and lessons learned
3. Address concerns in updated ADR
4. Re-rollout with mitigations

## To Investigate

1. **Automated Secret Rotation**: Explore tools for automated secret rotation
2. **Vault Access Logging**: Implement detailed vault access logging
3. **Secret Scanning**: Integrate automated secret scanning in CI/CD
4. **Multi-Client Support**: Test approach with additional clients
5. **Transient Secret Lifecycle**: Define patterns for in-service secret lifecycle management

## Validation

**Success Metrics:**
- Zero hardcoded secrets in git repository
- All shared/ path files contain no sensitive information
- Secret rotation completes in under 1 hour
- New client onboarding follows established pattern
- Security audits show no secret management violations

**Failure Conditions:**
- Secrets found in shared/ directory
- Secret rotation causes service outages
- Vault access incidents occur
- Team cannot follow established patterns

## Review Schedule

**Review Date:** 2026-12-24 (6 months from adoption)

**Review Triggers:**
- Addition of new client with different secret management needs
- Security incident related to secret management
- Significant change in Ansible vault capabilities
- Team feedback on operational challenges

## Notes

- Current implementation only has levonk/ client, but approach designed for multi-client support
- Shared path cleanliness is critical for maintaining service reusability
- In-service transient secrets need further documentation and pattern establishment
- Vault password management is the single most critical operational security concern

## References

- [Ansible Vault Documentation](https://docs.ansible.com/ansible/latest/vault_guide/index.html)
- [Shared Path Structure](../shared/active/08-docs/)
- [Client Configuration Structure](../../levonk/active/02-config/ansible/)
- [Security Best Practices](../shared/active/08-docs/security/)
- [Existing ADRs](./adr-001-netbird-cloud-controlplane.md)

<!-- vim: set ft=markdown: -->
