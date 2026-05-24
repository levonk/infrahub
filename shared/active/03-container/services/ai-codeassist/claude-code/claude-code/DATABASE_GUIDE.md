# Database Backend Selection Guide

## Quick Start

### For Development (SQLite - Recommended)
```bash
# Use SQLite for fast, lightweight development
export DATABASE_TYPE=sqlite
export SQLITE_PATH=./dev-data/claude_code.db

# Start services
docker compose up
```

### For Production (PostgreSQL - Recommended)
```bash
# Use PostgreSQL for concurrent multi-user scenarios
export DATABASE_TYPE=postgresql
export DATABASE_URL=postgresql://user:password@host:5432/database
export CLAUDE_CODE_DB_PASSWORD=secure_password

# Start services
docker compose --profile postgresql up
```

## Database Comparison

| Feature | PostgreSQL | SQLite |
|---------|------------|--------|
| Concurrent Users | 100+ | 1 writer, multiple readers |
| Storage | Network/Files | Single file |
| ACID Compliance | Full | Full |
| JSON Support | JSONB (advanced) | TEXT (basic) |
| Resource Usage | High | Minimal |
| Setup Complexity | Complex | Simple |
| Backup | pg_dump/pg_restore | File copy |
| Network Access | Required | None |

## Switching Databases

The abstraction layer allows seamless switching:

1. **Stop services**: `docker compose down`
2. **Set environment**: `export DATABASE_TYPE=sqlite` or `postgresql`
3. **Configure connection**: Set `DATABASE_URL` or `SQLITE_PATH`
4. **Start services**: `docker compose up`

Data migration between databases requires manual export/import using standard database tools.
