# Scripts Reference

## Overview

All automation scripts follow strict safety guidelines and best practices. Every script includes:
- Dry-run mode
- Input validation
- Error handling
- Logging
- Clear usage documentation

## Available Scripts

### `scripts/setup-postgres.sh`

**Purpose:** Set up and manage PostgreSQL Docker container for persistent data storage.

**Location:** [`scripts/setup-postgres.sh`](../scripts/setup-postgres.sh)

**Usage:**
```bash
./scripts/setup-postgres.sh [OPTIONS]

OPTIONS:
    --dry-run       Show what would be done without making changes
    --setup         Set up and start PostgreSQL (default)
    --stop          Stop the PostgreSQL container
    --start         Start the PostgreSQL container  
    --status        Show container status
    --help          Show help message

EXAMPLES:
    ./scripts/setup-postgres.sh --dry-run    # Preview setup
    ./scripts/setup-postgres.sh              # Setup and start
    ./scripts/setup-postgres.sh --status     # Check status
    ./scripts/setup-postgres.sh --stop       # Stop container
```

**Configuration:**
Edit these constants at the top of the script if needed:
```bash
CONTAINER_NAME="copilot-cli-postgres"
POSTGRES_VERSION="16-alpine"
POSTGRES_PORT="5434"              # ← Change if port conflicts
POSTGRES_USER="copilot_user"
POSTGRES_DB="copilot_cli"
DATA_VOLUME="copilot-cli-pgdata"
```

**What it does:**
- Detects Fedora/KDE environment
- Checks prerequisites (Docker)
- Generates secure credentials
- Creates persistent volume
- Starts PostgreSQL container
- Waits for database to be ready

**Logs to:** `logs/postgres-setup.log`

**Creates:** `.env` file with connection credentials

**Safety features:**
- Dry-run mode for testing
- Port availability check
- Idempotent (safe to run multiple times)
- Comprehensive error handling
- Confirmation for destructive operations
- Detailed logging

### `scripts/detect-environment.sh`

**Purpose:** Detect deployment environment (local vs cloud) and configure database connection accordingly.

**Location:** [`scripts/detect-environment.sh`](../scripts/detect-environment.sh)

**Usage:**
```bash
# MUST be sourced, not executed
source scripts/detect-environment.sh

# Now you have these variables:
# - $DEPLOYMENT_ENV: "local" or "cloud"
# - $IS_CI: "true" or "false"
# - $POSTGRES_HOST: Database host
# - $POSTGRES_PORT: Database port
# - $POSTGRES_USER: Database user
# - $POSTGRES_DB: Database name
# - $DATABASE_URL: Full connection string
```

**What it does:**
- Detects GitHub Actions, GitLab CI, CircleCI, Jenkins, Travis, or generic CI
- Loads `.env` file for local environment
- Uses environment variables for cloud/CI
- Sets appropriate port (5434 local, 5432 cloud)
- Configures connection string
- Verifies database connection if psql available

**When to use:**
- Before any database operations
- In scripts that need to work in both environments
- When you need environment-aware configuration

**Example:**
```bash
#!/bin/bash
set -euo pipefail

# Load environment configuration
source scripts/detect-environment.sh

# Use the configured variables
PGPASSWORD="$POSTGRES_PASSWORD" psql \
  -h "$POSTGRES_HOST" \
  -p "$POSTGRES_PORT" \
  -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" \
  -c "SELECT version();"
```

**Safety features:**
- Read-only detection (no modifications)
- Automatic environment detection
- Validates credentials availability
- Pretty output with status indicators
- Safe to run multiple times

---

## For AI Agents

### Before Running Any Script

1. **Read the script first:**
   ```bash
   cat scripts/script-name.sh
   ```

2. **Understand what it does:**
   - Check the purpose comment
   - Review configuration variables
   - Understand side effects

3. **Run in dry-run mode:**
   ```bash
   ./scripts/script-name.sh --dry-run
   ```

4. **Explain to user:**
   - What will change
   - Why it's needed
   - What the risks are

5. **Get approval for non-read operations**

6. **Execute and verify:**
   ```bash
   ./scripts/script-name.sh
   # Check logs
   cat logs/script-name.log
   ```

### Script Selection Guide

**Need to:**
- Detect environment → `source scripts/detect-environment.sh`
- Set up local database → `scripts/setup-postgres.sh --setup`
- Check database status → `scripts/setup-postgres.sh --status`
- Start database → `scripts/setup-postgres.sh --start`
- Stop database → `scripts/setup-postgres.sh --stop`

**Cloud/CI operations:**
- Environment detected automatically in workflows
- Database provided as service container
- See [CLOUD_DEPLOYMENT.md](./CLOUD_DEPLOYMENT.md) for details

**For system operations outside this repo:**
- Create a new script first
- Get explicit approval
- Test thoroughly with `--dry-run`

---

**Related:**
- [Main README](../README.md)
- [Safety Guidelines](../SAFETY_GUIDELINES.md)
- [Database Documentation](./DATABASE.md)
- [Cloud Deployment Guide](./CLOUD_DEPLOYMENT.md)
- [AI Agent Guide](./AI_AGENT_GUIDE.md)
