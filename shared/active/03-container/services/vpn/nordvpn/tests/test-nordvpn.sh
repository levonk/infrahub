#!/bin/bash
# Integration tests for NordVPN service

set -e

echo "=== NordVPN Service Tests ==="

# Test 1: Check if container is running (skip if not running)
echo "Test 1: Checking if container is running..."
if docker ps | grep -q nordvpn; then
  echo "✓ Container is running"
else
  echo "⚠ Container is not running (skipping runtime tests)"
fi

# Test 2: Check health check script exists and is executable
echo "Test 2: Checking health check script..."
if [ -x "assets/static/nordvpn/bin/healthcheck-nordvpn.sh" ]; then
  echo "✓ Health check script exists and is executable"
else
  echo "✗ Health check script missing or not executable"
  exit 1
fi

# Test 3: Check entrypoint script exists and is executable
echo "Test 3: Checking entrypoint script..."
if [ -x "assets/static/nordvpn/bin/entrypoint-nordvpn.sh" ]; then
  echo "✓ Entrypoint script exists and is executable"
else
  echo "✗ Entrypoint script missing or not executable"
  exit 1
fi

# Test 4: Check Dockerfile uses base image
echo "Test 4: Checking Dockerfile base image..."
if grep -q "FROM localnet-base-debian" Dockerfile; then
  echo "✓ Dockerfile uses localnet-base-debian"
else
  echo "✗ Dockerfile does not use localnet-base-debian"
  exit 1
fi

# Test 5: Check docker-compose.yml has required capabilities
echo "Test 5: Checking docker-compose.yml capabilities..."
if grep -q "NET_ADMIN" docker-compose.yml && grep -q "NET_RAW" docker-compose.yml; then
  echo "✓ Required capabilities present"
else
  echo "✗ Required capabilities missing"
  exit 1
fi

# Test 6: Check TUN device mapping
echo "Test 6: Checking TUN device mapping..."
if grep -q "/dev/net/tun" docker-compose.yml; then
  echo "✓ TUN device mapped"
else
  echo "✗ TUN device not mapped"
  exit 1
fi

# Test 7: Check security hardening (capability dropping)
echo "Test 7: Checking security hardening..."
if grep -q "cap_drop:" docker-compose.yml && grep -q "no-new-privileges" docker-compose.yml; then
  echo "✓ Security hardening present"
else
  echo "✗ Security hardening missing"
  exit 1
fi

# Test 8: Check environment variable naming convention
echo "Test 8: Checking environment variable naming..."
if grep -q "VPN_NORDVPN_TOKEN" docker-compose.yml && grep -q "VPN_NORDVPN_COUNTRY" docker-compose.yml; then
  echo "✓ Environment variables follow naming convention"
else
  echo "✗ Environment variables do not follow naming convention"
  exit 1
fi

# Test 9: Check justfile exists
echo "Test 9: Checking justfile..."
if [ -f "justfile" ]; then
  echo "✓ justfile exists"
else
  echo "✗ justfile missing"
  exit 1
fi

# Test 10: Check project.json exists
echo "Test 10: Checking project.json..."
if [ -f "project.json" ]; then
  echo "✓ project.json exists"
else
  echo "✗ project.json missing"
  exit 1
fi

echo "=== All tests passed ==="
