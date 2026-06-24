# PRD: Traefik Proxy Stack with Authelia, CrowdSec, and Cloudflare Integration

## Document Information
- **Status**: Draft
- **Created**: 2026-06-20
- **Author**: AI Assistant
- **Target Audience**: Junior Developers, DevOps Engineers
- **Priority**: High (Security & Access Control)

## Executive Summary

Deploy a production-ready Traefik reverse proxy stack with Authelia authentication, CrowdSec security, and Cloudflare DNS integration on the OCI cloud server. The system will provide secure HTTPS access to services via `search.levonk.com` with password-based authentication, automated Let's Encrypt certificate management, and IP-based security protection. This deployment focuses initially on SearXNG as the first service, with a hybrid automation approach for future service registration.

## Problem Statement

The current infrastructure lacks secure external access to services. SearXNG is deployed and functional internally, but cannot be accessed securely from outside the Tailscale network. There is no centralized authentication mechanism, no SSL/TLS termination, and no automated service discovery. Each new service requires manual configuration with no standardized approach.

## Goals

### Primary Goals
1. **Secure External Access**: Enable HTTPS access to services via Cloudflare-managed domains
2. **Centralized Authentication**: Implement Authelia for unified authentication across all services
3. **Automated SSL Management**: Use Let's Encrypt with Traefik for automatic certificate provisioning
4. **Security Hardening**: Deploy CrowdSec for IP-based threat protection and rate limiting
5. **Service Automation**: Create hybrid system for easy service registration

### Secondary Goals
1. **Monitoring & Logging**: Implement comprehensive logging for all proxy components
2. **Scalability**: Design for future expansion to additional services
3. **Maintainability**: Create Ansible roles for repeatable deployments

## Non-Goals

- Full Cloudflare CDN proxy mode (using local SSL termination instead)
- SSO integration with external providers (Google, GitHub, etc.) in initial phase
- Multi-factor authentication (TOTP) in initial deployment
- Automatic service discovery without any configuration
- Load balancing across multiple Traefik instances

## Success Criteria

### Functional Requirements
- [ ] Traefik accessible via `frontdoor.levonk.com` with valid Let's Encrypt certificate
- [ ] SearXNG accessible via `search.levonk.com` with Authelia password authentication
- [ ] Authelia admin user can successfully authenticate and access protected services
- [ ] CrowdSec actively monitoring and blocking suspicious IPs
- [ ] Cloudflare DNS records automatically configured for new services
- [ ] All services accessible via Tailscale network without authentication
- [ ] Container logs accessible and monitored for all components

### Non-Functional Requirements
- [ ] SSL certificates automatically renewed before expiration
- [ ] Services remain available during Traefik restarts (graceful shutdown)
- [ ] Authentication response time < 500ms for local network
- [ ] Proxy stack uses < 2GB RAM total
- [ ] All configuration follows variable-driven approach (no hardcoded IPs/ports)
- [ ] Ansible deployment completes without manual intervention
- [ ] Rollback procedure documented and tested

### Security Requirements
- [ ] All external traffic forced through HTTPS (HTTP→HTTPS redirect)
- [ ] Authelia passwords stored as hashed values (never plaintext)
- [ ] CrowdSec bans IPs after 3 failed authentication attempts
- [ ] No services exposed without authentication (except health checks)
- [ ] Cloudflare API credentials stored in Ansible vault
- [ ] All containers run as non-root users
- [ ] Security audit passes with no critical findings

## User Stories

### As a Security Administrator
- I want to centrally manage user authentication across all services
- So that I can control access without configuring each service individually
- Acceptance Criteria: Single Authelia login provides access to all protected services

### As a Service Developer
- I want to register new services with minimal configuration
- So that I can quickly deploy services without understanding complex proxy setup
- Acceptance Criteria: New service accessible via Ansible variables + Docker labels

### As an End User
- I want to access services securely via HTTPS with a single password
- So that my traffic is encrypted and authentication is simple
- Acceptance Criteria: Login once, access all services, valid SSL certificate

### As a System Administrator
- I want to monitor proxy logs and security events centrally
- So that I can troubleshoot issues and respond to threats quickly
- Acceptance Criteria: All logs accessible via `docker logs` and log aggregation

## Technical Architecture

### System Architecture

```
Internet
    ↓
Cloudflare DNS (search.levonk.com → OCI IP)
    ↓
Traefik (443/80) → Let's Encrypt SSL
    ↓
CrowdSec Bouncer (IP filtering)
    ↓
Authelia (Authentication)
    ↓
SearXNG (8080) - Protected Service
    ↓
NordVPN (Privacy)
```

### Component Details

#### Traefik
- **Version**: Latest stable
- **Ports**: 80 (HTTP), 443 (HTTPS), 8882 (Health)
- **SSL**: Let's Encrypt with ACME TLS challenge
- **Configuration**: Static config + Dynamic config (file-based)
- **Plugins**: 
  - CrowdSec Bouncer (v1.4.4) - Actively used for IP-based security
  - GeoBlock (v0.3.3) - US-only geographic access control (must be applied to routing rules)

#### Authelia
- **Version**: Latest stable
- **Database**: Postgres
- **Authentication**: Password-based (Argon2 hashing)
- **Session Storage**: Redis
- **Configuration**: YAML-based with environment variable substitution

#### CrowdSec
- **Version**: Latest stable
- **Components**: 
  - CrowdSec (security engine)
  - CrowdSec Bouncer (Traefik plugin)
- **Configuration**: 
  - Default remediation profile (672h ban)
  - Custom profiles per service type
- **Database**: SQLite (stored in Docker volume)

#### Cloudflare Integration
- **API**: Cloudflare API v4
- **DNS**: A records pointing to OCI server IP
- **SSL**: DNS-only mode (local Let's Encrypt for SSL)
- **Automation**: Ansible module for DNS record management

### Network Architecture

```
Docker Networks:
- traefik-network: Traefik + Authelia + CrowdSec
- vpn-network: Shared with NordVPN + SearXNG
- service-networks: Individual service networks as needed

Port Mappings:
- 80:80 (Traefik HTTP)
- 443:443 (Traefik HTTPS)
- 8080:8080 (SearXNG - internal only)
```

## Implementation Plan

### Phase 1: Infrastructure Preparation
1. **Ansible Role Creation**
   - Create `proxy-traefik` role based on docker-linux boilerplate
   - Create `proxy-authelia` role based on docker-linux boilerplate
   - Create `security-crowdsec` role based on docker-linux boilerplate
   - Create `cloudflare-dns` role for DNS management

2. **Configuration Management**
   - Define Ansible variables in `host_vars/oci-cloud-server.yml`
   - Create vault for sensitive data (passwords, API keys)
   - Implement variable-driven configuration (no hardcoded values)

### Phase 2: Service Deployment
1. **Traefik Deployment**
   - Deploy Traefik container with ACME configuration
   - Configure Let's Encrypt email and storage
   - Set up Cloudflare DNS challenge (optional backup)
   - Configure experimental plugins (CrowdSec, GeoBlock)

2. **Authelia Deployment**
   - Deploy Authelia container with SQLite database
   - Configure user database with admin account
   - Set up session management and cookie security
   - Configure Traefik forward auth integration

3. **CrowdSec Deployment**
   - Deploy CrowdSec security engine
   - Deploy CrowdSec Bouncer for Traefik
   - Configure acquisition sources (Traefik logs)
   - Set up remediation profiles and ban durations

### Phase 3: Service Integration
1. **SearXNG Integration**
   - Add Traefik labels to SearXNG container
   - Configure dynamic routing rule for `search.levonk.com`
   - Add security middleware chain (GeoBlock + CrowdSec + Authelia) to SearXNG route
   - Test authentication flow end-to-end
   - Verify US-only geographic access control

2. **Cloudflare DNS Configuration**
   - Create Cloudflare API credentials in vault
   - Configure A record for `search.levonk.com`
   - Configure A record for `traefik.levonk.com`
   - Test DNS resolution and SSL certificate generation

### Phase 4: Service Registration System
1. **Hybrid Registration Framework**
   - Create Ansible variables for core service definitions
   - Implement Docker label convention for dynamic services
   - Create Ansible module for service registration
   - Document registration process for developers

2. **Automation Scripts**
   - Create helper script for service registration
   - Implement validation for service configurations
   - Add rollback capability for failed registrations

### Phase 5: Monitoring & Validation
1. **Logging Setup**
   - Configure centralized logging for all containers
   - Set up log rotation and retention policies
   - Implement health checks for all components
   - Create monitoring dashboard (optional)

2. **Security Validation**
   - Run security audit on deployment
   - Test SSL certificate validity and renewal
   - Verify authentication and authorization
   - Test CrowdSec IP blocking functionality

## Data Model

### Service Registration (Ansible Variables)

```yaml
# Core services defined in Ansible
proxy_services:
  traefik:
    domain: "traefik.levonk.com"
    auth_enabled: false
    security_level: "public"
    
  searxng:
    domain: "search.levonk.com"
    auth_enabled: true
    security_level: "protected"
    middleware:
      - geoblock
      - crowdsec-bouncer
      - authelia
```

### Authelia User Database

```yaml
users:
  admin:
    disabled: false
    displayname: "Admin"
    password: "$argon2id$v=19$m=65536,t=3,p=2..." # Hashed
    email: "admin@levonk.com"
    groups:
      - admins
```

### CrowdSec Configuration

```yaml
profiles:
  default:
    decisions:
      - type: ban
        duration: 672h  # 28 days
        
  strict:
    decisions:
      - type: ban
        duration: 8760h  # 1 year
```

## Security Considerations

### Authentication Security
- **Password Hashing**: Argon2id with minimum 19 iterations
- **Session Management**: Secure cookies with HttpOnly, Secure, SameSite
- **Rate Limiting**: Authelia built-in rate limiting (5 attempts per minute)
- **Password Policy**: Minimum 12 characters, complexity requirements

### Network Security
- **SSL/TLS**: TLS 1.2+ only, strong cipher suites
- **HSTS**: Enable HTTP Strict Transport Security
- **IP Filtering**: CrowdSec security engine + GeoBlock (US-only) + custom IP lists
- **Firewall**: UFW rules to restrict access to necessary ports only

### Container Security
- **Non-root**: All containers run as non-root users
- **Capabilities**: Drop all capabilities, add only NET_BIND_SERVICE
- **Read-only**: Read-only filesystems where possible
- **Resource Limits**: CPU and memory limits to prevent DoS

### Secrets Management
- **Ansible Vault**: All sensitive data in encrypted vault
- **Environment Variables**: Secrets injected via environment, not in config files
- **No Hardcoded Values**: All IPs, ports, passwords as variables
- **Rotation**: Document procedure for credential rotation

## Performance Requirements

### Response Time Targets
- **Traefik Proxy**: < 50ms for established connections
- **Authelia Auth**: < 500ms for local authentication
- **CrowdSec Check**: < 100ms for IP reputation lookup
- **SSL Handshake**: < 200ms for Let's Encrypt certificates

### Resource Limits
- **Traefik**: 512MB RAM, 0.5 CPU cores
- **Authelia**: 256MB RAM, 0.25 CPU cores
- **CrowdSec**: 256MB RAM, 0.25 CPU cores
- **Total Stack**: < 2GB RAM, 1 CPU core baseline

### Scalability
- **Concurrent Users**: Support 50+ concurrent authenticated sessions
- **Request Rate**: Handle 1000+ requests per minute
- **Services**: Support 20+ registered services without performance degradation

## Monitoring & Observability

### Health Checks
- **Traefik**: `/ping` endpoint on port 8882
- **Authelia**: `/api/health` endpoint
- **CrowdSec**: API health check
- **SearXNG**: HTTP 200 on `/` endpoint

### Logging
- **Access Logs**: Traefik access.log (JSON format)
- **Error Logs**: Container stderr (JSON format)
- **Security Logs**: CrowdSec decisions and alerts
- **Authentication Logs**: Authelia success/failure events

### Metrics (Optional)
- **Traefik Dashboard**: Built-in metrics endpoint
- **Prometheus**: Optional integration for metrics collection
- **Grafana**: Optional dashboards for visualization

## Deployment Strategy

### Environment Setup
1. **Prerequisites**
   - OCI cloud server with Docker installed
   - Cloudflare account with API token
   - Domain `levonk.com` configured in Cloudflare
   - Ansible vault password file at `~/.ansible/vault_password`

2. **Ansible Environment**
   - Ensure devbox environment is active
   - Verify Ansible and required collections installed
   - Test Ansible connectivity to OCI server

### Deployment Steps
1. **Configuration Phase**
   ```bash
   # Set up Ansible vault
   ansible-vault create group_vars/all/vault.yml
   
   # Add Cloudflare API token
   # Add Authelia admin password (hashed)
   # Add CrowdSec API key
   ```

2. **Deployment Phase**
   ```bash
   # Deploy proxy stack
   ansible-playbook -i inventories/oci.yml playbooks/deploy-proxy-stack.yml \
     --tags traefik,authelia,crowdsec \
     --vault-password-file ~/.ansible/vault_password
   ```

3. **Verification Phase**
   ```bash
   # Test Traefik dashboard
   curl -I https://traefik.levonk.com
   
   # Test SearXNG with authentication
   curl -I https://search.levonk.com
   
   # Check SSL certificate
   openssl s_client -connect search.levonk.com:443
   ```

### Rollback Procedure
1. **Ansible Rollback**
   ```bash
   # Stop proxy stack
   ansible-playbook -i inventories/oci.yml playbooks/rollback-proxy-stack.yml
   ```

2. **Manual Rollback**
   ```bash
   # SSH into server
   ssh opc@oci-server
   
   # Stop containers
   docker-compose -f /opt/traefik/docker-compose.yml down
   
   # Restore previous configuration
   git checkout HEAD~1
   ```

## Testing Strategy

### Unit Tests
- **Ansible Role Tests**: Molecule tests for each role
- **Configuration Validation**: YAML syntax and variable validation
- **Template Rendering**: Jinja2 template rendering tests

### Integration Tests
- **Authentication Flow**: Test login process end-to-end
- **SSL Certificate**: Verify Let's Encrypt provisioning and renewal
- **Service Routing**: Test routing to SearXNG with authentication
- **Security Rules**: Test CrowdSec blocking and Authelia access control

### Security Tests
- **SSL Labs Test**: A+ rating on SSL Labs test
- **Header Security**: Verify security headers (HSTS, CSP, etc.)
- **Authentication**: Test brute force protection
- **Injection**: Test for SQL injection, XSS, etc.

### Performance Tests
- **Load Testing**: 1000 requests per minute
- **Concurrent Users**: 50 simultaneous authenticated sessions
- **SSL Performance**: Measure handshake time
- **Memory Usage**: Monitor memory under load

## Documentation Requirements

### User Documentation
- **Service Registration Guide**: How to register new services
- **Authentication Guide**: How to use Authelia for login
- **Troubleshooting Guide**: Common issues and solutions
- **Security Best Practices**: Guidelines for secure usage

### Developer Documentation
- **Architecture Overview**: System architecture and data flow
- **API Documentation**: Traefik and Authelia API endpoints
- **Configuration Reference**: All configuration options explained
- **Development Workflow**: How to extend and modify the system

### Operations Documentation
- **Deployment Guide**: Step-by-step deployment instructions
- **Monitoring Guide**: How to monitor system health
- **Backup/Recovery**: Backup and recovery procedures
- **Incident Response**: How to respond to security incidents

## Risks and Mitigations

### Technical Risks
- **Risk**: Let's Encrypt rate limiting
  - **Mitigation**: Use staging environment for testing, implement DNS challenge as backup
  
- **Risk**: Cloudflare API downtime
  - **Mitigation**: Use local DNS as fallback, cache DNS records locally
  
- **Risk**: Container resource exhaustion
  - **Mitigation**: Implement resource limits, monitor usage, auto-scale if needed

### Security Risks
- **Risk**: Authelia database compromise
  - **Mitigation**: Regular backups, encrypt database at rest, use strong passwords
  
- **Risk**: CrowdSec false positives
  - **Mitigation**: Regular review of banned IPs, implement whitelist for trusted IPs
  
- **Risk**: SSL certificate expiration
  - **Mitigation**: Monitor certificate expiration, implement automated renewal alerts

### Operational Risks
- **Risk**: Configuration drift between environments
  - **Mitigation**: Use Git for configuration management, implement CI/CD
  
- **Risk**: Service downtime during deployment
  - **Mitigation**: Use rolling updates, implement health checks, have rollback ready

## Dependencies

### External Dependencies
- **Cloudflare API**: Cloudflare account with API token
- **Let's Encrypt**: Valid domain with DNS configured
- **Docker Hub**: Access to container images
- **Internet**: Required for Let's Encrypt ACME challenges

### Internal Dependencies
- **Docker Engine**: Must be installed and running on OCI server
- **Ansible**: Version 2.15+ with required collections
- **NordVPN**: Required for SearXNG privacy (already deployed)
- **Tailscale**: Required for internal network access (already deployed)

### Service Dependencies
- **Traefik**: Depends on Docker socket access
- **Authelia**: Depends on Redis (optional) or memory storage
- **CrowdSec**: Depends on Traefik access logs
- **SearXNG**: Depends on NordVPN for privacy

## Timeline

### Phase 1: Infrastructure (Week 1)
- Day 1-2: Create Ansible roles and configuration structure
- Day 3-4: Implement variable-driven configuration
- Day 5: Test Ansible deployment locally

### Phase 2: Service Deployment (Week 2)
- Day 1-2: Deploy Traefik with Let's Encrypt
- Day 3-4: Deploy Authelia and CrowdSec
- Day 5: Test integration between components

### Phase 3: Service Integration (Week 3)
- Day 1-2: Integrate SearXNG with authentication
- Day 3-4: Configure Cloudflare DNS
- Day 5: End-to-end testing and validation

### Phase 4: Service Registration (Week 4)
- Day 1-3: Implement hybrid registration system
- Day 4-5: Documentation and testing

### Phase 5: Monitoring & Validation (Week 5)
- Day 1-2: Implement logging and monitoring
- Day 3-4: Security validation and testing
- Day 5: Final validation and handoff

## Acceptance Testing

### Functional Testing
1. **Access Traefik Dashboard**
   - Navigate to `https://traefik.levonk.com`
   - Verify valid SSL certificate
   - Verify dashboard loads without authentication

2. **Access SearXNG with Authentication**
   - Navigate to `https://search.levonk.com`
   - Verify redirect to Authelia login
   - Login with admin credentials
   - Verify access to SearXNG interface

3. **Test Security Features**
   - Attempt 3 failed logins
   - Verify IP is temporarily blocked
   - Test from different IP (whitelisted)
   - Verify access is restored

### Security Testing
1. **SSL Certificate Validation**
   - Check certificate validity period
   - Verify certificate chain
   - Test SSL Labs rating (target: A+)

2. **Authentication Security**
   - Test password complexity requirements
   - Verify session timeout
   - Test concurrent session limits
   - Verify secure cookie attributes

3. **Network Security**
   - Test HTTP→HTTPS redirect
   - Verify HSTS header
   - Test CrowdSec IP blocking functionality
   - Test GeoBlock US-only access control (verify non-US IPs are blocked)
   - Verify firewall rules

### Performance Testing
1. **Load Testing**
   - Run 1000 requests per minute
   - Monitor response times
   - Check error rates
   - Verify resource usage

2. **Concurrent User Testing**
   - Simulate 50 concurrent users
   - Monitor authentication performance
   - Check session management
   - Verify no memory leaks

## Success Metrics

### Deployment Success
- Ansible playbook completes without errors
- All containers running and healthy
- SSL certificates provisioned successfully
- DNS records configured correctly

### Operational Success
- Authentication response time < 500ms
- Proxy response time < 50ms
- Zero container crashes in 24-hour period
- SSL certificates auto-renew before expiration

### Security Success
- Zero unauthorized access attempts succeed
- CrowdSec blocks 100% of known malicious IPs
- All security headers present and correct
- Security audit passes with no critical findings

### User Success
- Users can authenticate with single password
- Services accessible via HTTPS with valid certificates
- Tailscale access works without authentication
- Service registration takes < 10 minutes

## Future Enhancements

### Short-term (Next 3 months)
- Add TOTP two-factor authentication to Authelia
- Implement Redis for session storage
- Add Prometheus metrics and Grafana dashboards
- Create service registration web UI

### Long-term (6-12 months)
- Add SSO integration (Google, GitHub)
- Implement automated service discovery
- Add multi-region deployment support
- Create mobile app for authentication

### Nice-to-have
- Integration with SIEM systems
- Advanced threat intelligence feeds
- Machine learning for anomaly detection
- API rate limiting per user

## Appendix

### A. Configuration Files
- Traefik static configuration: `/etc/traefik/traefik.yml`
- Traefik dynamic configuration: `/etc/traefik/dynamic.yml`
- Authelia configuration: `/etc/authelia/configuration.yml`
- CrowdSec configuration: `/etc/crowdsec/config.yaml`

### A.1. Traefik Dynamic Configuration Example
```yaml
http:
  routers:
    searxng:
      rule: 'Host(`search.levonk.com`)'
      service: searxng
      entryPoints:
        - websecure
      middlewares:
        - security-chain  # Applies GeoBlock + CrowdSec + Authelia
  
  middlewares:
    security-chain:
      chain:
        middlewares:
          - geoblock          # US-only geographic filtering
          - crowdsec-bouncer  # IP-based security
          - authelia          # Authentication
```

### B. Ansible Variables
- Cloudflare API token: `vault_cloudflare_api_token`
- Authelia admin password: `vault_authelia_admin_password`
- CrowdSec API key: `vault_crowdsec_api_key`
- Domain configuration: `proxy_services`

### C. Service Registration Example
```yaml
# To register a new service, add to host_vars:
proxy_services:
  myservice:
    domain: "myservice.levonk.com"
    auth_enabled: true
    security_level: "protected"
    middleware:
      - geoblock          # US-only geographic filtering
      - crowdsec-bouncer  # IP-based security
      - authelia          # Authentication
```

### D. Troubleshooting Commands
```bash
# Check container logs
docker logs traefik --tail=50
docker logs authelia --tail=50
docker logs crowdsec --tail=50

# Test SSL certificate
openssl s_client -connect search.levonk.com:443

# Test authentication
curl -I https://search.levonk.com

# Check CrowdSec decisions
docker exec crowdsec cscli decisions list

# Verify DNS resolution
nslookup search.levonk.com
```

### E. References
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Authelia Documentation](https://www.authelia.com/docs/)
- [CrowdSec Documentation](https://docs.crowdsec.net/)
- [Cloudflare API Documentation](https://developers.cloudflare.com/api/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)

---

**Document Version**: 1.0  
**Last Updated**: 2026-06-20  
**Next Review**: 2026-07-20