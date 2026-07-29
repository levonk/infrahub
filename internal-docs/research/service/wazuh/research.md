# Wazuh Security Platform - Docker Deployment Research

## Executive Summary

Wazuh is an open-source security platform that provides SIEM (Security Information and Event Management), XDR (Extended Detection and Response), and threat intelligence capabilities. It is a fork of OSSEC with significant enhancements. This document provides comprehensive research on Wazuh's Docker deployment for use in an Ansible role targeting Windows Docker Desktop hosts.

## 1. Official Docker Deployment Method

### Repository and Documentation

- **Official Docker Repository**: https://github.com/wazuh/wazuh-docker
- **Main Repository**: https://github.com/wazuh/wazuh
- **Official Documentation**: https://documentation.wazuh.com/current/deployment-options/docker/index.html
- **Docker Hub Organization**: https://hub.docker.com/u/wazuh

### Docker Compose Stack Components

The `wazuh-docker` repository provides two deployment configurations:

#### Single-Node Stack
- **wazuh-manager**: Analyzes security events, applies detection rules, manages agents
- **wazuh-indexer**: OpenSearch-based storage and indexing engine
- **wazuh-dashboard**: Web UI based on OpenSearch Dashboards fork

#### Multi-Node Stack
- **2x wazuh-manager** (master + worker): High-availability manager cluster
- **3x wazuh-indexer**: Distributed OpenSearch cluster for scalability and fault tolerance
- **1x wazuh-dashboard**: Web interface
- **1x nginx proxy**: Load balancer and SSL termination (optional)

### Upstream Docker Images and Registry

All images are hosted on Docker Hub at `docker.io/wazuh/`:

| Image | Latest Stable Tag (4.x) | Registry |
|-------|------------------------|----------|
| `wazuh/wazuh-manager` | `4.14.6` | docker.io/wazuh/wazuh-manager |
| `wazuh/wazuh-indexer` | `4.14.6` | docker.io/wazuh/wazuh-indexer |
| `wazuh/wazuh-dashboard` | `4.14.6` | docker.io/wazuh/wazuh-dashboard |
| `wazuh/wazuh-certs-generator` | `0.0.4` | docker.io/wazuh/wazuh-certs-generator |

**Version Tagging Pattern**: Images follow semantic versioning (e.g., `4.14.6`). All components in a stack should use the same version tag for compatibility.

### Multi-Architecture Support

**Status**: Official multi-arch images available (AMD64 + ARM64)

### Required Ports

| Port | Protocol | Component | Purpose |
|------|----------|-----------|---------|
| **1514** | TCP | Wazuh Manager | Agent communication service |
| **1515** | TCP | Wazuh Manager | Agent enrollment service |
| **55000** | TCP | Wazuh Manager | Wazuh server RESTful API |
| **9200** | TCP | Wazuh Indexer | Indexer RESTful API (internal) |
| **5601** | TCP | Wazuh Dashboard | Web UI (HTTP inside container) |

### Required Volumes

#### Wazuh Manager Volumes
| Volume Name | Container Path | Purpose |
|-------------|----------------|---------|
| `wazuh_api_configuration` | `/var/wazuh-manager/api/configuration` | API configuration |
| `wazuh_etc` | `/var/wazuh-manager/etc` | Manager configuration files |
| `wazuh_logs` | `/var/wazuh-manager/logs` | Manager logs |
| `wazuh_queue` | `/var/wazuh-manager/queue` | Event queue |
| `wazuh_var_multigroups` | `/var/wazuh-manager/var/multigroups` | Multi-group data |

#### Wazuh Indexer Volumes
| Volume Name | Container Path | Purpose |
|-------------|----------------|---------|
| `wazuh-indexer-data` | `/var/lib/wazuh-indexer` | Indexed data storage |

#### Wazuh Dashboard Volumes
| Volume Name | Container Path | Purpose |
|-------------|----------------|---------|
| `wazuh-dashboard-config` | `/usr/share/wazuh-dashboard/config` | Dashboard configuration |
| `wazuh-dashboard-custom` | `/usr/share/wazuh-dashboard/plugins/wazuh/public/assets/custom` | Custom assets |

### Required Secrets

| Credential Type | Default Username | Environment Variable |
|-----------------|------------------|---------------------|
| Indexer Admin | `admin` | `INDEXER_USERNAME`, `INDEXER_PASSWORD` |
| Dashboard User | `kibanaserver` | `DASHBOARD_USERNAME`, `DASHBOARD_PASSWORD` |
| Wazuh API | `wazuh-wui` | `API_USERNAME`, `API_PASSWORD` |

**Password Requirements**: API password must be 8+ characters with uppercase, lowercase, and special characters.

### Certificate Generation

Before first deployment, generate self-signed certificates using the `wazuh-certs-generator` container. Certificates are needed for:
- Manager: root-ca.pem, wazuh.manager.pem, wazuh.manager-key.pem
- Indexer: root-ca.pem, wazuh.indexer.pem, wazuh.indexer-key.pem, admin.pem, admin-key.pem
- Dashboard: root-ca.pem, wazuh.dashboard.pem, wazuh.dashboard-key.pem

### Environment Variables

#### Wazuh Manager
- `WAZUH_INDEXER_HOSTS=wazuh.indexer:9200`
- `WAZUH_NODE_NAME=manager`
- `INDEXER_USERNAME`, `INDEXER_PASSWORD`
- `API_USERNAME`, `API_PASSWORD`

#### Wazuh Indexer
- `OPENSEARCH_JAVA_OPTS=-Xms1g -Xmx1g`
- `bootstrap.memory_lock=true`
- `network.host=0.0.0.0`
- `node.name=wazuh.indexer`
- `cluster.initial_cluster_manager_nodes=wazuh.indexer`
- `node.max_local_storage_nodes=1`
- `plugins.security.allow_default_init_securityindex=true`
- `NODES_DN=CN=wazuh.indexer,OU=Wazuh,O=Wazuh,L=California,C=US`

#### Wazuh Dashboard
- `SERVER_PORT=5601`
- `SERVER_HOST=0.0.0.0`
- `OPENSEARCH_HOSTS=https://wazuh.indexer:9200`
- `INDEXER_USERNAME`, `INDEXER_PASSWORD`
- `WAZUH_API_URL=https://wazuh.manager`
- `DASHBOARD_USERNAME`, `DASHBOARD_PASSWORD`

### System Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 4 cores | 4+ cores |
| RAM | 8 GB | 16 GB |
| Disk Space | 50 GB | 100 GB+ SSD |

### Critical Kernel Parameter

`vm.max_map_count=262144` required for Wazuh Indexer (OpenSearch). Must be set in WSL2 on Windows.

### Healthcheck Endpoints

- **Manager**: `/var/wazuh-manager/bin/wazuh-manager-control status`
- **Indexer**: `curl -fks https://localhost:9200/_plugins/_security/health`
- **Dashboard**: `curl -k -s -o /dev/null https://localhost:5601/login`

## 2. Architecture

Wazuh follows a server-agent architecture with three central components:

- **Wazuh Manager**: Analyzes security events, applies detection rules, manages agents (ports 1514, 1515, 55000)
- **Wazuh Indexer**: OpenSearch-based storage and indexing engine (port 9200, internal)
- **Wazuh Dashboard**: Web UI based on OpenSearch Dashboards fork (port 5601)

Agents connect to the manager on port 1514 (TCP) for event transmission and port 1515 (TCP) for enrollment.

## 3. Version Information

**Current Stable Release**: Wazuh v4.14.6 (July 2026)
**Beta Release**: Wazuh v5.0.0-beta3

Use v4.14.6 for production (v5.0 is still beta).

## 4. Windows Docker Desktop Considerations

- Officially supported via WSL2 backend
- Linux containers run natively under WSL2
- Must set `vm.max_map_count=262144` in WSL2
- Use TCP 1514 for agent communication (not UDP)
- Ensure Windows Firewall allows inbound TCP 1514, 1515, 55000

## 5. Alternatives

Wazuh is the recommended choice for a small Tailscale-attached fleet with Windows + Linux + OCI hosts:
- Full platform support (Windows, Linux, macOS agents)
- Runs on Windows Docker Desktop via WSL2
- Comprehensive SIEM/XDR capabilities
- Open source, no licensing fees

Alternatives (OSSEC, Suricata, Zeek, Elastic Security, Security Onion, Falco) are either abandoned, complementary, too heavy, or lack Windows support.

## References

- https://github.com/wazuh/wazuh-docker
- https://github.com/wazuh/wazuh
- https://documentation.wazuh.com/current/
- https://hub.docker.com/u/wazuh
