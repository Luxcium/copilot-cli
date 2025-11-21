#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Environment Detection Script
# Purpose: Detect if running locally or in cloud/CI environment
# Usage: source ./scripts/detect-environment.sh
#
# Sets the following variables:
#   - DEPLOYMENT_ENV: "local" or "cloud"
#   - POSTGRES_HOST: Database host
#   - POSTGRES_PORT: Database port
#   - IS_CI: "true" or "false"
#
# AI Agent Notes:
#   - Source this script to get environment-specific configuration
#   - Always check DEPLOYMENT_ENV before operations
#   - Use appropriate connection method based on environment
###############################################################################

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Detect environment
detect_deployment_environment() {
    local env_type="local"
    local is_ci="false"
    
    # Check for GitHub Actions
    if [ -n "${GITHUB_ACTIONS:-}" ]; then
        env_type="cloud"
        is_ci="true"
        echo -e "${BLUE}ℹ${NC} Detected: GitHub Actions environment" >&2
    # Check for GitLab CI
    elif [ -n "${GITLAB_CI:-}" ]; then
        env_type="cloud"
        is_ci="true"
        echo -e "${BLUE}ℹ${NC} Detected: GitLab CI environment" >&2
    # Check for CircleCI
    elif [ -n "${CIRCLECI:-}" ]; then
        env_type="cloud"
        is_ci="true"
        echo -e "${BLUE}ℹ${NC} Detected: CircleCI environment" >&2
    # Check for Jenkins
    elif [ -n "${JENKINS_URL:-}" ]; then
        env_type="cloud"
        is_ci="true"
        echo -e "${BLUE}ℹ${NC} Detected: Jenkins environment" >&2
    # Check for Travis CI
    elif [ -n "${TRAVIS:-}" ]; then
        env_type="cloud"
        is_ci="true"
        echo -e "${BLUE}ℹ${NC} Detected: Travis CI environment" >&2
    # Check for other CI indicators
    elif [ -n "${CI:-}" ]; then
        env_type="cloud"
        is_ci="true"
        echo -e "${BLUE}ℹ${NC} Detected: Generic CI environment" >&2
    else
        echo -e "${BLUE}ℹ${NC} Detected: Local development environment" >&2
    fi
    
    echo "$env_type"
}

# Configure database connection based on environment
configure_database_connection() {
    local env_type="$1"
    
    if [ "$env_type" = "cloud" ]; then
        # Cloud/CI environment
        export POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
        export POSTGRES_PORT="${POSTGRES_PORT:-5432}"  # Standard port in CI
        export POSTGRES_USER="${POSTGRES_USER:-copilot_user}"
        export POSTGRES_DB="${POSTGRES_DB:-copilot_cli}"
        
        # Verify required variables are set
        if [ -z "${POSTGRES_PASSWORD:-}" ]; then
            echo -e "${RED}✗${NC} ERROR: POSTGRES_PASSWORD not set in cloud environment" >&2
            return 1
        fi
        
        export DATABASE_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}"
        
        echo -e "${GREEN}✓${NC} Cloud configuration loaded"
        echo "   Host: ${POSTGRES_HOST}"
        echo "   Port: ${POSTGRES_PORT}"
        echo "   Database: ${POSTGRES_DB}"
        
    else
        # Local environment
        export POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
        export POSTGRES_PORT="${POSTGRES_PORT:-5434}"  # Custom port locally
        
        # Try to load from .env file
        local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        local project_root="$(dirname "$script_dir")"
        local env_file="${project_root}/.env"
        
        if [ -f "$env_file" ]; then
            # Source .env file for local credentials
            set -a  # Export all variables
            source "$env_file"
            set +a
            
            echo -e "${GREEN}✓${NC} Local configuration loaded from .env"
            echo "   Host: ${POSTGRES_HOST}"
            echo "   Port: ${POSTGRES_PORT}"
            echo "   Database: ${POSTGRES_DB}"
        else
            echo -e "${YELLOW}⚠${NC} Warning: .env file not found at $env_file"
            echo "   Run ./scripts/setup-postgres.sh to create it"
            return 1
        fi
    fi
    
    return 0
}

# Verify database connection
verify_database_connection() {
    local env_type="$1"
    
    echo ""
    echo "Verifying database connection..."
    
    # Try to connect
    if command -v psql &> /dev/null; then
        if PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT 1;" &> /dev/null; then
            echo -e "${GREEN}✓${NC} Database connection successful"
            return 0
        else
            echo -e "${RED}✗${NC} Database connection failed"
            return 1
        fi
    elif command -v pg_isready &> /dev/null; then
        if PGPASSWORD="$POSTGRES_PASSWORD" pg_isready -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" &> /dev/null; then
            echo -e "${GREEN}✓${NC} Database is ready"
            return 0
        else
            echo -e "${RED}✗${NC} Database is not ready"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠${NC} Warning: Cannot verify connection (psql not installed)"
        return 0
    fi
}

# Print configuration summary
print_configuration_summary() {
    local env_type="$1"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Environment Configuration Summary"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Deployment Type: $env_type"
    echo "CI Environment: ${IS_CI}"
    echo ""
    echo "Database Configuration:"
    echo "  Host: ${POSTGRES_HOST}"
    echo "  Port: ${POSTGRES_PORT}"
    echo "  Database: ${POSTGRES_DB}"
    echo "  User: ${POSTGRES_USER}"
    echo "  Connection: ${DATABASE_URL//:*@/:***@}"  # Mask password in output
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Main execution when sourced
main() {
    # Detect environment
    export DEPLOYMENT_ENV=$(detect_deployment_environment)
    export IS_CI="false"
    
    if [ "$DEPLOYMENT_ENV" = "cloud" ]; then
        export IS_CI="true"
    fi
    
    # Configure connection
    if ! configure_database_connection "$DEPLOYMENT_ENV"; then
        # In cloud without database, that's acceptable for some operations
        if [ "$DEPLOYMENT_ENV" = "cloud" ]; then
            echo -e "${YELLOW}⚠${NC} Database configuration incomplete (may not be needed)" >&2
        else
            echo -e "${RED}✗${NC} Failed to configure database connection" >&2
            return 1
        fi
    else
        # Print summary only if configuration succeeded
        print_configuration_summary "$DEPLOYMENT_ENV"
    fi
    
    return 0
}

# Execute main if script is sourced
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    # Script is being sourced
    main
else
    # Script is being executed directly
    echo "This script should be sourced, not executed directly."
    echo "Usage: source $0"
    exit 1
fi
