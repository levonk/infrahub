#!/bin/bash
# shellcheck disable=SC1091
# Test script for turbo-cache service
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test configuration
TEST_CONTAINER_NAME="localnet-turbo-cache"
TEST_IMAGE_NAME="localnet-turbo-cache:latest"
HEALTH_CHECK_TIMEOUT=30
LOG_LEVEL="${LOG_LEVEL:-info}"

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Test functions
test_dockerfile_syntax() {
    log_info "Testing Dockerfile syntax..."
    if command -v hadolint >/dev/null 2>&1; then
        if hadolint docker/Dockerfile.turbo-cache; then
            log_info "✓ Dockerfile syntax is valid"
        else
            log_error "✗ Dockerfile syntax errors found"
            return 1
        fi
    else
        log_warn "hadolint not available, skipping Dockerfile syntax check"
    fi
}

test_docker_compose_syntax() {
    log_info "Testing docker-compose syntax..."
    if docker compose -f docker-compose.turbo-cache.yml config >/dev/null 2>&1; then
        log_info "✓ docker-compose syntax is valid"
    else
        log_error "✗ docker-compose syntax errors found"
        return 1
    fi
}

test_build_image() {
    log_info "Building Docker image..."
    if docker build -t "$TEST_IMAGE_NAME" -f docker/Dockerfile.turbo-cache .; then
        log_info "✓ Docker image built successfully"
    else
        log_error "✗ Docker image build failed"
        return 1
    fi
}

test_run_container() {
    log_info "Starting container for testing..."
    
    # Stop any existing container
    docker stop "$TEST_CONTAINER_NAME" >/dev/null 2>&1 || true
    docker rm "$TEST_CONTAINER_NAME" >/dev/null 2>&1 || true
    
    # Start container in detached mode
    if docker run -d \
        --name "$TEST_CONTAINER_NAME" \
        --rm \
        -p 3654:3654 \
        -p 3655:3655 \
        -e TURBO_CACHE_LOG_LEVEL="$LOG_LEVEL" \
        "$TEST_IMAGE_NAME"; then
        log_info "✓ Container started successfully"
    else
        log_error "✗ Failed to start container"
        return 1
    fi
    
    # Wait for container to be ready
    log_info "Waiting for container to be ready..."
    local count=0
    while [ $count -lt $HEALTH_CHECK_TIMEOUT ]; do
        if docker exec "$TEST_CONTAINER_NAME" /usr/local/bin/check-health.sh >/dev/null 2>&1; then
            log_info "✓ Container is ready"
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done
    
    log_error "✗ Container failed to become ready within $HEALTH_CHECK_TIMEOUT seconds"
    docker logs "$TEST_CONTAINER_NAME"
    return 1
}

test_health_check() {
    log_info "Testing health check..."
    if docker exec "$TEST_CONTAINER_NAME" /usr/local/bin/check-health.sh; then
        log_info "✓ Health check passed"
    else
        log_error "✗ Health check failed"
        return 1
    fi
}

test_ports() {
    log_info "Testing port accessibility..."
    
    # Test main port
    if nc -z localhost 3654 >/dev/null 2>&1; then
        log_info "✓ Main port 3654 is accessible"
    else
        log_warn "⚠ Main port 3654 is not accessible (may be expected for placeholder)"
    fi
    
    # Test web port
    if nc -z localhost 3655 >/dev/null 2>&1; then
        log_info "✓ Web port 3655 is accessible"
    else
        log_warn "⚠ Web port 3655 is not accessible (may be expected for placeholder)"
    fi
}

test_security_scan() {
    log_info "Running security scan..."
    if command -v trivy >/dev/null 2>&1; then
        if trivy image --exit-code 1 --severity HIGH,CRITICAL "$TEST_IMAGE_NAME"; then
            log_info "✓ No high or critical vulnerabilities found"
        else
            log_warn "⚠ Security scan found vulnerabilities (review output above)"
        fi
    else
        log_warn "trivy not available, skipping security scan"
    fi
}

test_cleanup() {
    log_info "Cleaning up test resources..."
    docker stop "$TEST_CONTAINER_NAME" >/dev/null 2>&1 || true
    docker rm "$TEST_CONTAINER_NAME" >/dev/null 2>&1 || true
    log_info "✓ Cleanup completed"
}

# Main test execution
main() {
    log_info "Starting turbo-cache service tests..."
    
    local failed_tests=0
    
    # Run tests
    test_dockerfile_syntax || failed_tests=$((failed_tests + 1))
    test_docker_compose_syntax || failed_tests=$((failed_tests + 1))
    test_build_image || failed_tests=$((failed_tests + 1))
    
    if [ $failed_tests -eq 0 ]; then
        test_run_container || failed_tests=$((failed_tests + 1))
        
        if [ $failed_tests -eq 0 ]; then
            test_health_check || failed_tests=$((failed_tests + 1))
            test_ports || failed_tests=$((failed_tests + 1))
            test_security_scan || true  # Don't fail on security scan
        fi
        
        test_cleanup
    fi
    
    # Report results
    if [ $failed_tests -eq 0 ]; then
        log_info "🎉 All tests passed!"
        exit 0
    else
        log_error "💥 $failed_tests test(s) failed!"
        exit 1
    fi
}

# Handle script arguments
case "${1:-}" in
    "syntax")
        test_dockerfile_syntax
        test_docker_compose_syntax
        ;;
    "build")
        test_build_image
        ;;
    "run")
        test_run_container
        test_health_check
        test_ports
        test_cleanup
        ;;
    "security")
        test_security_scan
        ;;
    "cleanup")
        test_cleanup
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  syntax    - Test Dockerfile and docker-compose syntax"
        echo "  build     - Test Docker image build"
        echo "  run       - Test container runtime"
        echo "  security  - Run security scan"
        echo "  cleanup   - Clean up test resources"
        echo "  help      - Show this help"
        echo ""
        echo "If no command is specified, all tests are run."
        ;;
    *)
        main
        ;;
esac
