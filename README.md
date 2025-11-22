# Copilot CLI Configuration

This repository maintains persistent configuration, decisions, and customizations for GitHub Copilot CLI usage.

## Purpose

This serves as the central location for:
- Copilot interaction preferences and decisions
- Custom configurations and settings
- Session context and history when working outside of specific projects
- Documentation of usage patterns and customizations
- Persistent data storage via PostgreSQL (local and cloud-compatible)

## Important: Safety First

**⚠️ This repository operates in two modes:**
- **Local:** Live production computer (Fedora 42 KDE workstation)
- **Cloud/Remote:** Ephemeral CI/CD environments (GitHub Actions)

All AI agents and human users MUST read and follow [`SAFETY_GUIDELINES.md`](./SAFETY_GUIDELINES.md) before making any changes.

## Structure

```
/projects/copilot-cli/
├── README.md                    # This file - main entry point
├── SAFETY_GUIDELINES.md         # CRITICAL: Read before any operations
├── .github/workflows/           # GitHub Actions CI/CD
│   └── validate-setup.yml      # Cloud validation workflow
├── docs/                        # Detailed documentation
│   ├── DATABASE.md             # PostgreSQL setup (local)
│   ├── CLOUD_DEPLOYMENT.md     # Cloud/remote deployment guide
│   ├── AI_AGENT_GUIDE.md       # Comprehensive AI agent guide
│   ├── SCRIPTS.md              # Available scripts reference
│   └── QUICK_REFERENCE.md      # Quick command reference
├── scripts/                     # Safe, reusable automation scripts
│   ├── setup-postgres.sh       # PostgreSQL Docker container setup
│   └── detect-environment.sh   # Environment detection utility
└── logs/                        # Operation logs (gitignored)
```

## Quick Start

### For Humans

1. **First time setup:**
   ```bash
   cd /projects/copilot-cli
   ./scripts/setup-postgres.sh --dry-run  # Preview what will happen
   ./scripts/setup-postgres.sh            # Actually set up database
   ```

2. **Daily usage:**
   ```bash
   ./scripts/setup-postgres.sh --status   # Check database status
   ./scripts/setup-postgres.sh --start    # Start if needed
   ./scripts/setup-postgres.sh --stop     # Stop when done
   ```

3. **Connection info:**
   - Check `.env` file for credentials (never commit this!)
   - Port: 5434 (non-standard to avoid conflicts)
   - Database: `copilot_cli`

### For AI Agents

**Before any operation, you MUST:**

1. Read [`SAFETY_GUIDELINES.md`](./SAFETY_GUIDELINES.md) - understand constraints
2. **Detect environment** (local vs cloud) - use `scripts/detect-environment.sh`
3. Read [`docs/AI_AGENT_GUIDE.md`](./docs/AI_AGENT_GUIDE.md) - comprehensive operational guide
4. Read [`docs/DATABASE.md`](./docs/DATABASE.md) - local database operations
5. Read [`docs/CLOUD_DEPLOYMENT.md`](./docs/CLOUD_DEPLOYMENT.md) - cloud deployment guide
6. Stay within repository scope unless explicitly authorized
7. Use scripts with `--dry-run` first, then get approval
8. Log all operations appropriately (local: `logs/`, cloud: workflow logs)

**Key constraints:**
- ❌ Never modify files outside this repository directly (local only)
- ❌ Never install/uninstall packages without permission (local only)
- ❌ Never execute destructive commands without dry-run + approval
- ❌ Never share state between local and cloud environments
- ✅ Always detect environment before operations
- ✅ Always use environment-appropriate configuration
- ✅ Always validate and handle errors gracefully
- ✅ Always provide clear explanations before actions

## Environments

### Local Development
- **OS:** Fedora 42 Linux
- **Desktop:** KDE Plasma
- **User:** luxcium
- **Tools:** Docker, git, gh CLI, curl
- **Purpose:** Daily development workstation
- **Database:** Docker container with persistent storage
- **Port:** 5434 (custom to avoid conflicts)

### Cloud/Remote (CI/CD)
- **Platform:** GitHub Actions (other platforms supported via similar patterns)
- **OS:** Ubuntu (GitHub-hosted runners)
- **Purpose:** Validation, testing, CI/CD
- **Database:** Service container (ephemeral)
- **Port:** 5432 (standard, isolated)
- **Isolation:** Complete separation from local environment

## Documentation

### Essential Reading (Start Here)
- [`SAFETY_GUIDELINES.md`](./SAFETY_GUIDELINES.md) - **READ THIS FIRST**
- [`docs/AI_AGENT_GUIDE.md`](./docs/AI_AGENT_GUIDE.md) - **Comprehensive AI agent guide**
- [`docs/QUICK_REFERENCE.md`](./docs/QUICK_REFERENCE.md) - Quick command reference

### Detailed Guides
- [`docs/DATABASE.md`](./docs/DATABASE.md) - Local PostgreSQL setup and management
- [`docs/CLOUD_DEPLOYMENT.md`](./docs/CLOUD_DEPLOYMENT.md) - Cloud/remote deployment guide
- [`docs/SCRIPTS.md`](./docs/SCRIPTS.md) - Available scripts and usage

## Support

This is a personal configuration repository. For questions about Copilot CLI itself, see the official GitHub Copilot documentation.

---

*Last updated: 2025-11-17*
