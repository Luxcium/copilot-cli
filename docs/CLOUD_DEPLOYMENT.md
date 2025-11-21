# Cloud & Remote Deployment Guide

**Last Updated:** 2025-11-21  
**Purpose:** Enable copilot-cli configuration to work seamlessly in both local and remote/cloud environments with proper isolation.

## Overview

This repository supports two distinct deployment modes:

1. **Local Development** - Docker-based PostgreSQL on your workstation (Fedora 42)
2. **Cloud/Remote/CI** - Ephemeral PostgreSQL in cloud environments (GitHub Actions, etc.)

**Key Principle:** Complete isolation between local and remote environments. No shared state or configuration paths.

## Deployment Modes Comparison

| Aspect | Local (Workstation) | Cloud/Remote (CI/CD) |
|--------|---------------------|----------------------|
| **Database** | Docker container with persistent volume | Service container (ephemeral) |
| **Data Persistence** | Persistent (survives restarts) | Ephemeral (destroyed after job) |
| **Port** | 5434 (custom to avoid conflicts) | 5432 (standard, isolated) |
| **Credentials** | `.env` file (gitignored) | Environment variables |
| **Access** | `localhost:5434` | `localhost:5432` or `postgres:5432` |
| **Setup Script** | `./scripts/setup-postgres.sh` | GitHub Actions service |
| **Use Case** | Daily development, testing | Validation, testing, CI/CD |
| **Cost** | Local resources only | Cloud compute time |

## GitHub Actions Setup

### Basic Configuration

The repository includes a workflow at `.github/workflows/validate-setup.yml` that:

- ✅ Runs only on manual trigger or specific file changes (cost-optimized)
- ✅ Uses PostgreSQL service container (fully isolated)
- ✅ Tests database operations
- ✅ Validates documentation
- ✅ Checks environment isolation
- ✅ Prevents concurrent runs (saves resources)

### How It Works

```yaml
services:
  postgres:
    image: postgres:16-alpine
    env:
      POSTGRES_USER: copilot_user
      POSTGRES_PASSWORD: test_password_cloud_only
      POSTGRES_DB: copilot_cli
    options: >-
      --health-cmd pg_isready
      --health-interval 10s
      --health-timeout 5s
      --health-retries 5
    ports:
      - 5432:5432
```

**Key Features:**
- **Ephemeral:** Database exists only during workflow run
- **Isolated:** No access to local machine data
- **Automatic cleanup:** Destroyed when workflow completes
- **Health checks:** Ensures database is ready before tests

### Manual Trigger

To run validation in GitHub Actions:

```bash
# Via GitHub CLI
gh workflow run validate-setup.yml

# Or via GitHub UI
# Navigate to: Actions → Validate Cloud Setup → Run workflow
```

### Cost Optimization Strategies

1. **Manual Triggers Only (Default)**
   - Workflow runs only when explicitly triggered
   - No automatic costs from every commit

2. **Path Filtering**
   ```yaml
   on:
     pull_request:
       paths:
         - 'scripts/**'
         - 'docs/**'
   ```
   - Only runs when relevant files change

3. **Concurrency Control**
   ```yaml
   concurrency:
     group: ${{ github.workflow }}-${{ github.ref }}
     cancel-in-progress: true
   ```
   - Cancels redundant runs

4. **Single Job Matrix** (if needed in future)
   ```yaml
   strategy:
     matrix:
       postgres: [16-alpine]  # Only one version
   ```

5. **Cache Dependencies** (when applicable)
   - Use `actions/cache` for repeated dependencies
   - Currently not needed (no dependencies)

**Estimated Cost:** ~$0.008 per workflow run (2 minutes on `ubuntu-latest`)

## Environment Detection

Scripts can detect their environment:

```bash
#!/bin/bash

# Detect if running in GitHub Actions
if [ -n "${GITHUB_ACTIONS}" ]; then
  echo "Running in GitHub Actions"
  POSTGRES_HOST="localhost"
  POSTGRES_PORT="5432"
  DATABASE_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@localhost:5432/${POSTGRES_DB}"
else
  echo "Running locally"
  POSTGRES_HOST="localhost"
  POSTGRES_PORT="5434"
  # Load from .env file
  source .env
fi
```

## Cloud Platform Support

### GitHub Actions (Implemented)

**Status:** ✅ Fully Supported

**Features:**
- Service containers for PostgreSQL
- Ephemeral, isolated environments
- Cost-optimized with manual triggers
- Automatic cleanup

**Access Pattern:**
```bash
# In GitHub Actions workflow
PGPASSWORD=${{ env.POSTGRES_PASSWORD }} psql -h localhost -U copilot_user -d copilot_cli
```

### Other Platforms (Future Support)

#### GitLab CI
**Status:** 📋 Planned

```yaml
services:
  - postgres:16-alpine

variables:
  POSTGRES_DB: copilot_cli
  POSTGRES_USER: copilot_user
  POSTGRES_PASSWORD: gitlab_test_pw
```

#### Docker Compose (Local & Remote)
**Status:** 📋 Planned

```yaml
version: '3.8'
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: copilot_user
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: copilot_cli
    volumes:
      - pgdata:/var/lib/postgresql/data
    ports:
      - "${POSTGRES_PORT:-5434}:5432"
volumes:
  pgdata:
```

#### Kubernetes
**Status:** 📋 Planned

For production deployments with persistent storage and high availability.

## Isolation Best Practices

### 1. No Shared Configuration Paths

❌ **Don't:**
```bash
# Hardcoded local paths
DB_PATH="/projects/copilot-cli/data"
```

✅ **Do:**
```bash
# Relative or environment-based paths
DB_PATH="${PROJECT_ROOT}/data"
```

### 2. Environment-Specific Credentials

❌ **Don't:**
```bash
# Committed credentials
POSTGRES_PASSWORD="hardcoded_password"
```

✅ **Do:**
```bash
# Local: .env file (gitignored)
# Cloud: Environment variables

if [ -f .env ]; then
  source .env
else
  # Use environment variables
  : ${POSTGRES_PASSWORD:?Required}
fi
```

### 3. Port Selection

| Environment | Port | Reason |
|-------------|------|--------|
| Local | 5434 | Avoid conflict with system PostgreSQL (5432) |
| Cloud/CI | 5432 | Standard port, isolated namespace |

### 4. Data Persistence

| Environment | Strategy |
|-------------|----------|
| Local | Docker volume (`copilot-cli-pgdata`) |
| Cloud/CI | Ephemeral (destroyed after use) |
| Production | Cloud-managed database or persistent volume |

## For AI Agents

### Cloud Environment Operations

**Before any cloud operation:**

1. **Detect environment:**
   ```bash
   if [ -n "${GITHUB_ACTIONS}" ]; then
     echo "In GitHub Actions"
   else
     echo "Local environment"
   fi
   ```

2. **Use appropriate connection:**
   ```bash
   # GitHub Actions
   PGPASSWORD=$POSTGRES_PASSWORD psql -h localhost -U copilot_user -d copilot_cli
   
   # Local
   source .env && psql "$DATABASE_URL"
   ```

3. **Verify isolation:**
   - Cloud operations NEVER access local `.env`
   - Local operations NEVER use CI credentials
   - No shared data paths

### Key Differences

| Operation | Local | Cloud/CI |
|-----------|-------|----------|
| Setup | `./scripts/setup-postgres.sh` | Automatic via service |
| Start | `./scripts/setup-postgres.sh --start` | N/A (auto-started) |
| Connect | Port 5434, `.env` credentials | Port 5432, env vars |
| Data | Persists in Docker volume | Ephemeral, destroyed |
| Logs | `logs/postgres-setup.log` | GitHub Actions logs |

### Safety Checks

Before cloud operations:

```bash
# Verify not modifying local environment
if [ -f .env ] && [ -n "${GITHUB_ACTIONS}" ]; then
  echo "ERROR: .env should not exist in cloud"
  exit 1
fi

# Verify credentials source
if [ -z "${GITHUB_ACTIONS}" ] && [ ! -f .env ]; then
  echo "ERROR: .env required for local operations"
  exit 1
fi
```

## Troubleshooting

### Cloud/GitHub Actions Issues

#### Connection Refused
```bash
# Check service is ready
- name: Wait for PostgreSQL
  run: |
    until pg_isready -h localhost -U copilot_user; do
      sleep 1
    done
```

#### Wrong Port
- GitHub Actions services use standard port `5432`
- Don't use `5434` in cloud environment

#### Authentication Failed
- Verify environment variables are set correctly
- Check service configuration in workflow file

### Local vs Cloud Conflicts

#### Port Already in Use (Local)
```bash
# Check what's using port 5434
ss -tuln | grep 5434

# Use different port if needed
export POSTGRES_PORT=5435
```

#### Wrong Environment Detection
```bash
# Explicitly set for testing
export GITHUB_ACTIONS=true  # Simulate cloud
unset GITHUB_ACTIONS         # Simulate local
```

## Testing Your Setup

### Local Testing
```bash
cd /home/runner/work/copilot-cli/copilot-cli

# Check status
./scripts/setup-postgres.sh --status

# Start if needed
./scripts/setup-postgres.sh --start

# Test connection
source .env && psql "$DATABASE_URL" -c "SELECT version();"
```

### Cloud Testing
```bash
# Trigger GitHub Actions workflow
gh workflow run validate-setup.yml

# Check run status
gh run list --workflow=validate-setup.yml

# View logs
gh run view --log
```

### Validation Checklist

- [ ] Local setup works independently
- [ ] Cloud setup works independently
- [ ] No shared state between environments
- [ ] Documentation is clear for both modes
- [ ] AI agents can detect and use correct environment
- [ ] Costs are minimized with manual triggers
- [ ] Security: No secrets committed
- [ ] Isolation: `.env` properly gitignored

## Migration & Backup

### Local to Cloud (Not Recommended)

Local data is **not** meant for cloud deployment. Cloud environments are ephemeral.

For testing with real data in cloud:
1. Export local data: `pg_dump > backup.sql`
2. Import in cloud: Use setup SQL in workflow
3. **Never** commit database dumps

### Cloud to Local (Not Applicable)

Cloud data is ephemeral and destroyed after workflow.

## Security Considerations

### Local Environment
- ✅ `.env` file with 600 permissions
- ✅ Gitignored configuration
- ✅ Random 25-character passwords
- ✅ Non-standard port (5434)

### Cloud Environment
- ✅ Environment variables (GitHub Secrets)
- ✅ Ephemeral credentials (destroyed after run)
- ✅ Isolated namespace
- ✅ No persistent state

### What NOT to Do
- ❌ Commit `.env` files
- ❌ Hardcode passwords in scripts
- ❌ Share credentials between environments
- ❌ Use production credentials in CI
- ❌ Commit database dumps

## Cost Analysis

### GitHub Actions Free Tier
- 2,000 minutes/month for free accounts
- 3,000 minutes/month for pro accounts
- This workflow uses ~2 minutes per run

**Example Usage:**
- 50 runs/month = 100 minutes
- Well within free tier
- Cost if exceeded: ~$0.008/minute

### Optimization Tips
1. Use `workflow_dispatch` (manual trigger) by default
2. Filter paths to only run when relevant
3. Cancel redundant runs with concurrency
4. Don't run on every commit
5. Use caching where applicable

## Future Enhancements

### Planned
- [ ] Docker Compose configuration for local development
- [ ] GitLab CI support
- [ ] Cloud database service integration (AWS RDS, etc.)
- [ ] Automated backup strategies
- [ ] Multi-environment configuration management

### Nice to Have
- [ ] Kubernetes deployment manifests
- [ ] Terraform/IaC configurations
- [ ] Monitoring and alerting
- [ ] Performance benchmarking in cloud

## Support Matrix

| Platform | Status | Notes |
|----------|--------|-------|
| Local (Docker) | ✅ Stable | Main development environment |
| GitHub Actions | ✅ Stable | CI/CD and validation |
| GitLab CI | 📋 Planned | Similar to GitHub Actions |
| Docker Compose | 📋 Planned | Simplified local setup |
| CircleCI | 📋 Planned | On demand |
| AWS/Azure/GCP | 📋 Planned | Production deployments |

---

**Related Documentation:**
- [README.md](../README.md) - Main repository overview
- [DATABASE.md](./DATABASE.md) - Local database setup
- [SCRIPTS.md](./SCRIPTS.md) - Scripts reference
- [SAFETY_GUIDELINES.md](../SAFETY_GUIDELINES.md) - Safety rules
- [QUICK_REFERENCE.md](./QUICK_REFERENCE.md) - Quick commands

**For Questions:**
- Check GitHub Actions logs for cloud issues
- Check `logs/postgres-setup.log` for local issues
- Review workflow file: `.github/workflows/validate-setup.yml`
