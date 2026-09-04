# VPN Routing Test Plan

**Created**: 2026-06-20  
**Feature**: Isolation VM Network Routing Validation  
**Purpose**: Comprehensive test plan for VPN routing validation and network egress control

## Test Scope

This test plan validates network routing from agent containers through VPN and proxy services on the OCI Cloud Server Host, ensuring proper network isolation and egress control.

## Test Environment

### Network Configuration
- **Container Network**: isolation-vm-network (172.28.0.0/16)
- **Gateway**: 172.28.0.1
- **VPN Gateway**: 192.168.101.1 (routed bridge kvm-route-br0)
- **NAT Bridge**: kvm-nat-br0 (192.168.100.0/24)
- **Host Default Gateway**: System default route

### Test Containers
- **nix-sidecar**: 172.28.0.2
- **base-kalinix**: 172.28.0.3
- **hermes-agent**: 172.28.0.4

### Configuration States
1. **VPN Disabled** (`isolation_vm_enable_vpn_routing: false`) - Current state
2. **VPN Enabled** (`isolation_vm_enable_vpn_routing: true`) - Optional state

## Test Cases

### TC-001: Basic Connectivity Test (VPN Disabled)
**Purpose**: Verify containers can reach external networks with VPN routing disabled

**Preconditions**:
- VPN routing disabled (`isolation_vm_enable_vpn_routing: false`)
- All containers running and healthy
- Host has internet connectivity

**Test Steps**:
1. From nix-sidecar container: `curl -I https://www.google.com`
2. From base-kalinix container: `curl -I https://www.google.com`
3. From hermes-agent container: `curl -I https://www.google.com`
4. Check external IP: `curl ifconfig.me` from each container
5. Verify responses are successful (HTTP 200)

**Expected Results**:
- All containers can reach external networks
- External IP matches host's public IP (NAT masquerading)
- Response times are acceptable (<5 seconds)

**Test Data**:
- Target: https://www.google.com
- Expected IP: Host public IP
- Timeout: 10 seconds

### TC-002: Basic Connectivity Test (VPN Enabled)
**Purpose**: Verify containers can reach external networks through VPN when enabled

**Preconditions**:
- VPN routing enabled (`isolation_vm_enable_vpn_routing: true`)
- VPN gateway accessible (192.168.101.1)
- All containers running and healthy

**Test Steps**:
1. Enable VPN routing in configuration
2. Restart containers to apply routing changes
3. From nix-sidecar container: `curl -I https://www.google.com`
4. From base-kalinix container: `curl -I https://www.google.com`
5. From hermes-agent container: `curl -I https://www.google.com`
6. Check external IP: `curl ifconfig.me` from each container
7. Verify responses are successful (HTTP 200)

**Expected Results**:
- All containers can reach external networks
- External IP matches VPN gateway public IP (not host IP)
- Response times are acceptable (<10 seconds, accounting for VPN overhead)

**Test Data**:
- Target: https://www.google.com
- Expected IP: VPN gateway public IP
- Timeout: 15 seconds

### TC-003: Traffic Routing Verification with Packet Capture
**Purpose**: Verify traffic routing path using packet capture on host

**Preconditions**:
- tcpdump installed on host
- Root access on host
- Containers running

**Test Steps**:
1. Start packet capture on host bridge interface: `tcpdump -i isolation-vm-br0 -w capture.pcap`
2. From container: `curl https://www.google.com`
3. Stop packet capture after 10 seconds
4. Analyze capture: `tcpdump -r capture.pcap -nn`
5. Verify traffic flows through expected interface

**Expected Results**:
- **VPN Disabled**: Traffic flows through default route interface
- **VPN Enabled**: Traffic flows through VPN gateway interface (192.168.101.1)
- No traffic leaks to unexpected interfaces
- Packet headers show correct source/destination IPs

**Test Data**:
- Capture interface: isolation-vm-br0
- Capture duration: 10 seconds
- Filter: `tcp port 443`

### TC-004: DNS Resolution Test
**Purpose**: Verify DNS resolution works correctly through VPN/proxy

**Preconditions**:
- Containers running
- DNS configured (Docker embedded DNS: 127.0.0.11:53)

**Test Steps**:
1. From container: `nslookup google.com`
2. From container: `dig google.com +short`
3. From container: `getent hosts google.com`
4. Verify DNS responses are successful
5. Check response times

**Expected Results**:
- DNS queries resolve successfully
- Response times are acceptable (<2 seconds)
- DNS queries use correct DNS servers
- No DNS leaks to unexpected resolvers

**Test Data**:
- Test domains: google.com, github.com, example.com
- Expected: Successful resolution with valid IPs
- Timeout: 5 seconds

### TC-005: Split-Tunneling Configuration Test
**Purpose**: Verify split-tunneling configuration works as expected

**Preconditions**:
- VPN routing enabled
- Split-tunneling rules configured (if applicable)

**Test Steps**:
1. Test routing to VPN gateway network: `ping 192.168.101.1`
2. Test routing to local network: `ping 192.168.100.1`
3. Test routing to internet: `ping 8.8.8.8`
4. Check routing table: `ip route show`
5. Verify custom routing table: `ip route show table isolation-vm`

**Expected Results**:
- Local network traffic uses direct routing
- VPN network traffic uses VPN gateway
- Internet traffic uses VPN gateway (when enabled)
- Routing tables show correct routes
- No routing conflicts or ambiguities

**Test Data**:
- Local network: 192.168.100.0/24
- VPN network: 192.168.101.0/24
- Internet: 0.0.0.0/0

### TC-006: Firewall Rules Enforcement Test
**Purpose**: Verify firewall rules enforce VPN routing and prevent direct egress

**Preconditions**:
- Firewall configured (firewalld or iptables)
- VPN routing enabled

**Test Steps**:
1. Check firewall rules: `iptables -L -n -v`
2. Check firewalld zones: `firewall-cmd --list-all --zone=trusted`
3. Attempt direct egress bypass (if applicable)
4. Verify firewall blocks unexpected traffic patterns
5. Check NAT rules: `iptables -t nat -L -n -v`

**Expected Results**:
- Firewall rules allow expected traffic patterns
- Firewall blocks direct egress when VPN is enabled
- NAT rules correctly masquerade container traffic
- No unexpected allow rules for container network
- Firewall zone configuration matches documentation

**Test Data**:
- Container network: 172.28.0.0/16
- Expected behavior: Traffic enforcement per configuration
- Blocked patterns: Direct egress when VPN enabled

### TC-007: VPN Failure Fallback Test
**Purpose**: Verify fallback behavior when VPN is unavailable

**Preconditions**:
- VPN routing currently enabled
- VPN gateway accessible

**Test Steps**:
1. Note current external IP: `curl ifconfig.me`
2. Simulate VPN failure (block VPN gateway access)
3. Test connectivity: `curl -I https://www.google.com`
4. Check if fallback to direct routing occurs
5. Re-enable VPN gateway access
6. Verify routing returns to VPN path

**Expected Results**:
- System detects VPN failure
- Fallback behavior is documented and consistent
- Either traffic fails securely (no leak) or falls back to direct routing
- VPN restoration returns traffic to VPN path
- No silent routing failures

**Test Data**:
- VPN gateway: 192.168.101.1
- Failure simulation: Block ICMP/TCP to gateway
- Expected behavior: Documented fallback behavior

### TC-008: Inter-Container Communication Test
**Purpose**: Verify inter-container communication is not affected by VPN routing

**Preconditions**:
- All containers running
- VPN routing in either state

**Test Steps**:
1. From base-kalinix: `ping nix-sidecar`
2. From hermes-agent: `ping base-kalinix`
3. From hermes-agent: `ping nix-sidecar`
4. Test container name resolution: `getent hosts nix-sidecar`
5. Verify communication works in both VPN states

**Expected Results**:
- Inter-container communication works in both VPN states
- Container name resolution works via Docker DNS
- No latency impact on inter-container traffic
- Communication is not routed through VPN gateway

**Test Data**:
- Container names: nix-sidecar, base-kalinix, hermes-agent
- Expected: Successful communication via Docker bridge
- Latency: <1ms for local bridge traffic

## Test Automation

### Ansible Test Playbook Structure
```yaml
- name: Test VPN Routing
  hosts: isolation_vms
  become: true
  tasks:
    - name: Test basic connectivity
      ansible.builtin.command: docker exec {{ item }} curl -I https://www.google.com
      loop:
        - isolation-vm-nix-sidecar
        - isolation-vm-base-kalinix
        - isolation-vm-hermes-agent
      
    - name: Test DNS resolution
      ansible.builtin.command: docker exec {{ item }} nslookup google.com
      loop:
        - isolation-vm-nix-sidecar
        - isolation-vm-base-kalinix
        - isolation-vm-hermes-agent
      
    - name: Check routing tables
      ansible.builtin.command: ip route show
      
    - name: Capture packet traces
      ansible.builtin.shell: tcpdump -i isolation-vm-br0 -w /tmp/capture.pcap &
      async: 10
      poll: 0
```

## Test Execution

### Prerequisites
1. All Phase 03 containers deployed and running
2. Isolation VM accessible via SSH
3. Docker daemon operational inside VM
4. Network bridges configured (kvm-nat-br0, kvm-route-br0)
5. VPN services operational on OCI Cloud Server Host (if testing VPN routing)

### Execution Order
1. TC-001: Basic Connectivity (VPN Disabled) - Baseline
2. TC-004: DNS Resolution Test - Independent
3. TC-008: Inter-Container Communication - Independent
4. TC-003: Traffic Routing Verification - Requires tcpdump
5. TC-005: Split-Tunneling Configuration - VPN state dependent
6. TC-006: Firewall Rules Enforcement - Security validation
7. TC-002: Basic Connectivity (VPN Enabled) - Requires VPN enable
8. TC-007: VPN Failure Fallback - Advanced scenario

### Test Data Collection
- Capture packet traces for routing verification
- Log routing table states for each test
- Record external IPs for egress verification
- Document response times for performance analysis
- Save firewall rule sets for security audit

## Success Criteria

### Critical Success Criteria
- ✅ All containers can reach external networks in both VPN states
- ✅ Traffic routing matches expected path (verified with packet capture)
- ✅ DNS resolution works correctly
- ✅ Firewall rules enforce routing policies
- ✅ No traffic leaks to unexpected paths

### Non-Critical Success Criteria
- ✅ Split-tunneling configuration works as designed
- ✅ Fallback behavior is documented and tested
- ✅ Inter-container communication unaffected by VPN state
- ✅ Response times are acceptable for agent operations

## Risk Assessment

### High Risk
- **VPN routing misconfiguration**: Could cause complete network isolation
  - Mitigation: Test VPN disabled state first as baseline
  - Rollback: Disable VPN routing immediately if issues occur

### Medium Risk
- **Firewall rules too restrictive**: Could block legitimate traffic
  - Mitigation: Document current firewall state before changes
  - Rollback: Restore previous firewall rules

### Low Risk
- **DNS resolution issues**: Could affect agent operations
  - Mitigation: Test DNS independently before VPN routing
  - Rollback: Restore DNS configuration

## Troubleshooting

### Common Issues

**Containers cannot reach external networks**:
- Check host connectivity: `ping 8.8.8.8` from host
- Verify IP forwarding: `sysctl net.ipv4.ip_forward`
- Check Docker bridge: `docker network inspect isolation-vm-network`
- Verify NAT rules: `iptables -t nat -L -n -v`

**VPN routing not working**:
- Check VPN gateway connectivity: `ping 192.168.101.1`
- Verify routing table: `ip route show table isolation-vm`
- Check sysctl settings: `sysctl net.ipv4.ip_forward`
- Verify custom routing rules exist

**DNS resolution failing**:
- Check Docker DNS: `docker exec <container> cat /etc/resolv.conf`
- Test DNS directly: `nslookup google.com 8.8.8.8`
- Check firewall DNS rules: `iptables -L -n -v | grep 53`

**Packet capture shows unexpected routing**:
- Verify bridge interface: `ip link show isolation-vm-br0`
- Check routing tables: `ip route show`
- Verify firewall NAT rules: `iptables -t nat -L -n -v`
- Check VPN gateway status

## Documentation Requirements

### Test Results Documentation
- Test execution date and time
- Test environment configuration
- Test case results (pass/fail)
- Packet capture files (saved for audit)
- Routing table states (saved for comparison)
- Firewall rule sets (saved for security audit)
- External IP verification results
- Response time measurements
- Any deviations from expected results

### Routing Topology Documentation
- Current routing configuration
- VPN routing state (enabled/disabled)
- Custom routing tables (if configured)
- Firewall rule sets
- Network diagram with traffic paths
- Gateway configurations
- DNS resolver configuration

## Related Documentation

- **Network Topology**: `shared/active/08-docs/network/isolation-vm-network-topology.md`
- **PRD**: `shared/active/08-docs/reqs/2026/20260619-isolation-vm.md`
- **Container Configuration**: `shared/active/02-config/ansible/roles/isolation-vm-containers/`
- **Network Configuration**: `shared/active/02-config/ansible/roles/isolation-vm-containers/tasks/networking.yml`

## Sign-Off

**Test Execution**: ___________________  
**Date**: ___________________  
**Results**: ___________________  
**Notes**: ___________________
