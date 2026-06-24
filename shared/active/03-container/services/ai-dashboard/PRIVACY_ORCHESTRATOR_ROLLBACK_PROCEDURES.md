# Privacy Orchestrator Rollback Procedures

## Overview
This document outlines rollback procedures for Privacy Orchestrator deployment issues. These procedures should be followed when deployment fails or issues are detected post-deployment.

## Prerequisites

- Access to the deployment server (SSH or direct access)
- Docker and Docker Compose installed
- Ansible installed (for automated deployments)
- Database access for rollback operations
- Backup of previous working configuration

## Rollback Triggers

Rollback should be initiated when:
- Health checks fail after deployment
- Performance degradation is detected
- Error rates increase significantly
- PII detection/transformation stops working
- Security vulnerabilities are discovered
- Configuration errors are detected
- Database migration failures occur

## Rollback Procedures

### 1. Configuration Rollback

#### Scenario: Configuration Change Causes Issues

**Symptoms:**
- Service fails to start after configuration change
- Health checks fail
- Unexpected behavior in PII detection/transformation

**Rollback Steps:**

1. **Identify the problematic configuration change:**
   ```bash
   # Check configuration file modification time
   ls -la /path/to/privacy-orchestrator/config/config.toml
   
   # Review recent changes
   git diff config/config.toml
   ```

2. **Restore previous configuration:**
   ```bash
   # If using version control
   git checkout HEAD~1 config/config.toml
   
   # If using backup files
   cp config/config.toml.backup config/config.toml
   
   # If using Ansible, redeploy previous version
   ansible-playbook -i inventories/oci.yml \
     playbooks/deploy-privacy-orchestrator.yml \
     --extra-vars "config_version=previous" \
     --vault-password-file ~/.ansible/vault_password
   ```

3. **Restart service with restored configuration:**
   ```bash
   cd /path/to/privacy-orchestrator
   docker compose -f docker-compose.privacy-orchestrator.yml restart
   ```

4. **Verify service health:**
   ```bash
   # Check container status
   docker ps | grep privacy-orchestrator
   
   # Test health endpoint
   curl -f http://localhost:9090/health
   
   # Check logs for errors
   docker logs privacy-orchestrator --tail=50
   ```

5. **Validate functionality:**
   ```bash
   # Test PII detection
   curl -X POST http://localhost:9090/detect \
     -H "Content-Type: application/json" \
     -d '{"text": "My email is test@example.com"}'
   
   # Test transformation
   curl -X POST http://localhost:9090/transform \
     -H "Content-Type: application/json" \
     -d '{"text": "My email is test@example.com", "mode": "redaction"}'
   ```

**Verification:**
- Service starts successfully
- Health checks pass
- PII detection/transformation works correctly
- No errors in logs

### 2. Service Deployment Rollback

#### Scenario: New Service Version Causes Issues

**Symptoms:**
- New Docker image has bugs or performance issues
- Service crashes after deployment
- Feature regression detected

**Rollback Steps:**

1. **Identify current and previous versions:**
   ```bash
   # Check current image version
   docker images | grep privacy-orchestrator
   
   # Check running container image
   docker inspect privacy-orchestrator | grep Image
   
   # List available versions
   docker images localnet-privacy-orchestrator
   ```

2. **Tag previous version as latest:**
   ```bash
   # If previous version is available locally
   docker tag localnet-privacy-orchestrator:v1.0.0 localnet-privacy-orchestrator:latest
   
   # If previous version needs to be pulled
   docker pull localnet-privacy-orchestrator:v1.0.0
   docker tag localnet-privacy-orchestrator:v1.0.0 localnet-privacy-orchestrator:latest
   ```

3. **Redeploy with previous version:**
   ```bash
   cd /path/to/privacy-orchestrator
   docker compose -f docker-compose.privacy-orchestrator.yml up -d --force-recreate
   ```

4. **Verify deployment:**
   ```bash
   # Check container is running previous version
   docker inspect privacy-orchestrator | grep Image
   
   # Test health endpoint
   curl -f http://localhost:9090/health
   
   # Check logs
   docker logs privacy-orchestrator --tail=50
   ```

5. **If using Ansible for deployment:**
   ```bash
   # Redeploy with specific version
   ansible-playbook -i inventories/oci.yml \
     playbooks/deploy-privacy-orchestrator.yml \
     --extra-vars "privacy_orchestrator_version=v1.0.0" \
     --vault-password-file ~/.ansible/vault_password
   ```

**Verification:**
- Container running previous version
- Service health checks pass
- No performance degradation
- Feature regression resolved

### 3. Database Rollback

#### Scenario: Database Migration Fails or Causes Issues

**Symptoms:**
- Database migration fails during deployment
- Data corruption detected
- Performance issues after schema changes

**Rollback Steps:**

1. **Stop Privacy Orchestrator service:**
   ```bash
   cd /path/to/privacy-orchestrator
   docker compose -f docker-compose.privacy-orchestrator.yml stop
   ```

2. **Create emergency backup (if not already exists):**
   ```bash
   # Backup current database state
   docker exec ai-dashboard-db pg_dump -U postgres analytics > emergency-backup-$(date +%Y%m%d-%H%M%S).sql
   ```

3. **Restore from pre-deployment backup:**
   ```bash
   # Identify the backup to restore
   ls -la /path/to/backups/analytics/
   
   # Restore from backup
   docker exec -i ai-dashboard-db psql -U postgres analytics < /path/to/backups/analytics/pre-deployment-backup.sql
   ```

4. **If migration was applied and needs rollback:**
   ```bash
   # Check migration version
   docker exec ai-dashboard-db psql -U postgres analytics -c "SELECT version FROM schema_migrations ORDER BY version DESC LIMIT 1;"
   
   # Rollback to previous migration version
   docker exec ai-dashboard-db psql -U postgres analytics -c "DELETE FROM schema_migrations WHERE version = 'current_version';"
   
   # Or use migration tool rollback if available
   # privacy-orchestrator migrate down
   ```

5. **Restart Privacy Orchestrator service:**
   ```bash
   docker compose -f docker-compose.privacy-orchestrator.yml start
   ```

6. **Verify database connectivity:**
   ```bash
   # Test database connection
   docker exec privacy-orchestrator env | grep DATABASE_URL
   docker exec ai-dashboard-db pg_isready -U postgres
   
   # Test analytics collection
   curl -X POST http://localhost:9090/detect \
     -H "Content-Type: application/json" \
     -d '{"text": "Test text"}'
   
   # Check database for new records
   docker exec ai-dashboard-db psql -U postgres analytics \
     -c "SELECT COUNT(*) FROM analytics WHERE timestamp > NOW() - INTERVAL '1 minute';"
   ```

**Verification:**
- Database schema matches expected state
- Data integrity maintained
- Service can connect to database
- Analytics collection works correctly

### 4. Network Configuration Rollback

#### Scenario: Network Changes Cause Connectivity Issues

**Symptoms:**
- Services cannot communicate after network changes
- IP address conflicts
- Network subnet issues

**Rollback Steps:**

1. **Identify network configuration changes:**
   ```bash
   # Check current network configuration
   docker network inspect proxy-chain-network
   docker network inspect ai-dashboard-network
   
   # Compare with previous configuration
   git diff docker-compose.privacy-orchestrator.yml
   ```

2. **Restore previous network configuration:**
   ```bash
   # Revert docker-compose file
   git checkout HEAD~1 docker-compose.privacy-orchestrator.yml
   
   # Or manually restore IP addresses
   # Edit docker-compose.privacy-orchestrator.yml to use previous IPs
   ```

3. **Recreate network if needed:**
   ```bash
   # Remove and recreate network
   docker network rm proxy-chain-network
   docker network create proxy-chain-network --driver bridge --subnet 172.29.0.0/16 --gateway 172.29.0.1
   ```

4. **Restart services with restored configuration:**
   ```bash
   cd /path/to/privacy-orchestrator
   docker compose -f docker-compose.privacy-orchestrator.yml down
   docker compose -f docker-compose.privacy-orchestrator.yml up -d
   ```

5. **Verify network connectivity:**
   ```bash
   # Test container-to-container communication
   docker exec privacy-orchestrator ping -c 3 headroom
   docker exec ai-dashboard-proxy-1 ping -c 3 privacy-orchestrator
   
   # Test HTTP connectivity
   docker exec privacy-orchestrator curl -f http://headroom:8787/health
   docker exec ai-dashboard-proxy-1 curl -f http://privacy-orchestrator:9090/health
   ```

**Verification:**
- All services can communicate
- No IP address conflicts
- Health checks pass for all services
- Pipeline data flow works correctly

### 5. Environment Variables Rollback

#### Scenario: Environment Variable Changes Cause Issues

**Symptoms:**
- Service fails to start after environment variable changes
- Incorrect configuration applied
- Security issues with exposed credentials

**Rollback Steps:**

1. **Identify problematic environment variables:**
   ```bash
   # Check current environment variables
   docker exec privacy-orchestrator env | sort
   
   # Compare with .env file
   cat .env.pipeline | grep PRIVACY_ORCHESTRATOR
   ```

2. **Restore previous environment variables:**
   ```bash
   # If using version control
   git checkout HEAD~1 .env.pipeline
   
   # If using backup files
   cp .env.pipeline.backup .env.pipeline
   
   # If using Ansible, redeploy previous environment
   ansible-playbook -i inventories/oci.yml \
     playbooks/deploy-privacy-orchestrator.yml \
     --extra-vars "env_version=previous" \
     --vault-password-file ~/.ansible/vault_password
   ```

3. **Restart service with restored environment:**
   ```bash
   cd /path/to/privacy-orchestrator
   docker compose -f docker-compose.privacy-orchestrator.yml down
   docker compose -f docker-compose.privacy-orchestrator.yml up -d
   ```

4. **Verify environment variables:**
   ```bash
   # Check environment variables in container
   docker exec privacy-orchestrator env | grep PRIVACY_ORCHESTRATOR
   
   # Verify specific critical variables
   docker exec privacy-orchestrator env | grep DATABASE_URL
   docker exec privacy-orchestrator env | grep UPSTREAM_PROXY
   ```

5. **Test service functionality:**
   ```bash
   # Test health endpoint
   curl -f http://localhost:9090/health
   
   # Test PII detection
   curl -X POST http://localhost:9090/detect \
     -H "Content-Type: application/json" \
     -d '{"text": "Test text"}'
   ```

**Verification:**
- Service starts successfully
- Environment variables correct
- No sensitive data exposed
- Service functionality works

### 6. Full Pipeline Rollback

#### Scenario: Privacy Orchestrator Integration Breaks Pipeline

**Symptoms:**
- Entire pipeline fails after Privacy Orchestrator integration
- Data flow blocked
- Cascade failures across services

**Rollback Steps:**

1. **Remove Privacy Orchestrator from pipeline:**
   ```bash
   # Update AI Dashboard Proxy 1 to point directly to Headroom
   # Edit .env.pipeline
   sed -i 's/AI_ANALYTICS_UPSTREAM_URL=http:\/\/privacy-orchestrator:9090/AI_ANALYTICS_UPSTREAM_URL=http:\/\/headroom:8787/' .env.pipeline
   
   # Or restore previous .env.pipeline
   git checkout HEAD~1 .env.pipeline
   ```

2. **Stop Privacy Orchestrator:**
   ```bash
   cd /path/to/privacy-orchestrator
   docker compose -f docker-compose.privacy-orchestrator.yml down
   ```

3. **Restart AI Dashboard Proxy 1:**
   ```bash
   cd /path/to/ai-dashboard
   docker compose -f docker-compose.ai-dashboard-pipeline.yml restart ai-dashboard-proxy-1
   ```

4. **Verify pipeline without Privacy Orchestrator:**
   ```bash
   # Test AI Dashboard Proxy 1 to Headroom connection
   docker exec ai-dashboard-proxy-1 curl -f http://headroom:8787/health
   
   # Test full pipeline flow
   curl -X POST http://localhost:9081/test \
     -H "Content-Type: application/json" \
     -d '{"test": "data"}'
   ```

5. **Investigate Privacy Orchestrator issues separately:**
   ```bash
   # Start Privacy Orchestrator in isolation
   cd /path/to/privacy-orchestrator
   docker compose -f docker-compose.privacy-orchestrator.yml up -d
   
   # Test Privacy Orchestrator independently
   curl -X POST http://localhost:9090/detect \
     -H "Content-Type: application/json" \
     -d '{"text": "Test text"}'
   ```

**Verification:**
- Pipeline works without Privacy Orchestrator
- Privacy Orchestrator works in isolation
- Root cause identified
- Fix developed and tested

## Rollback Verification Checklist

After any rollback, verify:

- [ ] Service starts successfully
- [ ] Health checks pass
- [ ] No errors in logs
- [ ] Service functionality works correctly
- [ ] Performance is acceptable
- [ ] No security issues introduced
- [ ] Database connectivity works
- [ ] Network connectivity works
- [ ] Pipeline integration works (if applicable)
- [ ] Monitoring and analytics work correctly

## Post-Rollback Actions

1. **Document the rollback:**
   - Record what was rolled back
   - Document the reason for rollback
   - Note the time of rollback
   - Capture any error messages or logs

2. **Investigate the root cause:**
   - Analyze logs from failed deployment
   - Review configuration changes
   - Test in staging environment
   - Identify the specific issue

3. **Develop a fix:**
   - Create a fix for the identified issue
   - Test the fix thoroughly
   - Document the fix
   - Get approval for redeployment

4. **Redeploy with fix:**
   - Schedule a maintenance window if needed
   - Communicate with stakeholders
   - Deploy the fix
   - Monitor closely after deployment

5. **Update procedures:**
   - Update deployment procedures to prevent recurrence
   - Add additional validation steps
   - Improve rollback procedures based on lessons learned
   - Update documentation

## Emergency Contacts

In case of emergency rollback situations:

- **DevOps Lead**: [Contact information]
- **Database Administrator**: [Contact information]
- **Security Team**: [Contact information]
- **Service Owner**: [Contact information]

## Related Documentation

- [PIPELINE.md](PIPELINE.md) - Pipeline architecture and configuration
- [PIPELINE_INTEGRATION_TEST_PLAN.md](PIPELINE_INTEGRATION_TEST_PLAN.md) - Integration testing procedures
- [deploy-privacy-orchestrator.yml](../../ansible/playbooks/deploy-privacy-orchestrator.yml) - Ansible deployment playbook
- [privacy-orchestrator-config-example.toml](privacy-orchestrator-config-example.toml) - Configuration examples
