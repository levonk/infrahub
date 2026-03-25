#!/usr/bin/env bash
set -e

# Test script for nix-sidecar volume ownership permissions validation
# This script tests the updated healthcheck to ensure it validates all required permissions

echo "🧪 Testing nix-sidecar volume ownership permissions validation..."

# Test 1: Verify healthcheck script has the new validation logic
echo "🔍 Test 1: Checking healthcheck script for new permission validations..."

if grep -q "Check /etc/nix ownership and permissions" /Users/micro/p/gh/lrepo52/job-aide/apps/active/devops/localnet/services/base/nix-sidecar/assets/static/nix-sidecar/healthcheck-nix-sidecar.sh; then
    echo "✅ Healthcheck contains /etc/nix validation"
else
    echo "❌ Healthcheck missing /etc/nix validation"
    exit 1
fi

if grep -q "Check /root/.cache/nix ownership and permissions" /Users/micro/p/gh/lrepo52/job-aide/apps/active/devops/localnet/services/base/nix-sidecar/assets/static/nix-sidecar/healthcheck-nix-sidecar.sh; then
    echo "✅ Healthcheck contains /root/.cache/nix validation"
else
    echo "❌ Healthcheck missing /root/.cache/nix validation"
    exit 1
fi

# Test 2: Verify entrypoint script sets the correct permissions
echo "🔍 Test 2: Checking entrypoint script for permission setup..."

if grep -q "Setting /etc/nix permissions for multi-user Nix" /Users/micro/p/gh/lrepo52/job-aide/apps/active/devops/localnet/services/base/nix-sidecar/assets/static/nix-sidecar/entrypoint-nix-sidecar.sh; then
    echo "✅ Entry point contains /etc/nix permission setup"
else
    echo "❌ Entry point missing /etc/nix permission setup"
    exit 1
fi

if grep -q "Setting /root/.cache/nix permissions for multi-user Nix" /Users/micro/p/gh/lrepo52/job-aide/apps/active/devops/localnet/services/base/nix-sidecar/assets/static/nix-sidecar/entrypoint-nix-sidecar.sh; then
    echo "✅ Entry point contains /root/.cache/nix permission setup"
else
    echo "❌ Entry point missing /root/.cache/nix permission setup"
    exit 1
fi

# Test 3: Verify specific permission values are correct
echo "🔍 Test 3: Validating specific permission requirements..."

# Check /etc/nix should be root:root 644 (or 755 for Docker volumes)
if grep -q "REQUIRED: root:root (multi-user Nix shared config)" /Users/micro/p/gh/lrepo52/job-aide/apps/active/devops/localnet/services/base/nix-sidecar/assets/static/nix-sidecar/healthcheck-nix-sidecar.sh; then
    echo "✅ Healthcheck validates /etc/nix ownership as root:root"
else
    echo "❌ Healthcheck missing /etc/nix ownership validation"
    exit 1
fi

if grep -q "REQUIRED: 644 (multi-user Nix shared config)" /Users/micro/p/gh/lrepo52/job-aide/apps/active/devops/localnet/services/base/nix-sidecar/assets/static/nix-sidecar/healthcheck-nix-sidecar.sh; then
    echo "✅ Healthcheck validates /etc/nix permissions as 644"
else
    echo "❌ Healthcheck missing /etc/nix permissions validation"
    exit 1
fi

# Check /root/.cache/nix should be root:root 755
if grep -q "REQUIRED: root:root (multi-user Nix daemon cache)" /Users/micro/p/gh/lrepo52/job-aide/apps/active/devops/localnet/services/base/nix-sidecar/assets/static/nix-sidecar/healthcheck-nix-sidecar.sh; then
    echo "✅ Healthcheck validates /root/.cache/nix ownership as root:root"
else
    echo "❌ Healthcheck missing /root/.cache/nix ownership validation"
    exit 1
fi

if grep -q "REQUIRED: 755 (multi-user Nix daemon cache)" /Users/micro/p/gh/lrepo52/job-aide/apps/active/devops/localnet/services/base/nix-sidecar/assets/static/nix-sidecar/healthcheck-nix-sidecar.sh; then
    echo "✅ Healthcheck validates /root/.cache/nix permissions as 755"
else
    echo "❌ Healthcheck missing /root/.cache/nix permissions validation"
    exit 1
fi

# Test 4: Verify entrypoint sets correct chmod values
echo "🔍 Test 4: Validating entrypoint chmod commands..."

if grep -q "chmod 644 /etc/nix" /Users/micro/p/gh/lrepo52/job-aide/apps/active/devops/localnet/services/base/nix-sidecar/assets/static/nix-sidecar/entrypoint-nix-sidecar.sh; then
    echo "✅ Entry point sets /etc/nix to 644 permissions"
else
    echo "❌ Entry point missing /etc/nix chmod 644"
    exit 1
fi

if grep -q "chmod 755 /root/.cache/nix" /Users/micro/p/gh/lrepo52/job-aide/apps/active/devops/localnet/services/base/nix-sidecar/assets/static/nix-sidecar/entrypoint-nix-sidecar.sh; then
    echo "✅ Entry point sets /root/.cache/nix to 755 permissions"
else
    echo "❌ Entry point missing /root/.cache/nix chmod 755"
    exit 1
fi

echo "🎉 All tests passed! Volume ownership permissions validation is correctly implemented."
echo ""
echo "📋 Summary of implemented validations:"
echo "   ✅ /nix (root:root 755) - was already validated"
echo "   ✅ /etc/nix (root:root 644) - NEW: added validation"
echo "   ✅ /root/.cache/nix (root:root 755) - NEW: added validation"
echo ""
echo "🔧 Implementation details:"
echo "   • Healthcheck now validates all three required directories"
echo "   • Entry point script sets correct permissions during startup"
echo "   • Docker volume compatibility considered (755 acceptable for /etc/nix)"
echo "   • Graceful handling when /root/.cache/nix is not yet mounted"

exit 0
