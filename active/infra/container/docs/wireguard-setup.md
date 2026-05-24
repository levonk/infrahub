# WireGuard VPN Setup Guide

## Overview

The homelab provides **two WireGuard VPN modes** for different use cases:

### 🔓 **Direct Mode (wg0 - Port 51820)**
- **Use Case**: Personal devices, trusted users
- **Internet Access**: ✅ Direct (like being on your home network)
- **Homelab Services**: ✅ Optional (can choose to use DNS, proxy, etc.)
- **Observation**: ❌ Not under transparent monitoring
- **Best For**: Your laptop, phone, tablet

### 🔒 **Transparent Mode (wg1 - Port 51821)**
- **Use Case**: Managed devices, kids' devices, guest access
- **Internet Access**: ❌ Blocked (must go through homelab services)
- **Homelab Services**: ✅ Enforced (DNS, proxy, filtering mandatory)
- **Observation**: ✅ All traffic logged and filtered
- **Best For**: Devices you want to monitor and protect

## Architecture

### Direct Mode (wg0)

```
Internet → WireGuard Direct (51820/udp)
              ↓
        VPN Tunnel (10.13.13.0/24)
              ↓ (split-tunnel)
        ├─→ Internet (direct access)
        └─→ Homelab Network (172.20.0.0/16) - optional
                ↓
            Services:
            ├─→ DNS (dnsdist:5353)
            ├─→ Web Proxy (Squid:3128)
            ├─→ Tor (SOCKS5:9050)
            ├─→ Monitoring (Grafana, Prometheus)
            └─→ Artifacts (Nexus, Verdaccio)
```

### Transparent Mode (wg1)

```
Internet → WireGuard Transparent (51821/udp)
              ↓
        VPN Tunnel (10.13.14.0/24)
              ↓ (enforced routing)
        Transparent Gateway (172.20.0.254)
              ↓ (mandatory interception)
        Homelab Services (DNS, Proxy, Filtering)
              ↓
        Internet (through homelab only)
```

## Security Features

### 1. **Network Isolation**
- WireGuard runs on separate Docker network (172.21.0.0/16)
- Cannot directly access Docker daemon or host services
- Explicit routing rules control access to homelab network

### 2. **Service Access Control**
- Only specific services are accessible through VPN
- Transparent proxy (nftables) does NOT intercept VPN traffic
- All VPN connections logged separately

### 3. **DNS Integration**
- VPN clients use homelab DNS (dnsdist) automatically
- Benefits from ad/malware blocking
- ODoH privacy protection for DNS queries

## Initial Setup

### 1. Configure Environment Variables

Edit `.env` and set:

```bash
# Your public IP or domain (for client configs)
WIREGUARD_SERVERURL=vpn.yourdomain.com  # or use 'auto' for auto-detection

# WireGuard port (default: 51820)
WIREGUARD_PORT=51820

# Number of client configurations to generate
WIREGUARD_PEERS=5

# Networks accessible through VPN
WIREGUARD_ALLOWEDIPS=172.20.0.0/16,192.168.2.214/32
```

### 2. Start WireGuard Service

```bash
# Start all services including WireGuard
make up

# Or start only WireGuard
docker compose up -d wireguard
```

### 3. Retrieve Client Configurations

WireGuard automatically generates QR codes and config files for each peer:

```bash
# View QR code for peer 1 (scan with WireGuard mobile app)
docker compose logs wireguard | grep -A 50 "PEER 1 QR code"

# Get config file for peer 1 (for desktop clients)
docker compose exec wireguard cat /config/peer1/peer1.conf
```

**Client config locations inside container:**
- `/config/peer1/peer1.conf`
- `/config/peer2/peer2.conf`
- `/config/peer3/peer3.conf`
- etc.

### 4. Copy Config to Your Device

**For Desktop (Linux/macOS/Windows):**

```bash
# Copy config file from container
docker compose cp wireguard:/config/peer1/peer1.conf ./peer1.conf

# Import into WireGuard client
# Linux: sudo wg-quick up ./peer1.conf
# macOS/Windows: Import via WireGuard GUI
```

**For Mobile (iOS/Android):**

1. View QR code: `docker compose logs wireguard`
2. Open WireGuard app
3. Tap "Add Tunnel" → "Create from QR code"
4. Scan the QR code

## Client Configuration Example

A generated client config looks like this:

```ini
[Interface]
PrivateKey = <client-private-key>
Address = 10.13.13.2/32
DNS = 192.168.2.214

[Peer]
PublicKey = <server-public-key>
PresharedKey = <preshared-key>
Endpoint = vpn.yourdomain.com:51820
AllowedIPs = 172.20.0.0/16, 192.168.2.214/32
PersistentKeepalive = 25
```

**What this means:**
- **Address**: Your VPN tunnel IP (10.13.13.x)
- **DNS**: Uses homelab DNS for queries
- **AllowedIPs**: Only routes homelab traffic through VPN (split-tunnel)
- **PersistentKeepalive**: Keeps connection alive through NAT

## Accessing Services Through VPN

Once connected, access services using homelab network IPs:

### Direct Service Access (Direct Mode - wg0)

```bash
# DNS (optional)
dig example.com @172.20.0.2 -p 5353

# Web Proxy (optional)
curl -x http://172.20.0.3:3128 http://example.com

# Tor for Anonymization (optional)
curl -x socks5://172.20.0.5:9050 http://example.com

# Configure browser to use Tor
# SOCKS5 Proxy: 172.20.0.5:9050
# No authentication required

# Monitoring
http://172.20.0.15:3000  # Grafana
http://172.20.0.14:9090  # Prometheus

# Artifacts
http://172.20.0.11:8081  # Nexus
http://172.20.0.12:4873  # Verdaccio
```

### Transparent Service Access (Transparent Mode - wg1)

```bash
# All traffic automatically goes through homelab services
# DNS, Web Proxy, and Filtering are ENFORCED
# Tor is used automatically by the transparent proxy chain

curl http://example.com  # Automatically filtered and logged
```

### Using Host IP

You can also access services via the host IP (192.168.2.214):

```bash
# Grafana
http://192.168.2.214:3000

# Prometheus
http://192.168.2.214:9090
```

## Firewall Configuration

### Host Firewall (UFW/iptables)

Allow WireGuard port:

```bash
# UFW
sudo ufw allow 51820/udp

# iptables
sudo iptables -A INPUT -p udp --dport 51820 -j ACCEPT
```

### Router Port Forwarding

Forward UDP port 51820 to your homelab server:

```
External Port: 51820/udp → Internal IP: 192.168.2.214:51820/udp
```

## Monitoring

### Check WireGuard Status

```bash
# View active connections
docker compose exec wireguard wg show

# View logs
docker compose logs -f wireguard

# Check peer handshakes
docker compose exec wireguard wg show all latest-handshakes
```

### Prometheus Metrics

WireGuard metrics are available in Prometheus (if exporter enabled):

- Connection status per peer
- Data transfer (bytes sent/received)
- Last handshake time

## Troubleshooting

### Client Can't Connect

1. **Check server is running:**
   ```bash
   docker compose ps wireguard
   ```

2. **Verify port is open:**
   ```bash
   sudo netstat -tulpn | grep 51820
   ```

3. **Check firewall rules:**
   ```bash
   sudo ufw status
   ```

4. **View WireGuard logs:**
   ```bash
   docker compose logs wireguard
   ```

### Client Connected But Can't Access Services

1. **Verify routing:**
   ```bash
   # On client
   ip route show
   # Should show route for 172.20.0.0/16 via WireGuard
   ```

2. **Test DNS:**
   ```bash
   dig example.com @192.168.2.214
   ```

3. **Check service health:**
   ```bash
   make health-check
   ```

### Regenerate Client Configs

```bash
# Stop WireGuard
docker compose stop wireguard

# Remove config volume
docker volume rm homelab_wireguard-config

# Restart (will regenerate configs)
docker compose up -d wireguard
```

## Security Best Practices

### 1. **Limit Peer Count**
- Only generate configs for devices you own
- Set `WIREGUARD_PEERS` to actual number needed

### 2. **Rotate Keys Regularly**
- Regenerate configs every 6-12 months
- Revoke access for lost devices immediately

### 3. **Monitor Connections**
- Check active peers regularly: `docker compose exec wireguard wg show`
- Alert on unexpected connections

### 4. **Use Split-Tunnel**
- Default config only routes homelab traffic through VPN
- Internet traffic goes direct (better performance)
- To route all traffic, set `AllowedIPs = 0.0.0.0/0` in client config

### 5. **Backup Configs**
```bash
# Backup all peer configs
docker compose cp wireguard:/config ./wireguard-backup
tar -czf wireguard-backup-$(date +%Y%m%d).tar.gz wireguard-backup/
```

## Advanced Configuration

### Custom Peer Names

Edit peer configs after generation:

```bash
docker compose exec wireguard vi /config/peer1/peer1.conf
```

### Add More Peers

Increase `WIREGUARD_PEERS` in `.env` and restart:

```bash
# Edit .env
WIREGUARD_PEERS=10

# Restart
docker compose restart wireguard
```

### Full-Tunnel Mode

To route ALL traffic through VPN (not just homelab):

```ini
# In client config, change:
AllowedIPs = 0.0.0.0/0, ::/0
```

**Warning**: This routes all internet traffic through your homelab!

## Integration with Other Services

### Configure Applications to Use VPN

**npm (Verdaccio):**
```bash
npm config set registry http://172.20.0.12:4873
```

**Maven (Nexus):**
```xml
<mirror>
  <id>nexus</id>
  <url>http://172.20.0.11:8081/repository/maven-public/</url>
  <mirrorOf>*</mirrorOf>
</mirror>
```

**Docker (Nexus Registry):**
```json
{
  "insecure-registries": ["172.20.0.11:8082"]
}
```

## Performance Tuning

### MTU Optimization

If experiencing slow speeds, adjust MTU:

```ini
# In client config [Interface] section:
MTU = 1420
```

### Keepalive Tuning

For mobile devices on cellular:

```ini
# In client config [Peer] section:
PersistentKeepalive = 25  # Default
# Or for better battery life:
PersistentKeepalive = 60
```

## Uninstall

```bash
# Stop and remove WireGuard
docker compose stop wireguard
docker compose rm wireguard

# Remove config volume (WARNING: deletes all peer configs!)
docker volume rm homelab_wireguard-config
```

---

**Need Help?** Check logs: `docker compose logs wireguard`
