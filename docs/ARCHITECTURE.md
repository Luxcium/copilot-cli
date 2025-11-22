# Architecture Overview

**Last Updated:** 2025-11-21  
**Purpose:** Explain the architecture of copilot-cli in both local and cloud environments

## System Architecture

### Dual Environment Design

The copilot-cli repository is designed to operate in two completely isolated environments:

```
┌─────────────────────────────────────────────────────────────────┐
│                     COPILOT-CLI REPOSITORY                      │
│                                                                 │
│  ┌────────────────────┐              ┌────────────────────┐   │
│  │  Local Environment │              │ Cloud Environment   │   │
│  │   (Workstation)    │              │ (GitHub Actions)    │   │
│  └────────────────────┘              └────────────────────┘   │
│           │                                     │               │
│           │                                     │               │
│           ▼                                     ▼               │
│  ┌────────────────────┐              ┌────────────────────┐   │
│  │  Environment       │              │  Environment        │   │
│  │  Detection         │              │  Detection          │   │
│  │  (detect-env.sh)   │              │  (detect-env.sh)    │   │
│  └────────────────────┘              └────────────────────┘   │
│           │                                     │               │
│           ▼                                     ▼               │
│  ┌────────────────────┐              ┌────────────────────┐   │
│  │  Docker Container  │              │ Service Container   │   │
│  │  Port: 5434        │              │ Port: 5432          │   │
│  │  Persistent Data   │              │ Ephemeral Data      │   │
│  └────────────────────┘              └────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Local Environment Architecture

### Components

```
┌──────────────────────────────────────────────────────────┐
│                   Fedora 42 Workstation                  │
│                                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │              User (luxcium)                     │    │
│  │  - KDE Plasma Desktop                          │    │
│  │  - Docker Desktop                              │    │
│  │  - psql client                                 │    │
│  └──────────────────┬─────────────────────────────┘    │
│                     │                                    │
│                     ▼                                    │
│  ┌─────────────────────────────────────────────────┐   │
│  │         /projects/copilot-cli/                  │   │
│  │  ┌──────────────────────────────────────────┐  │   │
│  │  │  Scripts                                  │  │   │
│  │  │  - setup-postgres.sh                     │  │   │
│  │  │  - detect-environment.sh                 │  │   │
│  │  │  - example-query.sh                      │  │   │
│  │  └──────────────────────────────────────────┘  │   │
│  │  ┌──────────────────────────────────────────┐  │   │
│  │  │  Configuration                            │  │   │
│  │  │  - .env (gitignored)                     │  │   │
│  │  │  - servers.json                          │  │   │
│  │  └──────────────────────────────────────────┘  │   │
│  │  ┌──────────────────────────────────────────┐  │   │
│  │  │  Documentation                            │  │   │
│  │  │  - README.md                             │  │   │
│  │  │  - docs/*.md                             │  │   │
│  │  └──────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────┘   │
│                     │                                    │
│                     ▼                                    │
│  ┌─────────────────────────────────────────────────┐   │
│  │         Docker Engine                           │   │
│  │  ┌──────────────────────────────────────────┐  │   │
│  │  │  copilot-cli-postgres                    │  │   │
│  │  │  - Image: postgres:16-alpine             │  │   │
│  │  │  - Port: 5434:5432                       │  │   │
│  │  │  - Volume: copilot-cli-pgdata            │  │   │
│  │  │  - Restart: unless-stopped               │  │   │
│  │  └──────────────────────────────────────────┘  │   │
│  │  ┌──────────────────────────────────────────┐  │   │
│  │  │  copilot-cli-pgadmin (optional)          │  │   │
│  │  │  - Image: dpage/pgadmin4:latest          │  │   │
│  │  │  - Port: 5435:80                         │  │   │
│  │  │  - Volume: copilot-cli-pgadmin           │  │   │
│  │  └──────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────┘   │
│                     │                                    │
│                     ▼                                    │
│  ┌─────────────────────────────────────────────────┐   │
│  │         Docker Volumes (Persistent)             │   │
│  │  - copilot-cli-pgdata (database files)         │   │
│  │  - copilot-cli-pgadmin (web UI config)         │   │
│  └─────────────────────────────────────────────────┘   │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

### Data Flow (Local)

1. User executes script → `./scripts/setup-postgres.sh`
2. Script detects local environment
3. Script creates/starts Docker container
4. Container runs PostgreSQL on port 5434
5. Data stored in Docker volume (persistent)
6. User connects via psql or application

### Characteristics

- **Persistent:** Data survives restarts
- **Port 5434:** Avoids conflicts with system PostgreSQL
- **Credentials:** Stored in `.env` file (gitignored)
- **Access:** Direct localhost connection
- **Management:** Manual via scripts

## Cloud Environment Architecture

### Components

```
┌──────────────────────────────────────────────────────────┐
│              GitHub Actions (Ubuntu Runner)              │
│                                                          │
│  ┌─────────────────────────────────────────────────┐   │
│  │         Workflow: validate-setup.yml            │   │
│  │  ┌──────────────────────────────────────────┐  │   │
│  │  │  Triggers:                               │  │   │
│  │  │  - workflow_dispatch (manual)            │  │   │
│  │  │  - pull_request (paths filtered)         │  │   │
│  │  │  - push to main (paths filtered)         │  │   │
│  │  └──────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────┘   │
│                     │                                    │
│                     ▼                                    │
│  ┌─────────────────────────────────────────────────┐   │
│  │         Repository Checkout                     │   │
│  │  - Code only (no .env)                         │   │
│  │  - Scripts available                           │   │
│  │  - Documentation available                     │   │
│  └─────────────────────────────────────────────────┘   │
│                     │                                    │
│                     ▼                                    │
│  ┌─────────────────────────────────────────────────┐   │
│  │         Service Container                       │   │
│  │  ┌──────────────────────────────────────────┐  │   │
│  │  │  postgres:16-alpine                      │  │   │
│  │  │  - Port: 5432:5432                       │  │   │
│  │  │  - Env: POSTGRES_USER=copilot_user       │  │   │
│  │  │  - Env: POSTGRES_PASSWORD=test_pw        │  │   │
│  │  │  - Env: POSTGRES_DB=copilot_cli          │  │   │
│  │  │  - Health check: pg_isready              │  │   │
│  │  └──────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────┘   │
│                     │                                    │
│                     ▼                                    │
│  ┌─────────────────────────────────────────────────┐   │
│  │         Workflow Jobs                           │   │
│  │  1. validate-cloud-setup                       │   │
│  │     - Test database connection                 │   │
│  │     - Create tables                            │   │
│  │     - Insert/query data                        │   │
│  │  2. validate-documentation                     │   │
│  │     - Check markdown files                     │   │
│  │     - Verify AI agent sections                 │   │
│  │  3. validate-isolation                         │   │
│  │     - Check no local paths                     │   │
│  │     - Verify .gitignore                        │   │
│  │  4. validation-summary                         │   │
│  │     - Aggregate results                        │   │
│  └─────────────────────────────────────────────────┘   │
│                     │                                    │
│                     ▼                                    │
│  ┌─────────────────────────────────────────────────┐   │
│  │         Results & Logs                          │   │
│  │  - Workflow logs                               │   │
│  │  - Job annotations                             │   │
│  │  - Pass/fail status                            │   │
│  └─────────────────────────────────────────────────┘   │
│                                                          │
│  ⚠️  Data destroyed when workflow completes             │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

### Data Flow (Cloud)

1. Workflow triggered (manual or auto)
2. GitHub Actions provisions Ubuntu runner
3. Service container starts with PostgreSQL
4. Repository checked out (code only)
5. Jobs execute tests and validations
6. Results logged to GitHub Actions
7. Workflow completes, all data destroyed

### Characteristics

- **Ephemeral:** Data destroyed after workflow
- **Port 5432:** Standard PostgreSQL port (isolated)
- **Credentials:** Environment variables in workflow
- **Access:** Service container networking
- **Management:** Automatic by GitHub Actions

## Environment Detection

### Detection Logic

```
┌─────────────────────────────────────────────────────┐
│          scripts/detect-environment.sh              │
│                                                     │
│  ┌───────────────────────────────────────────┐    │
│  │  Check Environment Variables              │    │
│  │  - GITHUB_ACTIONS                         │    │
│  │  - GITLAB_CI                              │    │
│  │  - CIRCLECI                               │    │
│  │  - CI (generic)                           │    │
│  └───────────────┬───────────────────────────┘    │
│                  │                                  │
│          ┌───────┴────────┐                        │
│          │                 │                        │
│          ▼                 ▼                        │
│    ┌─────────┐      ┌─────────┐                   │
│    │  Cloud  │      │  Local  │                    │
│    └────┬────┘      └────┬────┘                   │
│         │                 │                         │
│         ▼                 ▼                         │
│  ┌──────────────┐  ┌──────────────┐               │
│  │ Port: 5432   │  │ Port: 5434   │               │
│  │ Env vars     │  │ .env file    │               │
│  │ Ephemeral    │  │ Persistent   │               │
│  └──────────────┘  └──────────────┘               │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### Configuration Matrix

| Aspect | Local | Cloud |
|--------|-------|-------|
| Detection | `GITHUB_ACTIONS` unset | `GITHUB_ACTIONS=true` |
| Port | 5434 | 5432 |
| Host | localhost | localhost |
| Credentials | `.env` file | Environment variables |
| Database | Docker container | Service container |
| Data | Persistent volume | Ephemeral |
| Setup | Manual (scripts) | Automatic (workflow) |
| Logs | `logs/` directory | Workflow logs |

## Isolation Strategy

### Key Isolation Principles

1. **No Shared Configuration**
   - Local uses `.env` file (gitignored)
   - Cloud uses environment variables
   - No configuration file committed

2. **Different Ports**
   - Local: 5434 (avoid conflicts)
   - Cloud: 5432 (isolated namespace)

3. **Separate Data Storage**
   - Local: Docker volume (persistent)
   - Cloud: Container filesystem (ephemeral)

4. **Environment Detection**
   - Automatic detection via environment variables
   - Scripts adapt behavior accordingly

### Isolation Diagram

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  ┌─────────────────────┐    ┌─────────────────────┐   │
│  │  Local Environment  │    │  Cloud Environment  │   │
│  │                     │    │                     │   │
│  │  - .env file        │    │  - Env variables    │   │
│  │  - Port 5434        │    │  - Port 5432        │   │
│  │  - Docker volume    │    │  - Container FS     │   │
│  │  - logs/ dir        │    │  - Workflow logs    │   │
│  └─────────────────────┘    └─────────────────────┘   │
│           │                           │                 │
│           │   NO DATA SHARING         │                 │
│           │   NO CONFIG SHARING       │                 │
│           │   NO PORT CONFLICTS       │                 │
│           │                           │                 │
│           ▼                           ▼                 │
│  ┌─────────────────────┐    ┌─────────────────────┐   │
│  │  Persistent Data    │    │  Ephemeral Data     │   │
│  │  (survives)         │    │  (destroyed)        │   │
│  └─────────────────────┘    └─────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Cost Optimization

### GitHub Actions Strategy

```
┌─────────────────────────────────────────────────────────┐
│           GitHub Actions Cost Strategy                  │
│                                                         │
│  1. Trigger Optimization                               │
│     ┌───────────────────────────────────────────────┐ │
│     │ workflow_dispatch (manual) ← DEFAULT          │ │
│     │ - No automatic runs                           │ │
│     │ - User controls when to run                   │ │
│     │ - Zero cost unless triggered                  │ │
│     └───────────────────────────────────────────────┘ │
│                                                         │
│  2. Path Filtering                                     │
│     ┌───────────────────────────────────────────────┐ │
│     │ on:                                           │ │
│     │   pull_request:                               │ │
│     │     paths:                                    │ │
│     │       - 'scripts/**'  ← Only relevant files  │ │
│     │       - 'docs/**'                             │ │
│     └───────────────────────────────────────────────┘ │
│                                                         │
│  3. Concurrency Control                                │
│     ┌───────────────────────────────────────────────┐ │
│     │ concurrency:                                  │ │
│     │   cancel-in-progress: true                    │ │
│     │ - Stops redundant runs                        │ │
│     │ - Saves minutes                               │ │
│     └───────────────────────────────────────────────┘ │
│                                                         │
│  4. Minimal Job Strategy                               │
│     ┌───────────────────────────────────────────────┐ │
│     │ - No build matrix (single config)            │ │
│     │ - Fast jobs (~2 min total)                   │ │
│     │ - ubuntu-latest (cheapest)                   │ │
│     └───────────────────────────────────────────────┘ │
│                                                         │
│  Estimated Cost:                                       │
│  - ~$0.008 per run                                    │
│  - Well within free tier (2000 min/month)            │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Security Architecture

### Security Layers

1. **Credential Management**
   - Local: `.env` file (chmod 600, gitignored)
   - Cloud: Environment variables (not logged)
   - Never committed: Password patterns checked

2. **Access Control**
   - Local: User's workstation permissions
   - Cloud: GitHub Actions isolation
   - Network: localhost only (both environments)

3. **Data Protection**
   - Local: Docker volume with user permissions
   - Cloud: Ephemeral (destroyed automatically)
   - Backups: Manual, not automatic

### Security Diagram

```
┌─────────────────────────────────────────────────────────┐
│               Security Architecture                     │
│                                                         │
│  ┌─────────────────────┐    ┌─────────────────────┐   │
│  │  Local Security     │    │  Cloud Security     │   │
│  │                     │    │                     │   │
│  │  ✓ .env gitignored  │    │  ✓ Env vars only    │   │
│  │  ✓ chmod 600        │    │  ✓ No file storage  │   │
│  │  ✓ Random 25-char   │    │  ✓ Ephemeral data   │   │
│  │  ✓ User-only access │    │  ✓ Isolated runner  │   │
│  └─────────────────────┘    └─────────────────────┘   │
│           │                           │                 │
│           ▼                           ▼                 │
│  ┌─────────────────────────────────────────────────┐  │
│  │         Common Security Measures                │  │
│  │  - No secrets in repository                     │  │
│  │  - Localhost-only access                        │  │
│  │  - Regular security scans                       │  │
│  │  - Documented security practices                │  │
│  └─────────────────────────────────────────────────┘  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Scalability Considerations

### Current Design

- ✅ Works for single user (local)
- ✅ Works for CI/CD (cloud)
- ✅ Fully documented
- ✅ Environment-aware scripts

### Future Scalability

If multi-user or production deployment needed:

1. **Authentication Enhancement**
   - Implement proper user management
   - Add connection pooling
   - Consider SSL/TLS

2. **High Availability**
   - Primary/replica setup
   - Load balancing
   - Automated failover

3. **Cloud Database Services**
   - AWS RDS
   - Google Cloud SQL
   - Azure Database for PostgreSQL

4. **Monitoring & Observability**
   - Metrics collection
   - Log aggregation
   - Alerting

## Related Documentation

- [README.md](../README.md) - Main overview
- [CLOUD_DEPLOYMENT.md](./CLOUD_DEPLOYMENT.md) - Cloud deployment details
- [AI_AGENT_GUIDE.md](./AI_AGENT_GUIDE.md) - AI agent operations
- [DATABASE.md](./DATABASE.md) - Local database setup
- [TESTING.md](./TESTING.md) - Testing guide
- [SAFETY_GUIDELINES.md](../SAFETY_GUIDELINES.md) - Safety rules

---

**Key Principle:** Complete isolation between local and cloud environments ensures safety, predictability, and maintainability.
