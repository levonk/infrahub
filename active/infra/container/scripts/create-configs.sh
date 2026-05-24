#!/usr/bin/env bash
# Create all configuration files for homelab services
# This script recreates config files that Docker may have created as directories

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIGS_DIR="$PROJECT_ROOT/configs"

echo "Creating configuration files..."

# Create Loki config
cat > "$CONFIGS_DIR/logging/loki.yaml" << 'EOF'
# Loki Configuration
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

ruler:
  alertmanager_url: http://localhost:9093
EOF

echo "✓ Created loki.yaml"

# Create Promtail config
cat > "$CONFIGS_DIR/logging/promtail.yaml" << 'EOF'
# Promtail Configuration
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*log
EOF

echo "✓ Created promtail.yaml"

# Create Blackbox Exporter config
cat > "$CONFIGS_DIR/monitoring/blackbox.yml" << 'EOF'
# Blackbox Exporter Configuration
modules:
  http_2xx:
    prober: http
    timeout: 5s
    http:
      valid_http_versions: ["HTTP/1.1", "HTTP/2.0"]
      valid_status_codes: []  # Defaults to 2xx
      method: GET
      preferred_ip_protocol: "ip4"
      
  http_post_2xx:
    prober: http
    timeout: 5s
    http:
      method: POST
      
  tcp_connect:
    prober: tcp
    timeout: 5s
    
  icmp:
    prober: icmp
    timeout: 5s
    icmp:
      preferred_ip_protocol: "ip4"
      
  dns_udp:
    prober: dns
    timeout: 5s
    dns:
      transport_protocol: "udp"
      preferred_ip_protocol: "ip4"
      query_name: "example.com"
EOF

echo "✓ Created blackbox.yml"

# Ensure base web config directory exists
mkdir -p "$CONFIGS_DIR/web"

# Create Squid config
cat > "$CONFIGS_DIR/web/squid.conf" << 'EOF'
# Squid Proxy Configuration
# Basic configuration for homelab use

# Port configuration
http_port 3128

# Access control
acl localnet src 172.20.0.0/16  # Homelab network
acl SSL_ports port 443
acl Safe_ports port 80          # http
acl Safe_ports port 443         # https
acl CONNECT method CONNECT

# Deny requests to certain unsafe ports
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports

# Allow localhost and localnet
http_access allow localhost
http_access allow localnet

# Deny all other access
http_access deny all

# Cache settings
cache_dir ufs /var/spool/squid 1000 16 256
maximum_object_size 100 MB
cache_mem 256 MB

# Logging
access_log stdio:/var/log/squid/access.log squid
cache_log /var/log/squid/cache.log
cache_store_log /var/log/squid/store.log

# DNS
dns_nameservers 172.20.0.2

# Misc
coredump_dir /var/spool/squid
refresh_pattern ^ftp:           1440    20%     10080
refresh_pattern ^gopher:        1440    0%      1440
refresh_pattern -i (/cgi-bin/|\?) 0     0%      0
refresh_pattern .               0       20%     4320
EOF

echo "✓ Created squid.conf"

# Create Envoy config directory and file
ENVOY_CONFIG_DIR="$CONFIGS_DIR/web/envoy"
mkdir -p "$ENVOY_CONFIG_DIR"
cat > "$ENVOY_CONFIG_DIR/envoy.yaml" << 'EOF'
# Envoy Proxy Configuration
static_resources:
  listeners:
  - name: listener_0
    address:
      socket_address:
        address: 0.0.0.0
        port_value: 10000
    filter_chains:
    - filters:
      - name: envoy.filters.network.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          stat_prefix: ingress_http
          access_log:
          - name: envoy.access_loggers.stdout
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.access_loggers.stream.v3.StdoutAccessLog
          http_filters:
          - name: envoy.filters.http.router
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router
          route_config:
            name: local_route
            virtual_hosts:
            - name: local_service
              domains: ["*"]
              routes:
              - match:
                  prefix: "/"
                route:
                  cluster: service_backend

  clusters:
  - name: service_backend
    connect_timeout: 0.25s
    type: LOGICAL_DNS
    lb_policy: ROUND_ROBIN
    load_assignment:
      cluster_name: service_backend
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: squid
                port_value: 3128

admin:
  address:
    socket_address:
      address: 0.0.0.0
      port_value: 9901
EOF

echo "✓ Created envoy/envoy.yaml"

# Create Privoxy config
cat > "$CONFIGS_DIR/web/privoxy/config" << 'EOF'
# Privoxy Configuration
# Basic privacy-focused proxy

# Listen on all interfaces
listen-address  0.0.0.0:8118

# Forward to parent proxy (Squid)
forward / squid:3128

# Logging
logdir /var/log/privoxy
logfile logfile

# Access control
permit-access  172.20.0.0/16

# Privacy settings
enable-remote-toggle  0
enable-remote-http-toggle  0
enable-edit-actions 0

# Filtering
actionsfile match-all.action
actionsfile default.action
filterfile default.filter

# Misc
toggle  1
enable-proxy-authentication-forwarding 0
buffer-limit 4096
EOF

echo "✓ Created privoxy/config"

# Create Verdaccio config
cat > "$CONFIGS_DIR/artifacts/verdaccio/config.yaml" << 'EOF'
# Verdaccio Configuration
# https://verdaccio.org/docs/configuration

storage: /verdaccio/storage/data
plugins: /verdaccio/plugins

# Web UI
web:
  title: Homelab NPM Registry
  enable: true

# Authentication
auth:
  htpasswd:
    file: /verdaccio/storage/htpasswd
    max_users: -1

# Uplinks (proxy to npmjs.org)
uplinks:
  npmjs:
    url: https://registry.npmjs.org/
    timeout: 30s

# Packages access control
packages:
  '@*/*':
    access: $all
    publish: $authenticated
    unpublish: $authenticated
    proxy: npmjs

  '**':
    access: $all
    publish: $authenticated
    unpublish: $authenticated
    proxy: npmjs

# Server configuration
server:
  keepAliveTimeout: 60

# Logs
logs: { type: stdout, format: pretty, level: http }

# Listen on all interfaces
listen: 0.0.0.0:4873
EOF

echo "✓ Created verdaccio/config.yaml"

echo ""
echo "✅ All configuration files created successfully!"
echo ""
echo "Config files created:"
echo "  - configs/logging/loki.yaml"
echo "  - configs/logging/promtail.yaml"
echo "  - configs/monitoring/blackbox.yml"
echo "  - configs/web/squid.conf"
echo "  - configs/web/envoy.yaml"
echo "  - configs/web/privoxy/config"
echo "  - configs/artifacts/verdaccio/config.yaml"
