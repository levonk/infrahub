# RustFS Service

RustFS is a high-performance, S3-compatible object storage system built in Rust. This service provides a drop-in replacement for MinIO with superior performance and memory safety.

## 🚀 Features

- **High Performance**: Built with Rust for maximum speed and resource efficiency
- **S3 Compatible**: Full compatibility with existing S3 applications and tools
- **Distributed Architecture**: Scalable and fault-tolerant design
- **Data Lake Support**: Optimized for high-throughput big data and AI workloads
- **Open Source**: Apache 2.0 license for unrestricted commercial use
- **Security**: Memory safety and secure distributed features

## 📋 Service Details

- **Container Name**: `localnet-rustfs`
- **S3 API Port**: 9000 (default)
- **Console Port**: 9001 (default)
- **Default Credentials**: `rustfsadmin` / `rustfsadmin`
- **Data Storage**: `/data` (mounted from host)
- **Logs**: `/app/logs` (mounted from host)

## 🔧 Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CLOUD_RUSTFS_HOST_PORT` | 9000 | Host port for S3 API |
| `CLOUD_RUSTFS_CONSOLE_HOST_PORT` | 9001 | Host port for web console |
| `CLOUD_RUSTFS_ACCESS_KEY` | rustfsadmin | S3 access key |
| `CLOUD_RUSTFS_SECRET_KEY` | rustfsadmin | S3 secret key |
| `CLOUD_RUSTFS_LOG_LEVEL` | info | Logging level (debug, info, warn, error) |
| `CLOUD_RUSTFS_DATA_PATH` | ./data | Path to data directory |
| `CLOUD_RUSTFS_LOGS_PATH` | ./logs | Path to logs directory |
| `CLOUD_RUSTFS_TLS_PATH` | /opt/tls | Path to TLS certificates |
| `CLOUD_RUSTFS_OBS_ENDPOINT` | - | OpenTelemetry collector endpoint |

### Volume Mounts

- **Data Volume**: `${CLOUD_RUSTFS_DATA_PATH:-./data}:/data`
  - Stores object data and metadata
  - Ensure proper permissions (UID 10001 for rustfs user)
  
- **Logs Volume**: `${CLOUD_RUSTFS_LOGS_PATH:-./logs}:/app/logs`
  - Application logs and audit trails
  
- **TLS Volume** (optional): `${CLOUD_RUSTFS_CERTS_PATH}:/opt/tls`
  - TLS certificates for HTTPS access

## 🚀 Quick Start

### 1. Start the Service

```bash
# From localnet root directory
cd apps/active/devops/localnet
just up-cloud-rustfs
```

### 2. Access the Console

Open your web browser and navigate to:
- **Console**: http://localhost:9001
- **Credentials**: `rustfsadmin` / `rustfsadmin`

### 3. Create a Bucket

1. Log in to the RustFS console
2. Click "Create Bucket"
3. Enter bucket name (e.g., `my-test-bucket`)
4. Configure bucket settings (optional)

### 4. Test S3 Compatibility

```bash
# Using AWS CLI
aws s3 --endpoint-url http://localhost:9000 ls

# Create a bucket
aws s3 --endpoint-url http://localhost:9000 mb s3://test-bucket

# Upload a file
echo "Hello RustFS!" > test.txt
aws s3 --endpoint-url http://localhost:9000 cp test.txt s3://test-bucket/

# List objects
aws s3 --endpoint-url http://localhost:9000 ls s3://test-bucket/
```

## 🔒 Security

### Container Security

- **Non-root User**: Runs as `rustfs` user (UID 10001)
- **Capability Dropping**: All capabilities dropped except essential ones
- **No New Privileges**: Prevents privilege escalation
- **Resource Limits**: CPU and memory limits enforced

### Network Security

- **Internal Network**: Runs on dedicated `cloud-network`
- **Port Mapping**: Only expose necessary ports
- **TLS Support**: Optional HTTPS with certificate mounting

### Data Security

- **Access Control**: S3-compatible access keys
- **CORS**: Configurable cross-origin resource sharing
- **Audit Logging**: Comprehensive access logging

## 📊 Monitoring

### Health Checks

The service includes comprehensive health checks:

```bash
# Check container health
docker ps | grep rustfs

# View health check logs
docker logs localnet-rustfs | grep healthcheck
```

### Metrics

RustFS supports OpenTelemetry for observability:

```bash
# Enable metrics collection
CLOUD_RUSTFS_OBS_ENDPOINT=http://otel-collector:4317
```

### Logs

```bash
# View live logs
docker logs -f localnet-rustfs

# Check log files
ls -la ./logs/
```

## 🛠️ Development

### Building from Source

```bash
# Clone the repository
git clone https://github.com/rustfs/rustfs.git
cd rustfs

# Build multi-architecture images
./docker-buildx.sh --build-arg RELEASE=latest
```

### Configuration Files

- **Docker Compose**: `docker-compose.rustfs.yml`
- **Health Check**: `healthcheck/check-health.sh`
- **Environment**: See environment variables section

## 🔧 Troubleshooting

### Common Issues

#### Permission Denied Errors

```bash
# Fix data directory permissions
sudo chown -R 10001:10001 ./data
sudo chown -R 10001:10001 ./logs
```

#### Service Won't Start

```bash
# Check logs for errors
docker logs localnet-rustfs

# Verify configuration
docker inspect localnet-rustfs | grep Env
```

#### Health Check Failures

```bash
# Manual health check
curl -f http://localhost:9000/health
curl -f http://localhost:9001/rustfs/console/health
```

### Performance Tuning

#### Memory Usage

```yaml
# In docker-compose.rustfs.yml
deploy:
  resources:
    limits:
      memory: 4G
    reservations:
      memory: 1G
```

#### Storage Optimization

```bash
# Configure multiple storage volumes
RUSTFS_VOLUMES=/data/rustfs{0..3}
```

## 📚 References

- **RustFS Documentation**: https://docs.rustfs.com/
- **GitHub Repository**: https://github.com/rustfs/rustfs
- **S3 API Reference**: https://docs.aws.amazon.com/AmazonS3/latest/API/
- **Docker Hub**: https://hub.docker.com/r/rustfs/rustfs

## 🤝 Contributing

This service is part of the LocalNet development environment. For issues and improvements:

1. Check existing tickets in `.tickets/`
2. Create new tickets with `tkr create`
3. Follow the development workflow in `AGENTS.md`

## 📄 License

RustFS is licensed under the Apache License 2.0. See the [LICENSE](https://github.com/rustfs/rustfs/blob/main/LICENSE) file for details.
