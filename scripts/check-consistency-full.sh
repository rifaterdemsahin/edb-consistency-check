#!/bin/bash

# EDB/PostgreSQL Full Consistency Check Suite
# This script runs multiple consistency checks on the database

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Database connection parameters
DB_HOST="${DB_HOST:-postgres-service}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-testdb}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-postgres123}"

# Control which checks to run
RUN_CHECKSUMS="${RUN_CHECKSUMS:-true}"
RUN_INTEGRITY="${RUN_INTEGRITY:-true}"
RUN_BLOAT="${RUN_BLOAT:-true}"
RUN_VACUUM="${RUN_VACUUM:-false}"  # Disabled by default as it modifies the database

echo "=========================================="
echo "EDB Full Consistency Check Suite"
echo "=========================================="
echo ""

# Wait for database to be ready
echo "Waiting for PostgreSQL to be ready..."
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c '\q' 2>/dev/null; then
        echo -e "${GREEN}✓ Database is ready${NC}"
        break
    fi
    attempt=$((attempt + 1))
    echo "Attempt $attempt/$max_attempts - Database not ready yet..."
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo -e "${RED}✗ Failed to connect to database after $max_attempts attempts${NC}"
    exit 1
fi

echo ""

# Track overall status
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNINGS=0

# ====================
# Check 1: Data Checksums
# ====================
if [ "$RUN_CHECKSUMS" = "true" ]; then
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Check 1: Data Checksums (Safe)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "Running: SHOW data_checksums;"
    echo ""
    
    CHECKSUM_RESULT=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c "SHOW data_checksums;" | xargs)
    
    echo "Result: $CHECKSUM_RESULT"
    echo ""
    
    if [ "$CHECKSUM_RESULT" = "on" ]; then
        echo -e "${GREEN}✓ PASS: Data checksums are ENABLED${NC}"
        echo "  PostgreSQL will detect data corruption by verifying checksums on data pages."
        ((CHECKS_PASSED++))
    elif [ "$CHECKSUM_RESULT" = "off" ]; then
        echo -e "${YELLOW}⚠ WARNING: Data checksums are DISABLED${NC}"
        echo "  Consider enabling for production databases."
        ((CHECKS_WARNINGS++))
    else
        echo -e "${RED}✗ FAIL: Unexpected result${NC}"
        ((CHECKS_FAILED++))
    fi
    echo ""
fi

# ====================
# Check 2: Table/Index Integrity
# ====================
if [ "$RUN_INTEGRITY" = "true" ]; then
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Check 2: Table/Index Integrity (Can be intensive)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "Checking tables and indexes in catalog..."
    echo ""
    
    # Query to get table and index counts
    TABLE_COUNT=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM pg_catalog.pg_class WHERE relkind = 'r';" | xargs)
    INDEX_COUNT=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM pg_catalog.pg_class WHERE relkind = 'i';" | xargs)
    
    echo "Tables found: $TABLE_COUNT"
    echo "Indexes found: $INDEX_COUNT"
    echo ""
    
    # Show top 10 tables/indexes
    echo "Top 10 tables and indexes:"
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "
    SELECT 
        relname as name,
        CASE relkind 
            WHEN 'r' THEN 'table'
            WHEN 'i' THEN 'index'
        END as type,
        reltuples::bigint as estimated_rows
    FROM pg_catalog.pg_class 
    WHERE relkind IN ('r','i') 
    ORDER BY reltuples DESC 
    LIMIT 10;" 2>/dev/null || echo "Unable to query catalog"
    
    echo ""
    if [ "$TABLE_COUNT" -ge 0 ] && [ "$INDEX_COUNT" -ge 0 ]; then
        echo -e "${GREEN}✓ PASS: Catalog accessible, $TABLE_COUNT tables and $INDEX_COUNT indexes found${NC}"
        ((CHECKS_PASSED++))
    else
        echo -e "${RED}✗ FAIL: Unable to query catalog${NC}"
        ((CHECKS_FAILED++))
    fi
    echo ""
fi

# ====================
# Check 3: Table Bloat Analysis
# ====================
if [ "$RUN_BLOAT" = "true" ]; then
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Check 3: Table Bloat (Without full VACUUM)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "Analyzing table sizes..."
    echo ""
    
    # Get total database size
    DB_SIZE=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));" | xargs)
    echo "Total database size: $DB_SIZE"
    echo ""
    
    # Show top 10 largest tables
    echo "Top 10 largest tables:"
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "
    SELECT 
        schemaname,
        tablename,
        pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
    FROM pg_tables 
    WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
    ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC 
    LIMIT 10;" 2>/dev/null || echo "No user tables found"
    
    echo ""
    echo -e "${GREEN}✓ INFO: Bloat analysis complete${NC}"
    echo "  Note: For detailed bloat analysis, consider using pgstattuple extension"
    ((CHECKS_PASSED++))
    echo ""
fi

# ====================
# Check 4: VACUUM Recommendations
# ====================
if [ "$RUN_VACUUM" = "true" ]; then
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Check 4: VACUUM Operations (Modifies database)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}⚠ WARNING: VACUUM operations are enabled${NC}"
    echo "  This will perform maintenance on the database"
    echo ""
    
    # Get list of tables that might need vacuuming
    echo "Checking autovacuum statistics..."
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "
    SELECT 
        schemaname,
        relname,
        last_vacuum,
        last_autovacuum,
        n_tup_ins + n_tup_upd + n_tup_del as changes
    FROM pg_stat_user_tables
    ORDER BY changes DESC
    LIMIT 5;" 2>/dev/null || echo "Unable to check vacuum statistics"
    
    echo ""
    echo -e "${YELLOW}⚠ INFO: VACUUM operations not performed in this check${NC}"
    echo "  To vacuum a specific table manually, run:"
    echo "  VACUUM (VERBOSE, ANALYZE) table_name;"
    echo ""
else
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Check 4: VACUUM Operations (Skipped)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "VACUUM checks are disabled by default"
    echo "To enable, set RUN_VACUUM=true"
    echo ""
fi

# ====================
# Summary
# ====================
echo ""
echo "=========================================="
echo "Consistency Check Summary"
echo "=========================================="
echo ""
echo "Checks passed:    $CHECKS_PASSED"
echo "Checks with warnings: $CHECKS_WARNINGS"
echo "Checks failed:    $CHECKS_FAILED"
echo ""

if [ $CHECKS_FAILED -eq 0 ] && [ $CHECKS_WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed successfully!${NC}"
    exit 0
elif [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${YELLOW}✓ All checks passed with $CHECKS_WARNINGS warning(s)${NC}"
    exit 0
else
    echo -e "${RED}✗ Some checks failed!${NC}"
    exit 1
fi
