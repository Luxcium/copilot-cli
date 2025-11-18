# Copilot CLI Configuration

This repository maintains persistent configuration, decisions, and customizations for GitHub Copilot CLI usage.

## Purpose

This serves as the central location for:
- Copilot interaction preferences and decisions
- Custom configurations and settings
- Session context and history when working outside of specific projects
- Documentation of usage patterns and customizations
- Persistent data storage via PostgreSQL

## Important: Safety First

**⚠️ This repository operates on a live production computer (Fedora 42 KDE workstation).**

All AI agents and human users MUST read and follow [`SAFETY_GUIDELINES.md`](./SAFETY_GUIDELINES.md) before making any changes.

## Structure

```
/projects/copilot-cli/
├── README.md                    # This file - main entry point
├── SAFETY_GUIDELINES.md         # CRITICAL: Read before any operations
├── docs/                        # Detailed documentation
│   ├── DATABASE.md             # PostgreSQL setup and usage
│   └── SCRIPTS.md              # Available scripts reference
├── scripts/                     # Safe, reusable automation scripts
│   └── setup-postgres.sh       # PostgreSQL Docker container setup
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
2. Read [`docs/DATABASE.md`](./docs/DATABASE.md) - database operations
3. Read [`docs/SCRIPTS.md`](./docs/SCRIPTS.md) - available automation
4. Stay within `/projects/copilot-cli/` unless explicitly authorized
5. Use scripts with `--dry-run` first, then get approval
6. Log all operations to `logs/`

**Key constraints:**
- ❌ Never modify files outside this repository directly
- ❌ Never install/uninstall packages without permission  
- ❌ Never execute destructive commands without dry-run + approval
- ✅ Always use scripts for system interactions
- ✅ Always validate and handle errors gracefully
- ✅ Always provide clear explanations before actions

## Environment

**Target System:**
- OS: Fedora 42 Linux
- Desktop: KDE Plasma
- User: luxcium
- Tools: Docker, git, gh CLI, curl
- Purpose: Daily development workstation

## Documentation

- [`SAFETY_GUIDELINES.md`](./SAFETY_GUIDELINES.md) - **READ THIS FIRST**
- [`docs/DATABASE.md`](./docs/DATABASE.md) - PostgreSQL setup and management
- [`docs/SCRIPTS.md`](./docs/SCRIPTS.md) - Available scripts and usage

## Support

This is a personal configuration repository. For questions about Copilot CLI itself, see the official GitHub Copilot documentation.

---

*Last updated: 2025-11-17*
