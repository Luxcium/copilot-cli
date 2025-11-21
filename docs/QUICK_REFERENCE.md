# Quick Reference Guide

**Last Updated:** 2025-11-19T17:37:00Z

## 🚀 Quick Commands

```bash
# Check status (do this first!)
./scripts/setup-postgres.sh --status

# Initial setup (database only)
./scripts/setup-postgres.sh --setup

# Setup with web UI
./scripts/setup-postgres.sh --setup --with-ui

# Start services
./scripts/setup-postgres.sh --start

# Stop services
./scripts/setup-postgres.sh --stop

# Preview changes
./scripts/setup-postgres.sh --dry-run [--setup|--start|--stop]
```

## 🔌 Access Points

| Service | Access | Credentials |
|---------|--------|-------------|
| **PostgreSQL** | `localhost:5434` | See `.env` file |
| **pgAdmin** | `http://localhost:5435` | See `.env` file |

## 💻 Connect to Database

### From Host
```bash
# Quick psql connection
psql "postgresql://copilot_user:PASSWORD@localhost:5434/copilot_cli"

# Or from .env
source .env && psql "$DATABASE_URL"
```

### From Docker
```bash
docker exec -it copilot-cli-postgres psql -U copilot_user -d copilot_cli
```

### From Code (Node.js example)
```javascript
const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL
});
```

## 📊 Status Output Explained

```
📊 PostgreSQL Database:
✓ Status: Running ✓              # Container is running
   Port: 5434                     # Host port (avoid 5432 collision)
   Database: copilot_cli          # Database name
   User: copilot_user             # Database user
   Started: 2025-11-19 12:36:06   # When container started
✓  Connection: Accepting ✓        # Ready for queries
   Size: 7516 kB                  # Current database size

🌐 Web UI (pgAdmin):
✓ Status: Running ✓              # Web UI available
   URL: http://localhost:5435    # Access point
   Started: 2025-11-19 12:37:08  # When started

💡 For AI Agents:                 # Quick hints for automation
   - Database ready
   - Use $DATABASE_URL from .env
   - Port 5434 for SQL access
   - Credentials in: /path/.env
```

## 🤖 For AI Agents

**Before any database operation:**
1. Run `--status` to check if database is running
2. If stopped, run `--start` 
3. Use `$DATABASE_URL` from `.env` for connections
4. All timestamps are in UTC (ISO 8601)
5. Script is idempotent (safe to re-run)

**Key Information:**
- Database Port: `5434` (non-standard to avoid conflicts)
- Web UI Port: `5435` (if enabled)
- Credentials: `.env` file (chmod 600, gitignored)
- Data persistence: Docker volume `copilot-cli-pgdata`
- All operations logged to `logs/postgres-setup.log`

## 🛠️ Troubleshooting

### Container won't start?
```bash
# Check logs
docker logs copilot-cli-postgres

# Check if port is in use
ss -tuln | grep 5434

# Nuclear option (⚠️ deletes data!)
docker stop copilot-cli-postgres
docker rm copilot-cli-postgres
docker volume rm copilot-cli-pgdata
./scripts/setup-postgres.sh --setup
```

### Can't connect?
```bash
# Verify container is running
docker ps | grep copilot-cli-postgres

# Test connection
docker exec copilot-cli-postgres pg_isready -U copilot_user

# Restart if needed
./scripts/setup-postgres.sh --stop
./scripts/setup-postgres.sh --start
```

## 📝 Notes

- **Port 5434** chosen to avoid conflicts with system PostgreSQL (5432)
- **Port 5435** for pgAdmin to stay near PostgreSQL port
- Containers use `--restart unless-stopped` (auto-start on reboot)
- All passwords are 25-char random strings
- Data persists in Docker volumes (survives container removal)

---

**See Also:**
- [DATABASE.md](./DATABASE.md) - Detailed database documentation
- [SCRIPTS.md](./SCRIPTS.md) - Scripts reference
- [SAFETY_GUIDELINES.md](../SAFETY_GUIDELINES.md) - Safety rules
