# GitHub Actions Workflows

This directory contains GitHub Actions workflows for CI/CD operations in the cloud.

## Overview

All workflows are designed to be:
- ✅ **Cost-optimized**: Manual triggers by default, no automatic runs
- ✅ **Isolated**: Complete separation from local environment
- ✅ **Resilient**: Health checks, error handling, retry logic
- ✅ **Well-documented**: Clear purpose and usage instructions
- ✅ **Polyvalent**: Work with different configurations and contexts

## Available Workflows

### `validate-setup.yml`

**Purpose:** Validate that the repository setup works correctly in cloud environments.

**Trigger:** Manual (`workflow_dispatch`) or specific file changes

**What it does:**
1. **Cloud Setup Validation**
   - Spins up PostgreSQL service container
   - Tests database operations (create, insert, query)
   - Verifies database connectivity and readiness

2. **Documentation Validation**
   - Checks all required documentation files exist
   - Validates markdown structure
   - Ensures AI agent instructions are present

3. **Isolation Validation**
   - Verifies no local paths in configurations
   - Checks `.gitignore` properly configured
   - Ensures no secrets committed

4. **Summary Report**
   - Aggregates all validation results
   - Provides clear pass/fail status

**Cost:** ~$0.008 per run (~2 minutes on ubuntu-latest)

**Manual Trigger:**
```bash
# Via GitHub CLI
gh workflow run validate-setup.yml

# Via GitHub UI
# Navigate to: Actions → Validate Cloud Setup → Run workflow
```

**Automatic Triggers:**
- Pull requests that modify `scripts/`, `docs/`, or `.github/workflows/`
- Pushes to `main` branch that modify `scripts/` or `.github/workflows/`

## Cost Optimization Strategy

### Current Approach
1. **Manual trigger only by default** - No cost for regular commits
2. **Path filtering** - Only runs when relevant files change
3. **Concurrency control** - Cancels redundant runs
4. **Single job strategy** - No matrix builds unless necessary
5. **No caching overhead** - Minimal dependencies to cache

### Monthly Cost Estimate
**Free tier allowance:**
- Free accounts: 2,000 minutes/month
- Pro accounts: 3,000 minutes/month

**This workflow:**
- ~2 minutes per run
- ~50 runs/month (generous estimate) = 100 minutes
- **Well within free tier**

**If exceeded:** ~$0.008/minute × excess minutes

## Environment Isolation

### Key Differences from Local

| Aspect | Local | Cloud (GitHub Actions) |
|--------|-------|------------------------|
| Environment | Fedora 42 workstation | Ubuntu (GitHub runners) |
| Database | Docker container | Service container |
| Port | 5434 | 5432 |
| Credentials | `.env` file | Environment variables |
| Data | Persistent | Ephemeral |
| Logs | `logs/` directory | Workflow logs |

### Isolation Guarantees

✅ **What's isolated:**
- No access to local `.env` file
- No access to local Docker containers
- No access to local file system beyond repo
- No access to local user data
- Completely separate database instance

✅ **What's shared:**
- Repository code only (via `actions/checkout`)
- Nothing else

## Adding New Workflows

### Best Practices

1. **Cost-aware design:**
   ```yaml
   on:
     workflow_dispatch:  # Manual trigger = no cost
     pull_request:
       paths:           # Only run when relevant
         - 'specific/path/**'
   ```

2. **Concurrency control:**
   ```yaml
   concurrency:
     group: ${{ github.workflow }}-${{ github.ref }}
     cancel-in-progress: true
   ```

3. **Clear job names:**
   ```yaml
   jobs:
     descriptive-job-name:
       name: What This Job Does
   ```

4. **Health checks for services:**
   ```yaml
   services:
     postgres:
       options: >-
         --health-cmd pg_isready
         --health-interval 10s
   ```

5. **Fail fast:**
   ```yaml
   strategy:
     fail-fast: true  # Stop on first failure
   ```

### Workflow Template

```yaml
name: Your Workflow Name

on:
  workflow_dispatch:  # Manual trigger

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  your-job:
    name: Descriptive Job Name
    runs-on: ubuntu-latest
    
    # Use service containers if needed
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_USER: copilot_user
          POSTGRES_PASSWORD: test_password
          POSTGRES_DB: copilot_cli
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432
    
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      
      - name: Your step
        run: |
          echo "Do something"
```

## Troubleshooting

### Workflow Not Running

**Check:**
1. Is it manually triggered? Use `gh workflow run` or GitHub UI
2. Are path filters excluding your changes?
3. Is concurrency canceling the run?

### Database Connection Issues

**Common causes:**
```yaml
# Problem: Wrong port
psql -h localhost -p 5434  # ❌ Use 5432 in cloud

# Solution: Use standard port
psql -h localhost -p 5432  # ✅
```

**Health check not ready:**
```yaml
# Add explicit wait
- name: Wait for database
  run: |
    until pg_isready -h localhost -U copilot_user; do
      sleep 1
    done
```

### Workflow Failing

1. **Check logs:**
   ```bash
   gh run list --workflow=validate-setup.yml
   gh run view <run-id> --log
   ```

2. **Common issues:**
   - Missing environment variables
   - Wrong port configuration
   - Path issues (use relative paths)
   - Service not ready (add health checks)

### Cost Concerns

**Monitor usage:**
```bash
# Via GitHub CLI
gh api /user/settings/billing/actions

# Via GitHub UI
# Settings → Billing → Actions
```

**Reduce costs:**
1. Use `workflow_dispatch` (manual) more
2. Increase path filtering
3. Reduce test matrix size
4. Optimize job duration
5. Use caching effectively

## Monitoring

### Check Workflow Status

```bash
# List recent runs
gh run list --workflow=validate-setup.yml --limit 10

# View specific run
gh run view <run-id>

# View logs
gh run view <run-id> --log

# Watch in real-time
gh run watch <run-id>
```

### Success Metrics

- ✅ All jobs complete successfully
- ✅ Database operations work in cloud
- ✅ Documentation validates correctly
- ✅ No isolation breaches detected
- ✅ Total runtime < 3 minutes

## For AI Agents

### Before Modifying Workflows

1. **Understand cost implications:**
   - Every run costs GitHub Actions minutes
   - Free tier is limited
   - Optimize trigger conditions

2. **Test locally first:**
   ```bash
   # Use act to test workflows locally
   act -W .github/workflows/validate-setup.yml
   ```

3. **Use manual triggers:**
   - Always include `workflow_dispatch`
   - Don't auto-trigger on every commit

4. **Verify isolation:**
   - No local file access
   - No local credentials
   - Environment variables only

### Running Workflows

```bash
# Trigger manually
gh workflow run validate-setup.yml

# Check status
gh run list --workflow=validate-setup.yml

# View results
gh run view --log
```

### Adding Validation

```yaml
- name: Your validation
  run: |
    # Test something
    if [ condition ]; then
      echo "✓ Validation passed"
    else
      echo "✗ Validation failed"
      exit 1
    fi
```

## Security Considerations

### Secrets Management

**Don't:**
- ❌ Hardcode passwords in workflows
- ❌ Echo secrets to logs
- ❌ Commit secrets to repository

**Do:**
- ✅ Use GitHub Secrets for sensitive data
- ✅ Use environment variables
- ✅ Mask outputs with `::add-mask::`

**Example:**
```yaml
env:
  POSTGRES_PASSWORD: ${{ secrets.DB_PASSWORD }}  # ✅ Good

# Not:
env:
  POSTGRES_PASSWORD: hardcoded_password  # ❌ Bad
```

### Resource Access

Workflows have access to:
- ✅ Repository code (via checkout)
- ✅ GitHub Actions environment
- ✅ Configured secrets

Workflows do NOT have access to:
- ❌ Your local machine
- ❌ Local `.env` files
- ❌ Local Docker containers
- ❌ Other repositories (unless explicitly configured)

## Future Enhancements

### Planned
- [ ] Performance benchmarking workflow
- [ ] Security scanning workflow
- [ ] Documentation link checker
- [ ] Automated dependency updates
- [ ] Multi-platform testing (if needed)

### Nice to Have
- [ ] Slack/Discord notifications
- [ ] Deployment workflows (if needed)
- [ ] Integration testing
- [ ] Load testing

## Related Documentation

- [CLOUD_DEPLOYMENT.md](../../docs/CLOUD_DEPLOYMENT.md) - Cloud deployment guide
- [AI_AGENT_GUIDE.md](../../docs/AI_AGENT_GUIDE.md) - AI agent operations
- [SAFETY_GUIDELINES.md](../../SAFETY_GUIDELINES.md) - Safety rules
- [Main README](../../README.md) - Repository overview

---

**Remember:** Workflows are cloud-only, completely isolated from local environment!
