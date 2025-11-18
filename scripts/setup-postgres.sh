#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# PostgreSQL Docker Container Setup Script
# Purpose: Set up a PostgreSQL container for copilot-cli persistent data
# Usage: ./setup-postgres.sh [--dry-run] [--stop] [--start] [--status]
###############################################################################

# Configuration - Edit these as needed
readonly CONTAINER_NAME="copilot-cli-postgres"
readonly POSTGRES_VERSION="16-alpine"
readonly POSTGRES_PORT="5434"  # Non-standard port to avoid conflicts
readonly POSTGRES_USER="copilot_user"
readonly POSTGRES_DB="copilot_cli"
readonly DATA_VOLUME="copilot-cli-pgdata"

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

###############################################################################
# Helper Functions
###############################################################################

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
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
    
    if [ "$DRY_RUN" = true ]; then
        info "[DRY-RUN] Would generate password and save to $ENV_FILE"
        return 0
    fi
    
    cat >> "$ENV_FILE" << EOF
# PostgreSQL Configuration
POSTGRES_PASSWORD=${password}
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_DB=${POSTGRES_DB}
POSTGRES_HOST=localhost
POSTGRES_PORT=${POSTGRES_PORT}
DATABASE_URL=postgresql://${POSTGRES_USER}:${password}@localhost:${POSTGRES_PORT}/${POSTGRES_DB}
EOF
    chmod 600 "$ENV_FILE"
    success "Generated password and saved to .env"
}

container_exists() {
    docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

container_running() {
    docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

setup_postgres() {
    info "Setting up PostgreSQL container..."
    
    if container_running; then
        success "Container is already running"
        return 0
    fi
    
    if container_exists; then
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
        info "[DRY-RUN] Would run container with:"
        info "  - Image: postgres:${POSTGRES_VERSION}"
        info "  - Port: ${POSTGRES_PORT}:5432"
        info "  - Database: ${POSTGRES_DB}"
        info "  - User: ${POSTGRES_USER}"
        return 0
    fi
    
    if [ ! -f "$ENV_FILE" ]; then
        fatal ".env file not found. Cannot proceed without password."
    fi
    
    source "$ENV_FILE"
    
    if [ -z "${POSTGRES_PASSWORD:-}" ]; then
        fatal "POSTGRES_PASSWORD not set in .env file"
    fi
    
    docker volume create "$DATA_VOLUME" &>> "$LOG_FILE"
    success "Created volume: $DATA_VOLUME"
    
    docker run -d \
        --name "$CONTAINER_NAME" \
        --restart unless-stopped \
        -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
        -e POSTGRES_USER="$POSTGRES_USER" \
        -e POSTGRES_DB="$POSTGRES_DB" \
        -p "${POSTGRES_PORT}:5432" \
        -v "${DATA_VOLUME}:/var/lib/postgresql/data" \
        "postgres:${POSTGRES_VERSION}" &>> "$LOG_FILE"
    
    success "PostgreSQL container started successfully"
    info "Waiting for PostgreSQL to be ready..."
    
    local max_attempts=30
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if docker exec "$CONTAINER_NAME" pg_isready -U "$POSTGRES_USER" &> /dev/null; then
            success "PostgreSQL is ready!"
            return 0
        fi
        sleep 1
        ((attempt++))
    done
    
    fatal "PostgreSQL failed to become ready within 30 seconds"
}

stop_postgres() {
    if ! container_exists; then
        warning "Container does not exist"
        return 0
    fi
    
    if ! container_running; then
        info "Container is already stopped"
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        info "[DRY-RUN] Would stop container: $CONTAINER_NAME"
        return 0
    fi
    
    docker stop "$CONTAINER_NAME" &>> "$LOG_FILE"
    success "Container stopped"
}

start_postgres() {
    if ! container_exists; then
        fatal "Container does not exist. Run setup first."
    fi
    
    if container_running; then
        info "Container is already running"
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        info "[DRY-RUN] Would start container: $CONTAINER_NAME"
        return 0
    fi
    
    docker start "$CONTAINER_NAME" &>> "$LOG_FILE"
    success "Container started"
}

show_status() {
    info "PostgreSQL Status:"
    echo ""
    
    if container_exists; then
        if container_running; then
            success "Container: Running"
            docker ps --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        else
            warning "Container: Stopped"
        fi
    else
        warning "Container: Does not exist"
    fi
    
    echo ""
    if [ -f "$ENV_FILE" ]; then
        info "Configuration file: $ENV_FILE"
        info "Connection string available in .env"
    else
        warning "Configuration file not found"
    fi
}

show_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Set up and manage PostgreSQL container for copilot-cli

OPTIONS:
    --dry-run       Show what would be done without making changes
    --setup         Set up and start PostgreSQL (default)
    --stop          Stop the PostgreSQL container
    --start         Start the PostgreSQL container
    --status        Show container status
    --help          Show this help message

EXAMPLES:
    $(basename "$0") --dry-run          # Preview setup
    $(basename "$0")                    # Setup and start
    $(basename "$0") --status           # Check status
    $(basename "$0") --stop             # Stop container

CONFIGURATION:
    Port: ${POSTGRES_PORT}
    Database: ${POSTGRES_DB}
    User: ${POSTGRES_USER}
    Volume: ${DATA_VOLUME}

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
            --help)
                show_usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
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
