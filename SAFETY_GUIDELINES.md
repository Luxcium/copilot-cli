# Safety Guidelines for Copilot CLI Usage

**CRITICAL: This is a live production computer. All changes must be safe, reversible, and contained.**

## Core Principles

### 1. Repository Scope
- **ALL modifications stay within `/projects/copilot-cli/` unless explicitly approved**
- Never modify files outside this repository directly
- Use scripts for any system-wide operations

### 2. Script-Based Approach
- All system interactions must use scripts stored in `scripts/`
- Scripts must be:
  - **Safe**: Check preconditions, validate inputs
  - **Reliable**: Handle errors gracefully
  - **Resilient**: Support dry-run mode, provide rollback capability
  - **Idempotent**: Can be run multiple times safely
  - **Well-documented**: Clear purpose and usage instructions

### 3. Script Requirements
```bash
# Every script should include:
# - Shebang line
# - Description and usage
# - Dry-run mode (--dry-run flag)
# - Input validation
# - Error handling with meaningful messages
# - Exit codes (0 = success, non-zero = failure)
# - Confirmation prompts for destructive operations
```

### 4. Before Any System Change
1. Create and review the script first
2. Run in dry-run mode
3. Get explicit user approval
4. Execute with logging
5. Verify results

### 5. Never Do
- ❌ Delete files outside this repository
- ❌ Modify system configurations without a script
- ❌ Install/uninstall packages without explicit permission
- ❌ Change file permissions outside this repository
- ❌ Modify environment variables system-wide
- ❌ Execute untested commands with sudo

### 6. Always Do
- ✅ Ask before making changes outside this repository
- ✅ Use scripts with dry-run capability
- ✅ Provide clear explanations of what will change
- ✅ Keep backups and rollback plans
- ✅ Log all operations
- ✅ Test in dry-run mode first

## Emergency Stop
If anything goes wrong, user can:
- Press Ctrl+C to stop running operations
- Review `logs/` directory for what was changed
- Use rollback scripts if available

---

**Remember: This is a real production system. Caution and precision are paramount.**

*Established: 2025-11-17*
