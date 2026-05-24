# paperclip

Open-source orchestration for zero-human companies

## Overview

This is a Docker-based deployment of [Paperclip](https://github.com/paperclipai/paperclip), an open-source orchestration platform for autonomous AI companies.

## Quick Start

### Using Docker Compose

```bash
# Build and start the service
docker-compose up -d

# View logs
docker-compose logs -f

# Stop the service
docker-compose down
```

### Accessing Paperclip

Once the service is running, access the Paperclip web interface at:
- **URL**: http://localhost:3100
- **API**: http://localhost:3100/api

## Configuration

### Environment Variables

- `NODE_ENV`: Node.js environment (default: production)
- `PORT`: Port for the Paperclip API server (default: 3100)

- `DATABASE_URL`: PostgreSQL connection string

- `PAPERCLIP_BIND`: Bind address for the server (default: 0.0.0.0)

See `.env.example` for a complete list of environment variables.

### Database


This deployment includes a PostgreSQL container. The database is initialized with:
- **Database**: paperclip
- **User**: paperclip
- **Password**: paperclip

**Important**: Change the default credentials in production by setting the `DATABASE_URL` environment variable.


## Development

### Building the Image

```bash
docker build -t paperclip:latest .
```

### Running the Container

```bash
docker run -d \
  --name paperclip \
  -p 3100:3100 \

  -e DATABASE_URL=postgresql://user:pass@host:5432/db \

  paperclip:latest
```

## Maintenance

### Updating Paperclip

```bash
# Pull latest changes
git pull

# Rebuild and restart
docker-compose up -d --build
```

### Backup


```bash
# Backup PostgreSQL database
docker-compose exec postgres pg_dump -U paperclip paperclip > backup.sql

# Restore from backup
docker-compose exec -T postgres psql -U paperclip paperclip < backup.sql
```


## Troubleshooting

### Container won't start

Check the logs:
```bash
docker-compose logs paperclip
```

### Database connection issues


Ensure the PostgreSQL container is healthy:
```bash
docker-compose ps postgres
```


### Health check failing

The health check expects the Paperclip API to respond at `/health`. Ensure the service is fully started before checking health.

## Resources

- [Paperclip GitHub](https://github.com/paperclipai/paperclip)
- [Paperclip Documentation](https://github.com/paperclipai/paperclip/blob/master/doc/DEVELOPING.md)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

## License

This deployment follows the license of the Paperclip project.
