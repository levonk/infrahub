#!/bin/bash
# Audit container security for curl/wget usage
# This script audits all Dockerfiles for unsafe curl/wget usage

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Find all Dockerfiles (excluding boilerplates and node_modules)
find_dockerfiles() {
    find . -path "./boilerplate" -prune \
         -o -path "./node_modules" -prune \
         -o -name "Dockerfile*" -type f -print \
         2>/dev/null | sort
}

# Check if a Dockerfile uses curl or wget
check_curl_wget_usage() {
    local dockerfile="$1"
    local usage_type=""
    
    if grep -q "curl" "$dockerfile" 2>/dev/null; then
        usage_type="curl"
    elif grep -q "wget" "$dockerfile" 2>/dev/null; then
        usage_type="wget"
    else
        return 1
    fi
    
    echo "$usage_type"
    return 0
}

# Analyze curl/wget usage for security issues
analyze_usage() {
    local dockerfile="$1"
    local usage_type="$2"
    local issues=()
    
    # Check for unsafe patterns
    if grep -q "curl.*|" "$dockerfile" 2>/dev/null; then
        issues+=("curl pipe to shell - potential command injection")
    fi
    
    if grep -q "wget.*|" "$dockerfile" 2>/dev/null; then
        issues+=("wget pipe to shell - potential command injection")
    fi
    
    if grep -q "curl.*sh.*http" "$dockerfile" 2>/dev/null; then
        issues+=("curl executing remote shell scripts")
    fi
    
    if grep -q "wget.*sh.*http" "$dockerfile" 2>/dev/null; then
        issues+=("wget executing remote shell scripts")
    fi
    
    # Check for HTTP usage
    if grep -q "http://" "$dockerfile" 2>/dev/null; then
        issues+=("insecure HTTP URLs detected")
    fi
    
    # Check for missing verification
    if grep -q "$usage_type.*http" "$dockerfile" 2>/dev/null; then
        if ! grep -q "vet-run\|vet\|--verify\|--checksum" "$dockerfile" 2>/dev/null; then
            issues+=("missing verification for remote downloads")
        fi
    fi
    
    # Check for SSL verification disabled
    if grep -q "--insecure\|-k\|--no-check-certificate" "$dockerfile" 2>/dev/null; then
        issues+=("SSL verification disabled")
    fi
    
    # Output issues
    if [ ${#issues[@]} -gt 0 ]; then
        for issue in "${issues[@]}"; do
            print_error "  $issue"
        done
        return 1
    else
        return 0
    fi
}

# Check if vet-run/vet is available in the image
check_vet_available() {
    local dockerfile="$1"
    local base_image=""
    
    # Extract base image
    base_image=$(grep "^FROM" "$dockerfile" | head -1 | awk '{print $2}')
    
    if [ -z "$base_image" ]; then
        return 1
    fi
    
    # Check if it's a local image
    if [[ "$base_image" == localnet-* ]]; then
        # Check if vet is installed in the base image
        if docker run --rm "$base_image" which vet >/dev/null 2>&1; then
            return 0
        fi
    fi
    
    return 1
}

# Main audit function
audit_dockerfiles() {
    local dockerfiles=()
    local total=0
    local with_curl_wget=0
    local unsafe=0
    local need_vet=0
    
    print_header "Starting curl/wget security audit"
    
    # Find all Dockerfiles
    mapfile -t dockerfiles < <(find_dockerfiles)
    total=${#dockerfiles[@]}
    
    print_info "Found $total Dockerfiles to audit"
    echo
    
    # Audit each Dockerfile
    for dockerfile in "${dockerfiles[@]}"; do
        echo -n "Auditing: $dockerfile ... "
        
        if usage_type=$(check_curl_wget_usage "$dockerfile"); then
            with_curl_wget=$((with_curl_wget + 1))
            echo "uses $usage_type"
            
            # Analyze usage
            if ! analyze_usage "$dockerfile" "$usage_type"; then
                unsafe=$((unsafe + 1))
                
                # Check if vet is available
                if check_vet_available "$dockerfile"; then
                    print_warning "  vet is available in base image"
                else
                    need_vet=$((need_vet + 1))
                    print_error "  vet NOT available - consider installing levonk.common.vet_script_installer"
                fi
            else
                print_success "usage appears safe"
            fi
        else
            echo "no curl/wget"
        fi
    done
    
    echo
    print_header "Audit Summary"
    echo "Total Dockerfiles audited: $total"
    echo "Using curl/wget: $with_curl_wget"
    echo "Unsafe usage detected: $unsafe"
    echo "Need vet installed: $need_vet"
    echo
    
    if [ $unsafe -gt 0 ] || [ $need_vet -gt 0 ]; then
        print_error "Security issues found! Review the Dockerfiles above."
        return 1
    else
        print_success "All curl/wget usage appears safe!"
        return 0
    fi
}

# Generate report
generate_report() {
    local report_file="curl-wget-audit-report.md"
    
    cat > "$report_file" << EOF
# curl/wget Security Audit Report

Generated on: $(date)

## Summary

This report audits all Dockerfiles in the project for unsafe curl/wget usage and identifies containers that need the levonk.common.vet_script_installer package for safe remote script execution.

## Findings

$(audit_dockerfiles)

## Recommendations

1. **Install levonk.common.vet_script_installer**: Add this package to any base image that downloads files via curl/wget
2. **Use HTTPS**: Ensure all downloads use HTTPS URLs
3. **Verify downloads**: Use vet-run or vet to verify script integrity before execution
4. **Avoid pipes**: Never pipe curl/wget output directly to shell
5. **Enable SSL verification**: Never disable SSL certificate checks

## Actions Required

- [ ] Add levonk.common.vet_script_installer to base images that need it
- [ ] Update Dockerfiles to use HTTPS URLs
- [ ] Replace unsafe curl/wget usage with vet-verified alternatives
EOF
    
    print_success "Report generated: $report_file"
}

# Main execution
main() {
    cd "$(dirname "$0")/.."
    
    if [ "${1:-}" = "--report" ]; then
        generate_report
    else
        audit_dockerfiles
    fi
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
