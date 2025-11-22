#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Example Database Query Script
# Purpose: Demonstrate environment-agnostic database operations
# Usage: ./scripts/example-query.sh
#
# This script works in both local and cloud environments automatically.
#
# AI Agent Notes:
#   - Source detect-environment.sh for automatic configuration
#   - Use the configured $DATABASE_URL or individual variables
#   - Script adapts to local (port 5434) or cloud (port 5432) automatically
###############################################################################

# Colors for output
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   Example Database Query Script${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Source environment detection
# This automatically configures database connection for local or cloud
echo "Loading environment configuration..."
source "$(dirname "$0")/detect-environment.sh"

echo ""
echo -e "${GREEN}✓${NC} Environment configured"
echo "  Type: $DEPLOYMENT_ENV"
echo "  CI: $IS_CI"
echo ""

# Check if psql is available
if ! command -v psql &> /dev/null; then
    echo -e "${YELLOW}⚠${NC} psql not installed, cannot execute queries"
    echo "  This example requires PostgreSQL client tools"
    exit 0
fi

# Example 1: Check PostgreSQL version
echo -e "${BLUE}Example 1:${NC} Checking PostgreSQL version..."
PGPASSWORD="$POSTGRES_PASSWORD" psql \
    -h "$POSTGRES_HOST" \
    -p "$POSTGRES_PORT" \
    -U "$POSTGRES_USER" \
    -d "$POSTGRES_DB" \
    -c "SELECT version();" 2>&1 || {
    echo -e "${YELLOW}⚠${NC} Could not connect to database (it may not be running)"
    if [ "$DEPLOYMENT_ENV" = "local" ]; then
        echo "  Try: ./scripts/setup-postgres.sh --start"
    fi
    exit 0
}

echo ""

# Example 2: Create a test table
echo -e "${BLUE}Example 2:${NC} Creating test table..."
PGPASSWORD="$POSTGRES_PASSWORD" psql \
    -h "$POSTGRES_HOST" \
    -p "$POSTGRES_PORT" \
    -U "$POSTGRES_USER" \
    -d "$POSTGRES_DB" \
    -c "CREATE TABLE IF NOT EXISTS example_data (
        id SERIAL PRIMARY KEY,
        environment VARCHAR(50),
        created_at TIMESTAMP DEFAULT NOW(),
        message TEXT
    );" > /dev/null 2>&1

echo -e "${GREEN}✓${NC} Table created or already exists"
echo ""

# Example 3: Insert data
echo -e "${BLUE}Example 3:${NC} Inserting sample data..."
PGPASSWORD="$POSTGRES_PASSWORD" psql \
    -h "$POSTGRES_HOST" \
    -p "$POSTGRES_PORT" \
    -U "$POSTGRES_USER" \
    -d "$POSTGRES_DB" \
    -c "INSERT INTO example_data (environment, message) 
        VALUES ('$DEPLOYMENT_ENV', 'Test from $(date -u +%Y-%m-%dT%H:%M:%SZ)');" \
    > /dev/null 2>&1

echo -e "${GREEN}✓${NC} Data inserted"
echo ""

# Example 4: Query data
echo -e "${BLUE}Example 4:${NC} Querying recent entries..."
PGPASSWORD="$POSTGRES_PASSWORD" psql \
    -h "$POSTGRES_HOST" \
    -p "$POSTGRES_PORT" \
    -U "$POSTGRES_USER" \
    -d "$POSTGRES_DB" \
    -c "SELECT id, environment, created_at, message 
        FROM example_data 
        ORDER BY created_at DESC 
        LIMIT 5;"

echo ""

# Example 5: Count entries by environment
echo -e "${BLUE}Example 5:${NC} Counting entries by environment..."
PGPASSWORD="$POSTGRES_PASSWORD" psql \
    -h "$POSTGRES_HOST" \
    -p "$POSTGRES_PORT" \
    -U "$POSTGRES_USER" \
    -d "$POSTGRES_DB" \
    -c "SELECT environment, COUNT(*) as count 
        FROM example_data 
        GROUP BY environment 
        ORDER BY count DESC;"

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ All examples completed successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Show environment summary
echo "This script executed in: $DEPLOYMENT_ENV environment"
if [ "$DEPLOYMENT_ENV" = "local" ]; then
    echo "  - Using local Docker container"
    echo "  - Port: $POSTGRES_PORT"
    echo "  - Data persists in Docker volume"
else
    echo "  - Using cloud service container"
    echo "  - Port: $POSTGRES_PORT"
    echo "  - Data is ephemeral (destroyed after workflow)"
fi
echo ""
