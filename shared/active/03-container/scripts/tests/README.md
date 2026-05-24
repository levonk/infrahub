# Homelab E2E Tests

Comprehensive end-to-end tests for all homelab services.

## 📋 Test Suites

### DNS Services (`test-dns-services.sh`)
- ✅ CoreDNS health and metrics
- ✅ DNS query resolution (direct port)
- ✅ DNSCrypt-Proxy connectivity
- ✅ DNSDist metrics
- ✅ DNS cache performance
- ✅ DNSSEC validation

### Web Proxies (`test-web-proxies.sh`)
- ✅ Squid proxy health and caching
- ✅ Privoxy privacy proxy
- ✅ Envoy admin interface and proxy
- ✅ Tor SOCKS proxy and circuit
- ✅ Proxy chain (Privoxy → Squid)

### VPN Services (`test-vpn-services.sh`)
- ✅ WireGuard Direct interface and port
- ✅ WireGuard Transparent interface and port
- ✅ Transparent gateway
- ✅ Peer configuration and QR codes

### Artifact Repositories (`test-artifact-repos.sh`)
- ✅ Verdaccio NPM registry health and web UI
- ✅ Verdaccio package search and publish
- ✅ Nexus health and web UI
- ✅ Nexus Docker registry
- ✅ Repository configuration

### Monitoring (`test-monitoring.sh`)
- ✅ Prometheus health, targets, and query API
- ✅ Grafana health, web UI, and datasources
- ✅ Jaeger tracing UI
- ✅ Blackbox Exporter probes and modules

### Logging (`test-logging.sh`)
- ✅ Loki health and query API
- ✅ Elasticsearch health
- ✅ Promtail and Vector metrics

## 🚀 Running Tests

### Quick Tests (subset)
```bash
make test
```

Runs essential tests:
- DNS services
- Monitoring

### All Tests (comprehensive)
```bash
make test-all
```

Runs all test suites:
- DNS Services
- Web Proxies
- VPN Services
- Artifact Repositories
- Monitoring
- Logging

### Individual Test Suites
```bash
# DNS tests
./scripts/tests/test-dns-services.sh

# Web proxy tests
./scripts/tests/test-web-proxies.sh

# VPN tests
./scripts/tests/test-vpn-services.sh

# Artifact repository tests
./scripts/tests/test-artifact-repos.sh

# Monitoring tests
./scripts/tests/test-monitoring.sh

# Logging tests
./scripts/tests/test-logging.sh
```

## 📊 Test Output

Tests use color-coded output:
- 🟢 **PASS** - Test passed successfully
- 🔴 **FAIL** - Test failed (exit code 1)
- 🟡 **WARN** - Test passed with warnings
- ⚪ **SKIP** - Test skipped (missing dependencies)

### Example Output
```
========================================
Running: DNS Services E2E Tests
========================================

Testing: CoreDNS Health Check ... ✓ PASS - CoreDNS health endpoint responding
Testing: CoreDNS Metrics ... ✓ PASS - CoreDNS metrics available
Testing: DNS Query (Direct Port) ... ✓ PASS - DNS query successful: example.com -> 93.184.216.34
Testing: DNSCrypt-Proxy Query ... ✓ PASS - DNSCrypt-Proxy port 5300 listening
Testing: DNSDist Metrics ... ✓ PASS - DNSDist metrics available
Testing: DNS Cache Performance ... ✓ PASS - DNS cache working (1st: 45ms, 2nd: 2ms)
Testing: DNSSEC Validation ... ⚠ WARN - DNSSEC validation may not be enabled

========================================
Test Summary
========================================
Total:   7
Passed:  6
Failed:  0
Warned:  1
Skipped: 0
```

## 🔧 Prerequisites

Tests require the following tools:
- `curl` - HTTP requests
- `nc` (netcat) - Port connectivity checks
- `dig` - DNS queries (optional, will skip if not available)
- `docker` - Container inspection

Install on Ubuntu/Debian:
```bash
sudo apt-get install curl netcat-openbsd dnsutils
```

Install on macOS:
```bash
brew install curl netcat bind
```

## 🐛 Debugging Failed Tests

### Check Service Status
```bash
docker compose ps
```

### View Service Logs
```bash
# Specific service
docker compose logs <service-name>

# All services
docker compose logs
```

### Check Service Health
```bash
make health-check
```

### Restart Services
```bash
# Restart all
make restart

# Restart specific service
docker compose restart <service-name>
```

## 📝 Adding New Tests

1. Create a new test file in `scripts/tests/`:
   ```bash
   touch scripts/tests/test-new-service.sh
   chmod +x scripts/tests/test-new-service.sh
   ```

2. Use the test helper functions:
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   source "$SCRIPT_DIR/test-helpers.sh"
   
   test_my_service() {
       test_start "My Service Health"
       if curl -sf http://localhost:8080/health > /dev/null; then
           test_pass "Service is healthy"
       else
           test_fail "Service is not healthy"
       fi
   }
   
   main() {
       test_suite_start "My Service E2E Tests"
       test_my_service
       test_suite_end
   }
   
   main "$@"
   ```

3. Add to `run-all-tests.sh`:
   ```bash
   run_test_suite "$SCRIPT_DIR/test-new-service.sh"
   ```

## 🎯 CI/CD Integration

Add to your CI pipeline:

```yaml
# GitHub Actions example
- name: Run E2E Tests
  run: |
    cd apps/active/devops/localnet
    docker compose up -d
    sleep 30  # Wait for services to start
    make test-all
```

## 📚 Test Helper Functions

Available in `test-helpers.sh`:

- `test_suite_start "Suite Name"` - Start a test suite
- `test_suite_end` - End suite and show summary
- `test_start "Test Name"` - Start an individual test
- `test_pass "Message"` - Mark test as passed
- `test_fail "Message"` - Mark test as failed
- `test_warn "Message"` - Mark test with warning
- `test_skip "Message"` - Skip test

## 🔒 Security Notes

Tests make HTTP requests to localhost services. Ensure:
- Tests run in isolated environments
- No sensitive data in test outputs
- Services are not exposed to the internet during testing
