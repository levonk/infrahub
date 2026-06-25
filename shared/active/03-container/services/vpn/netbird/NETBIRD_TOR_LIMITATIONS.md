# Netbird and Tor Integration Limitations

## Current Status: NOT SUPPORTED

Based on research and Netbird community discussions, **Netbird does not currently support integration with Tor** due to fundamental architectural incompatibilities.

## Technical Limitations

### 1. VPN Compatibility Issues
Netbird has known compatibility issues when running alongside other VPN solutions, including:
- Tor Network
- Mullvad VPN
- Proton VPN
- Nord VPN
- Other "real VPN" solutions

### 2. Root Cause Analysis
From Netbird issue #2522:
> "They are very often purpose-built for hijacking all of the traffic and not allowing anything around them (prevents working together with other solutions) to deliver on their primary purpose of making average internet user more secure on public hotspots."

### 3. Network Interface Conflicts
- Both Netbird and Tor attempt to control network routing
- Conflicting iptables rules and routing tables
- Interface ownership conflicts (both use tun/tap devices)
- DNS resolution conflicts

## Alternative Solutions

### Option 1: Tailscale over Tor (RECOMMENDED)
Tailscale has demonstrated working configurations for routing through Tor:
- Use the Tailscale-over-Tor configuration provided in this project
- Proven community solutions exist
- Better VPN coexistence support

### Option 2: Containerized Isolation
Run Netbird and Tor in separate containers with careful network isolation:
- Requires advanced Docker networking configuration
- Complex routing setup
- Not officially supported by Netbird

### Option 3: Sequential VPN Chaining
Use Netbird without Tor, or use Tor without Netbird:
- Choose one based on use case
- Avoid running both simultaneously
- Manual switching between configurations

## Future Possibilities

### Netbird Roadmap Considerations
From Netbird issue #1138:
> "we are planning our Q4 roadmap and will include routing all traffic through a NetBird peer development. We will consider a similar integration as well as part of the feature."

### Potential Workarounds
- Netbird team may add explicit Tor support in future
- WireGuard protocol improvements may help
- Better VPN coexistence standards

## Current Recommendation

**DO NOT attempt to run Netbird and Tor simultaneously.** Use Tailscale-over-Tor for anonymized VPN access, or run Netbird and Tor as separate, mutually exclusive configurations.

## References

- Netbird Issue #2522: Netbird will not work when any VPN is active
- Netbird Issue #1138: Mullvad VPN support discussion
- Netbird Issue #1096: Support obfuscation to work-around ISP blocking
- Netbird Documentation: Configuring Exit Nodes for Internet Traffic
