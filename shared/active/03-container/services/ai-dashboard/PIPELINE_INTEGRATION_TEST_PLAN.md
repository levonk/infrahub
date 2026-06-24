# Privacy Orchestrator Pipeline Integration Test Plan

## Overview
This document outlines the end-to-end testing strategy for integrating the Privacy Orchestrator into the AI Dashboard pipeline.

## Test Environment
- **Pipeline**: AI Dashboard Proxy 1 → Privacy Orchestrator → Headroom → OmniRoute → AI Dashboard Proxy 2 → Iron-Proxy → NordVPN → Internet
- **Test Scope**: Privacy Orchestrator integration points and data flow validation
- **Test Type**: Integration testing with mock services where full pipeline unavailable

## Test Categories

### 1. Configuration Validation Tests

#### Test 1.1: Docker Compose Configuration
**Objective**: Verify docker-compose files are syntactically correct
```bash
# Test main pipeline configuration
docker compose -f docker-compose.ai-dashboard-pipeline.yml config

# Test standalone Privacy Orchestrator configuration
docker compose -f docker-compose.privacy-orchestrator.yml config
```
**Expected**: No syntax errors, valid YAML structure

#### Test 1.2: Environment Variables
**Objective**: Verify all required environment variables are defined
```bash
# Check .env.pipeline file
cat .env.pipeline | grep PRIVACY_ORCHESTRATOR

# Verify required variables
env | grep PRIVACY_ORCHESTRATOR_CONTAINER_IP
env | grep PRIVACY_ORCHESTRATOR_CHAIN_IP
env | grep PRIVACY_ORCHESTRATOR_HOST_PORT
```
**Expected**: All Privacy Orchestrator variables defined with valid values

#### Test 1.3: Network Configuration
**Objective**: Verify network configuration for proxy-chain-network
```bash
# Check if network exists
docker network inspect proxy-chain-network

# Verify subnet configuration
docker network inspect proxy-chain-network | grep 172.29.0.0/16
```
**Expected**: Network exists with correct subnet (172.29.0.0/16)

### 2. Service Startup Tests

#### Test 2.1: Privacy Orchestrator Container Startup
**Objective**: Verify Privacy Orchestrator container starts successfully
```bash
# Start Privacy Orchestrator service
docker compose -f docker-compose.privacy-orchestrator.yml up -d

# Check container status
docker ps | grep privacy-orchestrator

# Verify container is running
docker inspect privacy-orchestrator --format '{{.State.Running}}'
```
**Expected**: Container starts and reaches running state

#### Test 2.2: Health Check Endpoint
**Objective**: Verify health check endpoint responds correctly
```bash
# Test health endpoint
curl -f http://localhost:9090/health

# Check health check status
docker inspect privacy-orchestrator --format '{{.State.Health.Status}}'
```
**Expected**: Health endpoint returns 200 OK, container health status is "healthy"

#### Test 2.3: Service Dependencies
**Objective**: Verify Privacy Orchestrator waits for database dependency
```bash
# Check startup order
docker logs privacy-orchestrator | grep "Waiting for database"

# Verify database connection
docker exec privacy-orchestrator env | grep DATABASE_URL
```
**Expected**: Service waits for database, connects successfully

### 3. Pipeline Integration Tests

#### Test 3.1: Upstream Connection (AI Dashboard Proxy 1)
**Objective**: Verify AI Dashboard Proxy 1 can connect to Privacy Orchestrator
```bash
# Test connection from Proxy 1 to Privacy Orchestrator
docker exec ai-dashboard-proxy-1 curl -f http://privacy-orchestrator:9090/health

# Verify upstream URL configuration
docker exec ai-dashboard-proxy-1 env | grep AI_ANALYTICS_UPSTREAM_URL
```
**Expected**: Connection successful, upstream URL points to Privacy Orchestrator

#### Test 3.2: Downstream Connection (Headroom)
**Objective**: Verify Privacy Orchestrator can connect to Headroom
```bash
# Test connection from Privacy Orchestrator to Headroom
docker exec privacy-orchestrator curl -f http://headroom:8787/health

# Verify downstream URL configuration
docker exec privacy-orchestrator env | grep UPSTREAM_PROXY
```
**Expected**: Connection successful, downstream URL points to Headroom

#### Test 3.3: Network Connectivity
**Objective**: Verify all services can communicate via proxy-chain-network
```bash
# Test network connectivity
docker network inspect proxy-chain-network

# Verify container IP addresses
docker inspect privacy-orchestrator | grep 172.29.0.15
docker inspect ai-dashboard-proxy-1 | grep 172.29.0.11
docker inspect headroom | grep 172.29.0.13
```
**Expected**: All containers on correct network with assigned IPs

### 4. Data Flow Tests

#### Test 4.1: Request Flow Through Pipeline
**Objective**: Verify requests flow correctly through Privacy Orchestrator
```bash
# Send test request through pipeline
curl -X POST http://localhost:9081/detect \
  -H "Content-Type: application/json" \
  -d '{"text": "My email is test@example.com"}'

# Verify PII detection
curl -X POST http://localhost:9090/detect \
  -H "Content-Type: application/json" \
  -d '{"text": "My email is test@example.com"}'
```
**Expected**: PII detected and transformed in response

#### Test 4.2: Analytics Collection
**Objective**: Verify analytics are collected at pipeline stages
```bash
# Check database for analytics records
docker exec ai-dashboard-db psql -U postgres -d analytics \
  -c "SELECT COUNT(*) FROM analytics WHERE pipeline_stage = 'privacy-orchestrator'"

# Verify analytics endpoint
curl http://localhost:9090/analytics
```
**Expected**: Analytics records present for Privacy Orchestrator stage

#### Test 4.3: Transformation Modes
**Objective**: Verify different transformation modes work correctly
```bash
# Test redaction mode
curl -X POST http://localhost:9090/transform \
  -H "Content-Type: application/json" \
  -d '{"text": "My email is test@example.com", "mode": "redaction"}'

# Test masking mode
curl -X POST http://localhost:9090/transform \
  -H "Content-Type: application/json" \
  -d '{"text": "My email is test@example.com", "mode": "masking"}'
```
**Expected**: Different transformation modes produce different outputs

### 5. Performance Tests

#### Test 5.1: Latency Measurement
**Objective**: Measure Privacy Orchestrator processing latency
```bash
# Measure detection latency
time curl -X POST http://localhost:9090/detect \
  -H "Content-Type: application/json" \
  -d '{"text": "Test text with no PII"}'

# Measure transformation latency
time curl -X POST http://localhost:9090/transform \
  -H "Content-Type: application/json" \
  -d '{"text": "Test text", "mode": "redaction"}'
```
**Expected**: Latency < 100ms for simple requests

#### Test 5.2: Throughput Test
**Objective**: Measure Privacy Orchestrator throughput
```bash
# Run concurrent requests
for i in {1..100}; do
  curl -X POST http://localhost:9090/detect \
    -H "Content-Type: application/json" \
    -d '{"text": "Test text"}' &
done
wait
```
**Expected**: All requests complete successfully, no errors

#### Test 5.3: Resource Usage
**Objective**: Monitor resource usage under load
```bash
# Check memory usage
docker stats privacy-orchestrator --no-stream

# Check CPU usage
docker top privacy-orchestrator
```
**Expected**: Memory usage < 2GB, CPU usage reasonable

### 6. Error Handling Tests

#### Test 6.1: Invalid Input Handling
**Objective**: Verify graceful handling of invalid input
```bash
# Test malformed JSON
curl -X POST http://localhost:9090/detect \
  -H "Content-Type: application/json" \
  -d '{"invalid": "data"'

# Test missing required fields
curl -X POST http://localhost:9090/detect \
  -H "Content-Type: application/json" \
  -d '{}'
```
**Expected**: Appropriate error responses (400 Bad Request)

#### Test 6.2: Service Unavailability
**Objective**: Verify behavior when downstream services are unavailable
```bash
# Stop Headroom service
docker stop headroom

# Test Privacy Orchestrator with Headroom down
curl -X POST http://localhost:9090/transform \
  -H "Content-Type: application/json" \
  -d '{"text": "Test text"}'

# Restart Headroom
docker start headroom
```
**Expected**: Graceful error handling, circuit breaker activation

#### Test 6.3: Network Partition
**Objective**: Verify behavior during network issues
```bash
# Simulate network partition
docker network disconnect proxy-chain-network privacy-orchestrator

# Test service behavior
curl http://localhost:9090/health

# Reconnect network
docker network connect proxy-chain-network privacy-orchestrator
```
**Expected**: Service detects network issues, recovers on reconnection

### 7. Security Tests

#### Test 7.1: TLS Configuration (if enabled)
**Objective**: Verify TLS configuration
```bash
# Test HTTPS endpoint (if TLS enabled)
curl -k https://localhost:9090/health

# Verify certificate
openssl s_client -connect localhost:9090 -showcerts
```
**Expected**: TLS handshake successful, valid certificate

#### Test 7.2: Rate Limiting
**Objective**: Verify rate limiting works correctly
```bash
# Send rapid requests
for i in {1..1500}; do
  curl http://localhost:9090/health &
done
wait

# Check for rate limit errors
docker logs privacy-orchestrator | grep "rate limit"
```
**Expected**: Requests beyond limit are rate-limited

#### Test 7.3: Input Validation
**Objective**: Verify input validation prevents injection attacks
```bash
# Test SQL injection attempt
curl -X POST http://localhost:9090/detect \
  -H "Content-Type: application/json" \
  -d '{"text": "'; DROP TABLE users; --"}'

# Test XSS attempt
curl -X POST http://localhost:9090/detect \
  -H "Content-Type: application/json" \
  -d '{"text": "<script>alert(1)</script>"}'
```
**Expected**: Input sanitized, no injection vulnerabilities

### 8. Deployment Tests

#### Test 8.1: Ansible Deployment
**Objective**: Verify Ansible playbook deploys correctly
```bash
# Run Ansible playbook in check mode
ansible-playbook -i inventories/oci.yml \
  playbooks/deploy-privacy-orchestrator.yml \
  --check --diff --vault-password-file ~/.ansible/vault_password

# Run actual deployment
ansible-playbook -i inventories/oci.yml \
  playbooks/deploy-privacy-orchestrator.yml \
  --vault-password-file ~/.ansible/vault_password
```
**Expected**: Playbook completes without errors, service deployed

#### Test 8.2: Configuration File Deployment
**Objective**: Verify configuration files are deployed correctly
```bash
# Check config file exists
ssh user@server "cat /path/to/privacy-orchestrator/config/config.toml"

# Verify configuration syntax
ssh user@server "privacy-orchestrator --config /path/to/config.toml validate"
```
**Expected**: Configuration file deployed with correct content

#### Test 8.3: Service Restart
**Objective**: Verify service can be restarted without issues
```bash
# Restart service
docker compose -f docker-compose.privacy-orchestrator.yml restart

# Verify service comes back healthy
docker ps | grep privacy-orchestrator
curl http://localhost:9090/health
```
**Expected**: Service restarts successfully, health checks pass

### 9. Rollback Tests

#### Test 9.1: Configuration Rollback
**Objective**: Verify configuration can be rolled back
```bash
# Backup current configuration
cp config/config.toml config/config.toml.backup

# Apply new configuration
cp new-config.toml config/config.toml
docker compose -f docker-compose.privacy-orchestrator.yml restart

# If issues, rollback
cp config/config.toml.backup config/config.toml
docker compose -f docker-compose.privacy-orchestrator.yml restart
```
**Expected**: Rollback restores previous working configuration

#### Test 9.2: Service Rollback
**Objective**: Verify service can be rolled back to previous version
```bash
# Tag current version
docker tag localnet-privacy-orchestrator:latest localnet-privacy-orchestrator:v1

# Deploy new version
docker pull localnet-privacy-orchestrator:v2
docker compose -f docker-compose.privacy-orchestrator.yml up -d

# If issues, rollback
docker tag localnet-privacy-orchestrator:v1 localnet-privacy-orchestrator:latest
docker compose -f docker-compose.privacy-orchestrator.yml up -d
```
**Expected**: Rollback restores previous service version

#### Test 9.3: Database Rollback
**Objective**: Verify database changes can be rolled back
```bash
# Create database backup
docker exec ai-dashboard-db pg_dump -U postgres analytics > backup.sql

# Apply schema changes
# (run migration scripts)

# If issues, restore backup
docker exec -i ai-dashboard-db psql -U postgres analytics < backup.sql
```
**Expected**: Database restore successful, data integrity maintained

## Test Execution Checklist

- [ ] Configuration validation tests pass
- [ ] Service startup tests pass
- [ ] Pipeline integration tests pass
- [ ] Data flow tests pass
- [ ] Performance tests meet requirements
- [ ] Error handling tests pass
- [ ] Security tests pass
- [ ] Deployment tests pass
- [ ] Rollback procedures tested and documented

## Success Criteria

1. All configuration files are valid and properly structured
2. Privacy Orchestrator starts successfully and passes health checks
3. All pipeline services can communicate via proxy-chain-network
4. Data flows correctly through the pipeline with PII transformation
5. Analytics are collected at all pipeline stages
6. Performance meets requirements (latency < 100ms, reasonable throughput)
7. Error handling is graceful and well-documented
8. Security measures are effective (rate limiting, input validation)
9. Deployment automation works correctly
10. Rollback procedures are tested and reliable

## Notes

- Some tests require full pipeline to be running (Headroom, OmniRoute, etc.)
- Mock services may be used for isolated testing
- Performance tests should be run in a controlled environment
- Security tests should be reviewed by security team
- All test results should be documented and archived
