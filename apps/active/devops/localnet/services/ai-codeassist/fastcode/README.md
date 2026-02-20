# FastCode Service Container

FastCode is an AI-powered code understanding and analysis system that accelerates and streamlines your code comprehension workflow. This service container provides a complete, production-ready deployment of FastCode with comprehensive security, monitoring, and operational features.

## 🚀 Features

### Core Capabilities
- **Semantic-Structural Code Representation**: Multi-layered codebase understanding for comprehensive analysis
- **Lightning-Fast Codebase Navigation**: Quick exploration and understanding of complex codebases
- **Cost-Efficient Context Management**: Optimized token usage and context handling
- **Multi-Language Support**: Python, JavaScript, TypeScript, Java, Go, C/C++, Rust, C#
- **Vector-Based Search**: Advanced semantic search using embeddings and vector databases
- **LLM Integration**: Support for OpenAI, Anthropic, and local models via Ollama

### Service Features
- **Web Interface**: User-friendly web UI for repository analysis
- **REST API**: Comprehensive API for programmatic access
- **Health Monitoring**: Built-in health checks and monitoring
- **Security Hardened**: Non-root execution, privilege dropping, secure defaults
- **Resource Management**: Configurable memory and CPU limits
- **Persistent Storage**: Data persistence across container restarts

## 📋 Prerequisites

- Docker and Docker Compose
- Access to LLM provider API (OpenAI, Anthropic, or local Ollama)
- Sufficient system resources (minimum 2GB RAM, 1 CPU core)

## 🛠️ Quick Start

### 1. Environment Configuration

Copy the example environment file and configure your settings:

```bash
cp env.example .env
```

Edit `.env` with your configuration:

```bash
# Required: OpenAI API key
FASTCODE_OPENAI_API_KEY=your_openai_api_key_here

# Optional: Change model or use alternative providers
FASTCODE_MODEL=gpt-4
FASTCODE_BASE_URL=https://api.openai.com/v1

# Optional: User configuration
USERNAME=fastcode
PUID=1000
PGID=1000
```

### 2. Start the Service

Using the LocalNet justfile (recommended):

```bash
cd apps/active/devops/localnet
just up-fastcode
```

Or directly with Docker Compose:

```bash
docker-compose -f services/ai-codeassist/fastcode/docker-compose.fastcode.yml up -d
```

### 3. Access FastCode

Open your browser and navigate to:
- **Web Interface**: http://localhost:5000
- **API Documentation**: http://localhost:5000/docs
- **Health Check**: http://localhost:5000/health

## 🔧 Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `FASTCODE_OPENAI_API_KEY` | OpenAI API key | Required |
| `FASTCODE_MODEL` | LLM model to use | `gpt-4` |
| `FASTCODE_BASE_URL` | LLM API base URL | `https://api.openai.com/v1` |
| `FASTCODE_HOST_PORT` | Service port | `5000` |
| `USERNAME` | Non-root user name | `fastcode` |
| `PUID` | User ID | `1000` |
| `PGID` | Group ID | `1000` |
| `FASTCODE_REPO_MOUNT` | External repository mount | Optional |

### LLM Provider Configuration

#### OpenAI (Default)
```bash
FASTCODE_OPENAI_API_KEY=sk-...
FASTCODE_MODEL=gpt-4
FASTCODE_BASE_URL=https://api.openai.com/v1
```

#### OpenRouter
```bash
FASTCODE_OPENAI_API_KEY=sk-or-...
FASTCODE_MODEL=google/gemini-3-flash-preview
FASTCODE_BASE_URL=https://openrouter.ai/api/v1
```

#### Ollama (Local)
```bash
FASTCODE_OPENAI_API_KEY=ollama
FASTCODE_MODEL=qwen3-coder-30b_fastcode
FASTCODE_BASE_URL=http://localhost:11434/v1
```

## 📊 Usage

### Web Interface

1. **Load Repository**: Use the web interface to load a Git repository or local codebase
2. **Ask Questions**: Query your codebase using natural language
3. **Explore Code**: Navigate through code with semantic understanding
4. **Get Insights**: Receive detailed explanations and analysis

### API Usage

```bash
# Load a repository
curl -X POST "http://localhost:5000/api/load-repository" \
  -H "Content-Type: application/json" \
  -d '{"source": "https://github.com/user/repo.git", "is_url": true}'

# Query the repository
curl -X POST "http://localhost:5000/api/query" \
  -H "Content-Type: application/json" \
  -d '{"question": "How does authentication work in this codebase?"}'
```

### CLI Access

```bash
# Enter the container
docker exec -it fastcode bash

# Use FastCode CLI
python main.py --repo /path/to/repo --query "Your question here"
```

## 🔍 Monitoring and Health

### Health Checks

The service includes comprehensive health checks:

```bash
# Check service health
curl http://localhost:5000/health

# View detailed health status
docker exec fastcode /app/assets/static/fastcode/healthcheck-fastcode.sh
```

### Logs

```bash
# View service logs
docker logs fastcode

# Follow logs in real-time
docker logs -f fastcode

# View application logs
docker exec fastcode tail -f /app/logs/fastcode.log
```

### Metrics

Access metrics at http://localhost:9090/metrics (if enabled).

## 🛡️ Security

### Security Features

- **Non-root Execution**: Runs as non-root user with dropped privileges
- **Resource Limits**: Configurable CPU and memory constraints
- **Secure Defaults**: Minimal attack surface, secure configurations
- **Health Monitoring**: Continuous health and security monitoring
- **Volume Isolation**: Proper file system permissions and isolation

### Security Configuration

```yaml
# Security options in docker-compose.yml
security_opt:
  - no-new-privileges:true
cap_drop:
  - ALL
cap_add:
  - CHOWN
  - SETGID
  - SETUID
  - DAC_OVERRIDE
```

## 🔧 Development

### Local Development

```bash
# Build the container
docker build -t fastcode:dev .

# Run with development settings
docker run -p 5000:5000 \
  -e DEBUG=true \
  -e RELOAD=true \
  -v $(pwd):/app \
  fastcode:dev
```

### Code Structure

```
fastcode/
├── Dockerfile.fastcode              # Container definition
├── docker-compose.fastcode.yml      # Service configuration
├── requirements.txt                 # Python dependencies
├── env.example                     # Environment template
├── assets/
│   └── static/
│       └── fastcode/
│           ├── entrypoint-fastcode.sh    # Container entrypoint
│           └── healthcheck-fastcode.sh    # Health check script
└── README.md                       # This file
```

## 🚨 Troubleshooting

### Common Issues

#### Service Not Starting
```bash
# Check logs
docker logs fastcode

# Verify environment variables
docker exec fastcode env | grep FASTCODE

# Check port conflicts
netstat -tlnp | grep 5000
```

#### Permission Issues
```bash
# Fix volume permissions
sudo chown -R 1000:1000 ./data ./logs ./repositories

# Check user permissions
docker exec fastcode id
```

#### Memory Issues
```bash
# Check memory usage
docker stats fastcode

# Increase memory limit
# Edit docker-compose.yml and update resources.limits.memory
```

#### API Key Issues
```bash
# Verify API key
docker exec fastcode curl -H "Authorization: Bearer $FASTCODE_OPENAI_API_KEY" \
  https://api.openai.com/v1/models

# Test connectivity
docker exec fastcode ping api.openai.com
```

### Debug Mode

Enable debug mode for detailed logging:

```bash
# Set debug environment variable
export DEBUG=true

# Or update docker-compose.yml
environment:
  - DEBUG=true
  - LOG_LEVEL=DEBUG
```

## 📈 Performance

### Optimization Tips

1. **Vector Database**: Use ChromaDB or FAISS for better search performance
2. **Caching**: Enable Redis caching for repeated queries
3. **Resource Allocation**: Allocate sufficient memory for large codebases
4. **Model Selection**: Use appropriate models for your use case

### Benchmarks

Typical performance metrics:
- **Indexing**: ~2-5 minutes per 10K lines of code
- **Query Response**: ~2-10 seconds depending on complexity
- **Memory Usage**: ~1-2GB for medium codebases

## 🔄 Updates and Maintenance

### Updating the Service

```bash
# Pull latest changes
git pull

# Rebuild container
docker-compose -f services/ai-codeassist/fastcode/docker-compose.fastcode.yml build

# Restart service
docker-compose -f services/ai-codeassist/fastcode/docker-compose.fastcode.yml up -d
```

### Backup and Recovery

```bash
# Backup data
docker run --rm -v fastcode_data:/data -v $(pwd):/backup \
  alpine tar czf /backup/fastcode-backup.tar.gz -C /data .

# Restore data
docker run --rm -v fastcode_data:/data -v $(pwd):/backup \
  alpine tar xzf /backup/fastcode-backup.tar.gz -C /data
```

## 📚 Additional Resources

- [FastCode GitHub Repository](https://github.com/HKUDS/FastCode)
- [FastCode Documentation](https://github.com/HKUDS/FastCode#readme)
- [LocalNet Development Guide](../AGENTS.md)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)

## 🤝 Contributing

To contribute to FastCode:

1. Fork the [FastCode repository](https://github.com/HKUDS/FastCode)
2. Create a feature branch
3. Make your changes
4. Test with this container
5. Submit a pull request

## 📄 License

This container configuration follows the same license as FastCode. See the [FastCode repository](https://github.com/HKUDS/FastCode) for details.

## 🆘 Support

For issues with:
- **FastCode Functionality**: Open an issue on the [FastCode GitHub](https://github.com/HKUDS/FastCode/issues)
- **Container Configuration**: Contact the LocalNet team
- **Deployment Issues**: Check the troubleshooting section above

---

**Note**: This service container is part of the LocalNet development environment. Please ensure you have the proper environment setup and follow the LocalNet guidelines for service management.
