# Testing Guide

**Last Updated:** 2025-11-21  
**Purpose:** Guide for testing copilot-cli setup in both local and cloud environments

## Overview

This repository supports two testing modes:
1. **Local Testing** - Test on your workstation with Docker
2. **Cloud Testing** - Test in GitHub Actions with service containers

Both modes are fully isolated from each other.

## Prerequisites

### Local Testing
- Docker installed and running
- PostgreSQL client tools (`psql`, `pg_isready`)
- Bash shell
- Git

### Cloud Testing
- GitHub repository access
- GitHub Actions enabled
- GitHub CLI (`gh`) for manual triggers (optional)

## Local Testing

### Initial Setup Test

```bash
cd /home/runner/work/copilot-cli/copilot-cli

# 1. Preview setup (dry-run)
./scripts/setup-postgres.sh --dry-run

# 2. Actually run setup
./scripts/setup-postgres.sh --setup

# 3. Check status
./scripts/setup-postgres.sh --status
```

**Expected output:**
- ✓ PostgreSQL container running
- ✓ Database accepting connections
- ✓ `.env` file created with credentials
- Port 5434 in use

### Environment Detection Test

```bash
# Test environment detection
source scripts/detect-environment.sh

# Verify variables
echo "Environment: $DEPLOYMENT_ENV"  # Should be: local
echo "Is CI: $IS_CI"                  # Should be: false
echo "Port: $POSTGRES_PORT"           # Should be: 5434
echo "Host: $POSTGRES_HOST"           # Should be: localhost
```

**Expected:**
- Detection identifies local environment
- Port 5434 configured
- `.env` file loaded successfully

### Database Operations Test

```bash
# Run example query script
./scripts/example-query.sh
```

**Expected:**
- Creates `example_data` table
- Inserts sample data
- Queries data successfully
- Shows environment as "local"

### Manual Database Test

```bash
# Load credentials
source .env

# Test connection
psql "$DATABASE_URL" -c "SELECT version();"

# Create test table
psql "$DATABASE_URL" -c "
  CREATE TABLE test_local (
    id SERIAL PRIMARY KEY,
    data TEXT
  );
"

# Insert data
psql "$DATABASE_URL" -c "INSERT INTO test_local (data) VALUES ('test');"

# Query data
psql "$DATABASE_URL" -c "SELECT * FROM test_local;"

# Clean up
psql "$DATABASE_URL" -c "DROP TABLE test_local;"
```

### Cleanup Test

```bash
# Stop database
./scripts/setup-postgres.sh --stop

# Check status (should show stopped)
./scripts/setup-postgres.sh --status

# Restart
./scripts/setup-postgres.sh --start

# Verify data persists
source .env
psql "$DATABASE_URL" -c "SELECT COUNT(*) FROM example_data;"
```

## Cloud Testing

### Manual Workflow Trigger

```bash
# Using GitHub CLI
gh workflow run validate-setup.yml

# Check status
gh run list --workflow=validate-setup.yml --limit 5

# View latest run
gh run view --log
```

**Or via GitHub UI:**
1. Navigate to repository on GitHub
2. Click "Actions" tab
3. Select "Validate Cloud Setup" workflow
4. Click "Run workflow" button
5. Click "Run workflow" to confirm

### What the Workflow Tests

The `validate-setup.yml` workflow performs:

1. **Cloud Setup Validation**
   - Starts PostgreSQL service container
   - Verifies database connectivity
   - Creates test table
   - Inserts and queries data
   - Confirms port 5432 (standard)

2. **Documentation Validation**
   - Checks all required files exist
   - Validates markdown structure
   - Ensures AI agent sections present

3. **Isolation Validation**
   - Verifies no hardcoded local paths
   - Checks `.gitignore` configuration
   - Ensures no committed secrets

4. **Summary Report**
   - Aggregates all validation results
   - Reports overall pass/fail

### Expected Workflow Results

All jobs should pass with:
- ✅ PostgreSQL service healthy
- ✅ Database operations successful
- ✅ Documentation complete
- ✅ Isolation verified
- Total runtime: ~2 minutes

### Viewing Workflow Results

```bash
# List recent runs
gh run list --workflow=validate-setup.yml

# Get details of specific run
gh run view <run-id>

# View logs
gh run view <run-id> --log

# View in browser
gh run view <run-id> --web
```

## Environment Detection Testing

### Test Local Detection

```bash
cd /home/runner/work/copilot-cli/copilot-cli

# Ensure we're in local mode (unset CI vars)
unset GITHUB_ACTIONS
unset CI

# Test detection
source scripts/detect-environment.sh

# Verify
test "$DEPLOYMENT_ENV" = "local" && echo "✓ Local detection works"
test "$POSTGRES_PORT" = "5434" && echo "✓ Correct port for local"
```

### Test Cloud Detection

```bash
cd /home/runner/work/copilot-cli/copilot-cli

# Simulate GitHub Actions
export GITHUB_ACTIONS=true
export POSTGRES_PASSWORD=test_password

# Test detection
source scripts/detect-environment.sh

# Verify
test "$DEPLOYMENT_ENV" = "cloud" && echo "✓ Cloud detection works"
test "$IS_CI" = "true" && echo "✓ CI flag set correctly"
test "$POSTGRES_PORT" = "5432" && echo "✓ Correct port for cloud"

# Clean up
unset GITHUB_ACTIONS
unset POSTGRES_PASSWORD
```

## Integration Testing

### Full Local Workflow

```bash
#!/bin/bash
set -euo pipefail

echo "=== Full Local Workflow Test ==="

# 1. Setup
echo "Step 1: Setup database..."
./scripts/setup-postgres.sh --setup

# 2. Verify running
echo "Step 2: Verify status..."
./scripts/setup-postgres.sh --status | grep "Running"

# 3. Test queries
echo "Step 3: Test database operations..."
./scripts/example-query.sh

# 4. Stop
echo "Step 4: Stop database..."
./scripts/setup-postgres.sh --stop

# 5. Restart
echo "Step 5: Restart database..."
./scripts/setup-postgres.sh --start

# 6. Verify data persists
echo "Step 6: Verify data persistence..."
source .env
COUNT=$(psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM example_data;")
if [ "$COUNT" -gt 0 ]; then
    echo "✓ Data persisted across restart"
else
    echo "✗ Data not persisted"
    exit 1
fi

echo "=== All tests passed! ==="
```

### Full Cloud Workflow

Handled automatically by `.github/workflows/validate-setup.yml`:

```bash
# Trigger the workflow
gh workflow run validate-setup.yml

# Wait for completion
sleep 60

# Check results
gh run list --workflow=validate-setup.yml --limit 1
```

## Troubleshooting Tests

### Local: Database Won't Start

```bash
# Check Docker is running
docker info

# Check port availability
ss -tuln | grep 5434

# Check logs
docker logs copilot-cli-postgres
cat logs/postgres-setup.log

# Nuclear option: reset everything
docker stop copilot-cli-postgres
docker rm copilot-cli-postgres
docker volume rm copilot-cli-pgdata
rm .env
./scripts/setup-postgres.sh --setup
```

### Local: Can't Connect

```bash
# Verify container is running
docker ps | grep copilot-cli-postgres

# Check database is ready
docker exec copilot-cli-postgres pg_isready -U copilot_user

# Check credentials
cat .env | grep POSTGRES_PASSWORD

# Test connection
source .env
psql "$DATABASE_URL" -c "SELECT 1;"
```

### Cloud: Workflow Fails

```bash
# View detailed logs
gh run view --log

# Common issues:
# 1. Service not ready - add health checks
# 2. Wrong port - use 5432 not 5434
# 3. Missing env vars - check workflow file
# 4. YAML syntax - validate with yamllint
```

### Environment Detection Fails

```bash
# Check what's being detected
bash -x scripts/detect-environment.sh 2>&1 | grep "Detected:"

# For local:
# Should see: "Detected: Local development environment"

# For cloud (simulated):
export GITHUB_ACTIONS=true
bash -x scripts/detect-environment.sh 2>&1 | grep "Detected:"
# Should see: "Detected: GitHub Actions environment"
```

## Test Checklist

### Before Each Release

- [ ] Local setup works from scratch
- [ ] Local database operations succeed
- [ ] Local data persists across restarts
- [ ] Environment detection identifies local correctly
- [ ] Cloud workflow passes all jobs
- [ ] Cloud database operations succeed
- [ ] Environment detection identifies cloud correctly
- [ ] Documentation is up to date
- [ ] No secrets in repository
- [ ] `.gitignore` properly configured
- [ ] Scripts are executable
- [ ] Example scripts work in both environments

### After Configuration Changes

- [ ] Test in local environment
- [ ] Test in cloud environment
- [ ] Verify isolation maintained
- [ ] Check documentation updated
- [ ] Validate workflow syntax
- [ ] Run full test suite

## Automated Testing

### Local Test Script

Create `/tmp/test-local.sh`:

```bash
#!/bin/bash
set -euo pipefail

cd /home/runner/work/copilot-cli/copilot-cli

echo "Testing local environment..."

# Setup
./scripts/setup-postgres.sh --setup > /dev/null 2>&1

# Test detection
source scripts/detect-environment.sh > /dev/null 2>&1
test "$DEPLOYMENT_ENV" = "local" || exit 1

# Test operations
./scripts/example-query.sh > /dev/null 2>&1

echo "✓ Local tests passed"
```

### Cloud Test Script

Already implemented in `.github/workflows/validate-setup.yml`

### Continuous Testing

For continuous validation:

```yaml
# Add to .github/workflows/validate-setup.yml
on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly on Sunday
```

**Note:** This adds cost. Only enable if needed.

## Performance Testing

### Local Performance

```bash
# Time database operations
time psql "$DATABASE_URL" -c "
  INSERT INTO example_data (environment, message)
  SELECT 'local', 'bulk_' || i
  FROM generate_series(1, 1000) AS i;
"

# Check database size
docker exec copilot-cli-postgres psql -U copilot_user -d copilot_cli -c "
  SELECT pg_size_pretty(pg_database_size('copilot_cli'));
"
```

### Cloud Performance

Monitor workflow execution time:
```bash
gh run list --workflow=validate-setup.yml --limit 10 | grep "completed"
```

## Test Data Cleanup

### Local Cleanup

```bash
# Remove test tables
source .env
psql "$DATABASE_URL" -c "DROP TABLE IF EXISTS example_data;"
psql "$DATABASE_URL" -c "DROP TABLE IF EXISTS test_local;"

# Full reset (⚠️ deletes all data)
docker stop copilot-cli-postgres
docker rm copilot-cli-postgres
docker volume rm copilot-cli-pgdata
rm .env
```

### Cloud Cleanup

Automatic - data is ephemeral and destroyed after each workflow run.

## Related Documentation

- [README.md](../README.md) - Main overview
- [CLOUD_DEPLOYMENT.md](./CLOUD_DEPLOYMENT.md) - Cloud deployment guide
- [AI_AGENT_GUIDE.md](./AI_AGENT_GUIDE.md) - AI agent operations
- [DATABASE.md](./DATABASE.md) - Local database setup
- [SCRIPTS.md](./SCRIPTS.md) - Available scripts

---

**Remember:** Always test in both environments to ensure true isolation and compatibility!
