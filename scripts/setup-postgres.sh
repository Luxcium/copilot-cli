#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# PostgreSQL + pgAdmin Docker Setup Script
# Purpose: PostgreSQL for copilot-cli persistent data with optional web UI
# Usage: ./setup-postgres.sh [OPTIONS]
#
# AI Agent Notes:
#   - Always check --status before operations
#   - Use --dry-run to preview changes
#   - Web UI available at http://localhost:5435 (pgAdmin) when enabled
#   - Direct DB access on port 5434
#   - All timestamps in UTC for consistency
#   - Script is idempotent - safe to run multiple times
###############################################################################

# Configuration - Edit these as needed
readonly CONTAINER_NAME="copilot-cli-postgres"
readonly PGADMIN_NAME="copilot-cli-pgadmin"
readonly POSTGRES_VERSION="16-alpine"
readonly PGADMIN_VERSION="latest"
readonly POSTGRES_PORT="5434"  # Non-standard port to avoid conflicts
readonly PGADMIN_PORT="5435"   # Web UI port
readonly POSTGRES_USER="copilot_user"
readonly POSTGRES_DB="copilot_cli"
readonly DATA_VOLUME="copilot-cli-pgdata"
readonly PGADMIN_VOLUME="copilot-cli-pgadmin"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_ROOT}/.env"
LOG_FILE="${PROJECT_ROOT}/logs/postgres-setup.log"

# Flags
DRY_RUN=false
ACTION="setup"
ENABLE_PGADMIN=false

###############################################################################
# Helper Functions
###############################################################################

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

info() { echo -e "${BLUE}ℹ${NC} $*"; log "INFO" "$*"; }
success() { echo -e "${GREEN}✓${NC} $*"; log "SUCCESS" "$*"; }
warning() { echo -e "${YELLOW}⚠${NC} $*"; log "WARNING" "$*"; }
error() { echo -e "${RED}✗${NC} $*" >&2; log "ERROR" "$*"; }
fatal() { error "$*"; exit 1; }

check_command() {
    if ! command -v "$1" &> /dev/null; then
        fatal "Required command not found: $1"
    fi
}

detect_environment() {
    info "Detecting environment..."
    
    if [ -f /etc/fedora-release ]; then
        info "Running on Fedora Linux"
        grep -oP '(?<=release )[0-9]+' /etc/fedora-release || echo "unknown"
    fi
    
    if [ -n "${XDG_CURRENT_DESKTOP:-}" ]; then
        info "Desktop environment: $XDG_CURRENT_DESKTOP"
    fi
    
    if [ -n "${USER:-}" ]; then
        info "User: $USER"
    fi
}

check_prerequisites() {
    info "Checking prerequisites..."
    
    check_command docker
    
    if ! docker info &> /dev/null; then
        fatal "Docker daemon is not running or you don't have permission to access it"
    fi
    
    success "All prerequisites met"
}

check_port_available() {
    if ss -tuln 2>/dev/null | grep -q ":${POSTGRES_PORT} "; then
        warning "Port ${POSTGRES_PORT} is already in use"
        return 1
    fi
    return 0
}

generate_password() {
    if [ -f "$ENV_FILE" ] && grep -q "POSTGRES_PASSWORD=" "$ENV_FILE"; then
        info "Password already exists in .env file"
        return 0
    fi
    
    local password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    local pgadmin_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    
    if [ "$DRY_RUN" = true ]; then
        info "[DRY-RUN] Would generate passwords and save to $ENV_FILE"
        return 0
    fi
    
    cat >> "$ENV_FILE" << EOF
# PostgreSQL Configuration - Generated $(date -u '+%Y-%m-%dT%H:%M:%SZ')
POSTGRES_PASSWORD=${password}
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_DB=${POSTGRES_DB}
POSTGRES_HOST=localhost
POSTGRES_PORT=${POSTGRES_PORT}
DATABASE_URL=postgresql://${POSTGRES_USER}:${password}@localhost:${POSTGRES_PORT}/${POSTGRES_DB}

# pgAdmin Configuration (Web UI)
PGADMIN_DEFAULT_EMAIL=admin@copilot-cli.local
PGADMIN_DEFAULT_PASSWORD=${pgadmin_password}
PGADMIN_PORT=${PGADMIN_PORT}
PGADMIN_URL=http://localhost:${PGADMIN_PORT}
EOF
    chmod 600 "$ENV_FILE"
    success "Generated passwords and saved to .env"
}

container_exists() {
    docker ps -a --format '{{.Names}}' | grep -q "^${1}$"
}

container_running() {
    docker ps --format '{{.Names}}' | grep -q "^${1}$"
}

get_container_uptime() {
    if container_running "$1"; then
        docker inspect --format='{{.State.StartedAt}}' "$1" 2>/dev/null | xargs -I{} date -d {} '+Started: %Y-%m-%d %H:%M:%S UTC' 2>/dev/null || echo "Unknown"
    else
        echo "Not running"
    fi
}

get_container_health() {
    if container_running "$1"; then
        docker inspect --format='{{.State.Health.Status}}' "$1" 2>/dev/null || echo "No health check"
    else
        echo "N/A"
    fi
}

setup_postgres() {
    info "Setting up PostgreSQL container..."
    
    if container_running "$CONTAINER_NAME"; then
        success "PostgreSQL container is already running"
        if [ "$ENABLE_PGADMIN" = true ]; then
            setup_pgadmin
        fi
        return 0
    fi
    
    if container_exists "$CONTAINER_NAME"; then
        info "Container exists but is stopped. Starting it..."
        start_postgres
        return 0
    fi
    
    if ! check_port_available; then
        fatal "Port ${POSTGRES_PORT} is in use. Please stop the conflicting service or change POSTGRES_PORT"
    fi
    
    generate_password
    
    if [ "$DRY_RUN" = true ]; then
        info "[DRY-RUN] Would create Docker volume: $DATA_VOLUME"
        info "[DRY-RUN] Would run PostgreSQL container with:"
        info "  - Image: postgres:${POSTGRES_VERSION}"
        info "  - Port: ${POSTGRES_PORT}:5432"
        info "  - Database: ${POSTGRES_DB}"
        info "  - User: ${POSTGRES_USER}"
        if [ "$ENABLE_PGADMIN" = true ]; then
            info "[DRY-RUN] Would also setup pgAdmin web UI on port ${PGADMIN_PORT}"
        fi
        return 0
    fi
    
    if [ ! -f "$ENV_FILE" ]; then
        fatal ".env file not found. Cannot proceed without password."
    fi
    
    # Load password from .env without conflicting with readonly vars
    local POSTGRES_PASSWORD_VALUE=$(grep "^POSTGRES_PASSWORD=" "$ENV_FILE" | cut -d= -f2)
    
    if [ -z "$POSTGRES_PASSWORD_VALUE" ]; then
        fatal "POSTGRES_PASSWORD not set in .env file"
    fi
    
    docker volume create "$DATA_VOLUME" &>> "$LOG_FILE"
    success "Created volume: $DATA_VOLUME"
    
    info "Starting PostgreSQL container..."
    docker run -d \
        --name "$CONTAINER_NAME" \
        --restart unless-stopped \
        -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD_VALUE" \
        -e POSTGRES_USER="$POSTGRES_USER" \
        -e POSTGRES_DB="$POSTGRES_DB" \
        -p "${POSTGRES_PORT}:5432" \
        -v "${DATA_VOLUME}:/var/lib/postgresql/data" \
        "postgres:${POSTGRES_VERSION}" &>> "$LOG_FILE"
    
    success "PostgreSQL container started"
    info "Waiting for PostgreSQL to be ready..."
    
    local max_attempts=30
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if docker exec "$CONTAINER_NAME" pg_isready -U "$POSTGRES_USER" &> /dev/null; then
            success "PostgreSQL is ready and accepting connections!"
            break
        fi
        sleep 1
        ((attempt++))
    done
    
    if [ $attempt -eq $max_attempts ]; then
        error "PostgreSQL didn't become ready within 30 seconds (check logs)"
        return 1
    fi
    
    if [ "$ENABLE_PGADMIN" = true ]; then
        setup_pgadmin
    fi
    
    return 0
}

setup_pgadmin() {
    info "Setting up pgAdmin web UI..."
    
    if container_running "$PGADMIN_NAME"; then
        success "pgAdmin is already running"
        return 0
    fi
    
    if container_exists "$PGADMIN_NAME"; then
        info "pgAdmin container exists, starting..."
        docker start "$PGADMIN_NAME" &>> "$LOG_FILE"
        success "pgAdmin started"
        return 0
    fi
    
    if ! ss -tuln 2>/dev/null | grep -q ":${PGADMIN_PORT} "; then
        local PGADMIN_EMAIL=$(grep "^PGADMIN_DEFAULT_EMAIL=" "$ENV_FILE" | cut -d= -f2)
        local PGADMIN_PASS=$(grep "^PGADMIN_DEFAULT_PASSWORD=" "$ENV_FILE" | cut -d= -f2)
        
        docker volume create "$PGADMIN_VOLUME" &>> "$LOG_FILE"
        
        docker run -d \
            --name "$PGADMIN_NAME" \
            --restart unless-stopped \
            -e PGADMIN_DEFAULT_EMAIL="$PGADMIN_EMAIL" \
            -e PGADMIN_DEFAULT_PASSWORD="$PGADMIN_PASS" \
            -e PGADMIN_CONFIG_SERVER_MODE="False" \
            -p "${PGADMIN_PORT}:80" \
            -v "${PGADMIN_VOLUME}:/var/lib/pgadmin" \
            "dpage/pgadmin4:${PGADMIN_VERSION}" &>> "$LOG_FILE"
        
        success "pgAdmin container started"
        info "Access web UI at: http://localhost:${PGADMIN_PORT}"
        info "Login: ${PGADMIN_EMAIL}"
        info "Password: (check .env file for PGADMIN_DEFAULT_PASSWORD)"
    else
        warning "Port ${PGADMIN_PORT} is already in use, skipping pgAdmin setup"
    fi
}

stop_postgres() {
    if ! container_exists "$CONTAINER_NAME"; then
        warning "PostgreSQL container does not exist"
        return 0
    fi
    
    if ! container_running "$CONTAINER_NAME"; then
        info "PostgreSQL is already stopped"
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        info "[DRY-RUN] Would stop container: $CONTAINER_NAME"
        if container_exists "$PGADMIN_NAME"; then
            info "[DRY-RUN] Would stop container: $PGADMIN_NAME"
        fi
        return 0
    fi
    
    info "Stopping PostgreSQL..."
    docker stop "$CONTAINER_NAME" &>> "$LOG_FILE"
    success "PostgreSQL stopped"
    
    if container_running "$PGADMIN_NAME"; then
        info "Stopping pgAdmin..."
        docker stop "$PGADMIN_NAME" &>> "$LOG_FILE"
        success "pgAdmin stopped"
    fi
}

start_postgres() {
    if ! container_exists "$CONTAINER_NAME"; then
        fatal "PostgreSQL container does not exist. Run --setup first."
    fi
    
    if container_running "$CONTAINER_NAME"; then
        info "PostgreSQL is already running"
    else
        if [ "$DRY_RUN" = true ]; then
            info "[DRY-RUN] Would start container: $CONTAINER_NAME"
        else
            docker start "$CONTAINER_NAME" &>> "$LOG_FILE"
            success "PostgreSQL started"
        fi
    fi
    
    if container_exists "$PGADMIN_NAME" && ! container_running "$PGADMIN_NAME"; then
        if [ "$DRY_RUN" = true ]; then
            info "[DRY-RUN] Would start container: $PGADMIN_NAME"
        else
            info "Starting pgAdmin..."
            docker start "$PGADMIN_NAME" &>> "$LOG_FILE"
            success "pgAdmin started"
        fi
    fi
}

show_status() {
    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    info "Copilot CLI Database Status - ${timestamp}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # PostgreSQL Status
    echo "📊 PostgreSQL Database:"
    if container_exists "$CONTAINER_NAME"; then
        if container_running "$CONTAINER_NAME"; then
            success "Status: Running ✓"
            echo "   Port: ${POSTGRES_PORT}"
            echo "   Database: ${POSTGRES_DB}"
            echo "   User: ${POSTGRES_USER}"
            echo "   $(get_container_uptime "$CONTAINER_NAME")"
            
            # Test connection
            if docker exec "$CONTAINER_NAME" pg_isready -U "$POSTGRES_USER" &> /dev/null; then
                success "   Connection: Accepting connections ✓"
            else
                warning "   Connection: Not ready"
            fi
            
            # Get database size
            local db_size=$(docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c "SELECT pg_size_pretty(pg_database_size('${POSTGRES_DB}'));" 2>/dev/null | xargs)
            if [ -n "$db_size" ]; then
                echo "   Size: ${db_size}"
            fi
        else
            warning "Status: Stopped (run --start to start)"
        fi
    else
        warning "Status: Not configured (run --setup to initialize)"
    fi
    
    echo ""
    
    # pgAdmin Status
    echo "🌐 Web UI (pgAdmin):"
    if container_exists "$PGADMIN_NAME"; then
        if container_running "$PGADMIN_NAME"; then
            success "Status: Running ✓"
            echo "   URL: http://localhost:${PGADMIN_PORT}"
            echo "   $(get_container_uptime "$PGADMIN_NAME")"
        else
            warning "Status: Stopped (run --start to start)"
        fi
    else
        info "Status: Not installed (use --with-ui flag to enable)"
    fi
    
    echo ""
    
    # Configuration
    echo "⚙️  Configuration:"
    if [ -f "$ENV_FILE" ]; then
        success "Config file: ${ENV_FILE} ✓"
        info "Connection string available in .env"
        
        if [ -r "$ENV_FILE" ]; then
            local DB_URL=$(grep "^DATABASE_URL=" "$ENV_FILE" | cut -d= -f2-)
            echo ""
            echo "   Quick connect commands:"
            echo "   $ psql \"${DB_URL}\""
            echo "   $ docker exec -it ${CONTAINER_NAME} psql -U ${POSTGRES_USER} -d ${POSTGRES_DB}"
        fi
    else
        warning "Config file not found (will be created on setup)"
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # AI Agent helpful info
    if container_running "$CONTAINER_NAME" 2>/dev/null; then
        echo "💡 For AI Agents:"
        echo "   - Database ready for operations"
        echo "   - Use \$DATABASE_URL from .env for connections"
        echo "   - Port ${POSTGRES_PORT} for direct SQL access"
        [ -f "$ENV_FILE" ] && echo "   - Credentials in: ${ENV_FILE}"
        echo ""
    fi
}

show_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Set up and manage PostgreSQL + optional web UI for copilot-cli

OPTIONS:
    --setup         Set up and start PostgreSQL (default)
    --start         Start the database containers
    --stop          Stop the database containers
    --status        Show detailed status (RECOMMENDED - check this first!)
    --with-ui       Include pgAdmin web UI on port ${PGADMIN_PORT}
    --dry-run       Preview what would be done without changes
    --help          Show this help message

EXAMPLES:
    $(basename "$0") --status                    # Check what's running
    $(basename "$0") --dry-run                   # Preview setup
    $(basename "$0") --setup                     # Setup database only
    $(basename "$0") --setup --with-ui           # Setup with web UI
    $(basename "$0") --start                     # Start containers
    $(basename "$0") --stop                      # Stop containers

ACCESS:
    PostgreSQL:  localhost:${POSTGRES_PORT}
    pgAdmin UI:  http://localhost:${PGADMIN_PORT} (if enabled with --with-ui)
    Credentials: See .env file after setup

CONFIGURATION:
    Database: ${POSTGRES_DB}
    User: ${POSTGRES_USER}
    Volumes: ${DATA_VOLUME}, ${PGADMIN_VOLUME}

AI AGENT NOTES:
    - Always check --status before operations
    - Script is idempotent (safe to re-run)
    - Use --dry-run to preview changes
    - All timestamps in UTC
    - Credentials auto-generated in .env
    - Port ${POSTGRES_PORT} avoids conflicts with default PostgreSQL (5432)

EOF
}

###############################################################################
# Main
###############################################################################

main() {
    # Create logs directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --setup)
                ACTION="setup"
                shift
                ;;
            --stop)
                ACTION="stop"
                shift
                ;;
            --start)
                ACTION="start"
                shift
                ;;
            --status)
                ACTION="status"
                shift
                ;;
            --with-ui)
                ENABLE_PGADMIN=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                echo ""
                show_usage
                exit 1
                ;;
        esac
    done
    
    if [ "$DRY_RUN" = true ]; then
        warning "DRY-RUN MODE - No changes will be made"
    fi
    
    detect_environment
    check_prerequisites
    
    case $ACTION in
        setup)
            setup_postgres
            echo ""
            show_status
            ;;
        stop)
            stop_postgres
            ;;
        start)
            start_postgres
            ;;
        status)
            show_status
            ;;
    esac
    
    success "Operation completed"
}

main "$@"
