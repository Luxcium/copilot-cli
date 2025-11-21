# AI Agent Operational Guide

**Last Updated:** 2025-11-21  
**Purpose:** Comprehensive guide for AI agents working with copilot-cli in both local and cloud environments

## Critical First Steps

Before any operation, AI agents **MUST**:

1. ✅ Read [SAFETY_GUIDELINES.md](../SAFETY_GUIDELINES.md) - understand constraints
2. ✅ Detect environment (local vs cloud)
3. ✅ Use appropriate configuration for environment
4. ✅ Verify isolation between environments
5. ✅ Log all operations

## Environment Detection

### Quick Detection

```bash
# Source the detection script
source scripts/detect-environment.sh

# Now you have:
# - $DEPLOYMENT_ENV: "local" or "cloud"
# - $IS_CI: "true" or "false"
# - $POSTGRES_HOST, $POSTGRES_PORT: configured for your environment
# - $DATABASE_URL: ready to use connection string
```

### Manual Detection

```bash
if [ -n "${GITHUB_ACTIONS}" ] || [ -n "${CI}" ]; then
    echo "Running in cloud/CI environment"
    DEPLOYMENT_ENV="cloud"
else
    echo "Running in local environment"
    DEPLOYMENT_ENV="local"
fi
```

## Environment-Specific Operations

### Local Environment Operations

**Characteristics:**
- Running on user's Fedora 42 workstation
- Docker containers for services
- Persistent data in volumes
- Custom port 5434 to avoid conflicts

**Before operations:**
```bash
# 1. Check if setup exists
./scripts/setup-postgres.sh --status

# 2. Start if needed
./scripts/setup-postgres.sh --start

# 3. Load credentials
source .env

# 4. Verify connection
psql "$DATABASE_URL" -c "SELECT version();"
```

**Database operations:**
```bash
# Connect to database
source .env
psql "$DATABASE_URL"

# Or via Docker
docker exec -it copilot-cli-postgres psql -U copilot_user -d copilot_cli

# Run query
docker exec copilot-cli-postgres psql -U copilot_user -d copilot_cli -c "SELECT * FROM your_table;"
```

**Key constraints:**
- ❌ Never modify files outside `/projects/copilot-cli/`
- ❌ Never install packages without permission
- ❌ Never execute destructive commands without dry-run
- ✅ Always use scripts for system interactions
- ✅ Always log operations to `logs/`

### Cloud/CI Environment Operations

**Characteristics:**
- Running in GitHub Actions or similar
- Service containers (auto-managed)
- Ephemeral data (destroyed after job)
- Standard port 5432

**Environment setup (automatic in workflow):**
```yaml
services:
  postgres:
    image: postgres:16-alpine
    env:
      POSTGRES_USER: copilot_user
      POSTGRES_PASSWORD: ${{ secrets.POSTGRES_PASSWORD }}
      POSTGRES_DB: copilot_cli
```

**Database operations:**
```bash
# Environment variables are already set
# No need to source .env

# Connect to database
PGPASSWORD=$POSTGRES_PASSWORD psql -h localhost -U copilot_user -d copilot_cli

# Run query
PGPASSWORD=$POSTGRES_PASSWORD psql -h localhost -U copilot_user -d copilot_cli -c "SELECT version();"
```

**Key constraints:**
- ✅ Data is ephemeral (good for testing)
- ✅ Fully isolated from local environment
- ✅ No persistent state needed
- ❌ Don't try to access `.env` file (doesn't exist)
- ❌ Don't try to use port 5434 (use 5432)

## Common Operations by Environment

### Check Database Status

**Local:**
```bash
./scripts/setup-postgres.sh --status
```

**Cloud:**
```bash
# Check if service is ready
pg_isready -h localhost -U copilot_user

# Or with psql
PGPASSWORD=$POSTGRES_PASSWORD psql -h localhost -U copilot_user -d copilot_cli -c "SELECT 1;"
```

### Create a Table

**Local:**
```bash
source .env
psql "$DATABASE_URL" -c "
  CREATE TABLE IF NOT EXISTS test_table (
    id SERIAL PRIMARY KEY,
    created_at TIMESTAMP DEFAULT NOW(),
    data TEXT
  );
"
```

**Cloud:**
```bash
PGPASSWORD=$POSTGRES_PASSWORD psql -h localhost -U copilot_user -d copilot_cli -c "
  CREATE TABLE IF NOT EXISTS test_table (
    id SERIAL PRIMARY KEY,
    created_at TIMESTAMP DEFAULT NOW(),
    data TEXT
  );
"
```

### Insert Data

**Local:**
```bash
source .env
psql "$DATABASE_URL" -c "INSERT INTO test_table (data) VALUES ('test data');"
```

**Cloud:**
```bash
PGPASSWORD=$POSTGRES_PASSWORD psql -h localhost -U copilot_user -d copilot_cli -c "INSERT INTO test_table (data) VALUES ('test data');"
```

### Query Data

**Local:**
```bash
source .env
psql "$DATABASE_URL" -c "SELECT * FROM test_table;"
```

**Cloud:**
```bash
PGPASSWORD=$POSTGRES_PASSWORD psql -h localhost -U copilot_user -d copilot_cli -c "SELECT * FROM test_table;"
```

## Decision Tree for AI Agents

```
┌─────────────────────────────┐
│ Start Operation             │
└──────────┬──────────────────┘
           │
           ▼
    ┌──────────────┐
    │ Detect Env   │
    └──────┬───────┘
           │
      ┌────┴────┐
      │         │
      ▼         ▼
   Local      Cloud
      │         │
      │         │
      ▼         ▼
  ┌─────┐   ┌─────┐
  │ .env│   │ ENV │  (Credentials)
  │ file│   │ VARS│
  └──┬──┘   └──┬──┘
     │         │
     ▼         ▼
  Port       Port
  5434       5432
     │         │
     │         │
     ▼         ▼
  Docker     Service
  Container  Container
     │         │
     │         │
     └────┬────┘
          │
          ▼
    ┌──────────┐
    │ Execute  │
    │ Operation│
    └──────────┘
```

## Safety Checklists

### Before Local Operations

- [ ] Confirmed running in local environment
- [ ] Read SAFETY_GUIDELINES.md
- [ ] Database container is running (--status)
- [ ] `.env` file exists and is readable
- [ ] Operation stays within `/projects/copilot-cli/`
- [ ] No destructive operations without dry-run
- [ ] Prepared to log to `logs/` directory

### Before Cloud Operations

- [ ] Confirmed running in cloud/CI environment
- [ ] Verified `GITHUB_ACTIONS` or `CI` variable is set
- [ ] Database service is configured in workflow
- [ ] Environment variables are set (not using .env)
- [ ] Understanding data is ephemeral
- [ ] Operation is appropriate for cloud context

## Common Patterns

### Pattern 1: Environment-Agnostic Query

```bash
#!/bin/bash
set -euo pipefail

# Detect and configure environment
source scripts/detect-environment.sh

# Now execute query using configured variables
PGPASSWORD="$POSTGRES_PASSWORD" psql \
  -h "$POSTGRES_HOST" \
  -p "$POSTGRES_PORT" \
  -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" \
  -c "SELECT version();"
```

### Pattern 2: Conditional Local Setup

```bash
#!/bin/bash
set -euo pipefail

if [ -z "${CI:-}" ]; then
    # Local environment - ensure database is running
    ./scripts/setup-postgres.sh --status
    
    if ! docker ps | grep -q copilot-cli-postgres; then
        echo "Starting database..."
        ./scripts/setup-postgres.sh --start
    fi
    
    source .env
else
    # Cloud environment - verify service is ready
    until pg_isready -h localhost -U copilot_user; do
        echo "Waiting for database..."
        sleep 1
    done
fi

# Continue with operations...
```

### Pattern 3: Safe Schema Migration

```bash
#!/bin/bash
set -euo pipefail

# Load environment
source scripts/detect-environment.sh

# Define migration
MIGRATION_SQL="
CREATE TABLE IF NOT EXISTS schema_version (
  version INTEGER PRIMARY KEY,
  applied_at TIMESTAMP DEFAULT NOW()
);
"

# Apply migration
if [ "$DEPLOYMENT_ENV" = "local" ]; then
    echo "Applying migration locally..."
    psql "$DATABASE_URL" -c "$MIGRATION_SQL"
else
    echo "Applying migration in cloud..."
    PGPASSWORD="$POSTGRES_PASSWORD" psql \
      -h "$POSTGRES_HOST" \
      -p "$POSTGRES_PORT" \
      -U "$POSTGRES_USER" \
      -d "$POSTGRES_DB" \
      -c "$MIGRATION_SQL"
fi
```

## Error Handling

### Connection Errors

**Local - Database Not Running:**
```bash
Error: could not connect to server: Connection refused
Solution:
  ./scripts/setup-postgres.sh --start
```

**Local - Wrong Port:**
```bash
Error: could not connect to server: Connection refused
Solution:
  Check you're using port 5434 (not 5432)
  source .env && echo $POSTGRES_PORT
```

**Cloud - Service Not Ready:**
```bash
Error: could not connect to server: Connection refused
Solution:
  Add health check wait in workflow:
    until pg_isready -h localhost; do sleep 1; done
```

### Authentication Errors

**Local - Missing .env:**
```bash
Error: POSTGRES_PASSWORD not set
Solution:
  Run ./scripts/setup-postgres.sh to create .env
```

**Cloud - Missing Environment Variable:**
```bash
Error: POSTGRES_PASSWORD not set
Solution:
  Set in workflow:
    env:
      POSTGRES_PASSWORD: test_password
```

### Permission Errors

**Local - .env Not Readable:**
```bash
Error: Permission denied: .env
Solution:
  chmod 600 .env
  # Or regenerate: rm .env && ./scripts/setup-postgres.sh
```

## Logging Guidelines

### Local Operations

```bash
# Create log directory
mkdir -p logs

# Log to file
LOG_FILE="logs/operation-$(date +%Y%m%d-%H%M%S).log"

echo "Starting operation..." | tee -a "$LOG_FILE"
# ... operations ...
echo "Completed successfully" | tee -a "$LOG_FILE"
```

### Cloud Operations

```bash
# Logs go to GitHub Actions automatically
echo "::notice::Starting operation"
# ... operations ...
echo "::notice::Completed successfully"

# For errors
echo "::error::Operation failed: reason"
```

## Best Practices for AI Agents

### 1. Always Detect Environment First

```bash
# DON'T assume environment
psql -h localhost -p 5434 ...  # ❌ May be wrong port

# DO detect and use appropriate config
source scripts/detect-environment.sh
psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" ...  # ✅ Correct
```

### 2. Handle Both Environments Gracefully

```bash
# DON'T hardcode for one environment
source .env  # ❌ Fails in cloud

# DO check environment
if [ -f .env ]; then
    source .env
elif [ -n "${POSTGRES_PASSWORD}" ]; then
    # Use environment variables
    :
else
    echo "Error: No credentials found"
    exit 1
fi
```

### 3. Verify Operations

```bash
# After any operation, verify it worked
if psql "$DATABASE_URL" -c "SELECT 1;" &> /dev/null; then
    echo "✓ Operation successful"
else
    echo "✗ Operation failed"
    exit 1
fi
```

### 4. Clean Up in Cloud

```bash
# In cloud/CI, cleanup is automatic (ephemeral)
# But for consistency, close connections properly
psql "$DATABASE_URL" -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$POSTGRES_DB';"
```

### 5. Document Your Operations

```bash
# Always explain what you're doing
echo "Creating users table for authentication..."
psql "$DATABASE_URL" -c "CREATE TABLE users (...);"

echo "Inserting test data..."
psql "$DATABASE_URL" -c "INSERT INTO users ..."

echo "Verifying data..."
psql "$DATABASE_URL" -c "SELECT COUNT(*) FROM users;"
```

## Quick Reference Commands

### Environment Detection
```bash
source scripts/detect-environment.sh
echo "Environment: $DEPLOYMENT_ENV"
echo "CI: $IS_CI"
```

### Local Setup
```bash
./scripts/setup-postgres.sh --status
./scripts/setup-postgres.sh --start
source .env
```

### Cloud Connection
```bash
PGPASSWORD=$POSTGRES_PASSWORD psql -h localhost -U copilot_user -d copilot_cli
```

### Universal Connection (after environment detection)
```bash
source scripts/detect-environment.sh
PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB"
```

## Related Documentation

- [README.md](../README.md) - Repository overview
- [SAFETY_GUIDELINES.md](../SAFETY_GUIDELINES.md) - **MUST READ** safety rules
- [DATABASE.md](./DATABASE.md) - Local database setup
- [CLOUD_DEPLOYMENT.md](./CLOUD_DEPLOYMENT.md) - Cloud deployment details
- [SCRIPTS.md](./SCRIPTS.md) - Available scripts
- [QUICK_REFERENCE.md](./QUICK_REFERENCE.md) - Quick command reference

## Support

**For local issues:**
- Check `logs/postgres-setup.log`
- Run `./scripts/setup-postgres.sh --status`

**For cloud issues:**
- Check GitHub Actions logs
- Review workflow file: `.github/workflows/validate-setup.yml`

**For isolation issues:**
- Verify `.env` is gitignored
- Check no hardcoded paths in scripts
- Ensure proper environment detection

---

**Remember:** Local is persistent, cloud is ephemeral. Always detect environment before operations!
