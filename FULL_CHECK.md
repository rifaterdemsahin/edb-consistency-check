# Full Consistency Check Suite

This document describes the extended consistency check suite that includes multiple checks beyond just data checksums.

## Overview

The full consistency check suite runs four different checks on your PostgreSQL database:

1. **Data Checksums** (Safe, Read-only)
2. **Table/Index Integrity** (Can be intensive, Read-only)
3. **Table Bloat Analysis** (Read-only)
4. **VACUUM Recommendations** (Read-only, disabled by default)

## SQL Queries Used

### 1. Data Checksums Check (Safe)
```sql
SHOW data_checksums;
```
Verifies that data checksums are enabled for corruption detection.

### 2. Table/Index Integrity Check (Can be intensive)
```sql
-- Count tables and indexes
SELECT COUNT(*) FROM pg_catalog.pg_class WHERE relkind = 'r';  -- tables
SELECT COUNT(*) FROM pg_catalog.pg_class WHERE relkind = 'i';  -- indexes

-- Show top 10 tables/indexes
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
LIMIT 10;
```
Checks the catalog for table and index integrity.

### 3. Table Bloat Check (Without full VACUUM)
```sql
-- Database size
SELECT pg_size_pretty(pg_database_size('database_name'));

-- Top 10 largest tables
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables 
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC 
LIMIT 10;
```
Analyzes table sizes to identify potential bloat.

### 4. VACUUM Recommendations (Disabled by default)
```sql
-- Check autovacuum statistics
SELECT 
    schemaname,
    relname,
    last_vacuum,
    last_autovacuum,
    n_tup_ins + n_tup_upd + n_tup_del as changes
FROM pg_stat_user_tables
ORDER BY changes DESC
LIMIT 5;
```
Provides information about tables that might need vacuuming.

**Note**: To actually run VACUUM on a specific table:
```sql
VACUUM (VERBOSE, ANALYZE) table_name;
```

## Usage

### Using Makefile

Run the full consistency check suite:

```bash
make check-full
```

Or run the complete workflow (setup + deploy + full check):

```bash
make all-full
```

### Using kubectl Directly

```bash
# Deploy the full check job
kubectl apply -f k8s/full-check-job.yaml

# Wait for completion
kubectl wait --for=condition=complete job/full-consistency-check-job --timeout=180s

# View results
kubectl logs job/full-consistency-check-job
```

### Using the Script Directly

You can also run the script standalone (if you have psql client):

```bash
export DB_HOST=postgres-service
export DB_NAME=testdb
export DB_USER=postgres
export DB_PASSWORD=postgres123

./scripts/check-consistency-full.sh
```

## Configuration

The full check suite can be configured using environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `RUN_CHECKSUMS` | `true` | Enable/disable data checksums check |
| `RUN_INTEGRITY` | `true` | Enable/disable table/index integrity check |
| `RUN_BLOAT` | `true` | Enable/disable bloat analysis |
| `RUN_VACUUM` | `false` | Enable/disable VACUUM recommendations |

### Example: Enable VACUUM Check

Edit `k8s/full-check-job.yaml` and change:

```yaml
- name: RUN_VACUUM
  value: "true"
```

Then deploy:

```bash
kubectl apply -f k8s/full-check-job.yaml
```

## Expected Output

### Successful Run

```
==========================================
EDB Full Consistency Check Suite
==========================================

✓ Database is ready

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Check 1: Data Checksums (Safe)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Running: SHOW data_checksums;

Result: on

✓ PASS: Data checksums are ENABLED
  PostgreSQL will detect data corruption by verifying checksums on data pages.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Check 2: Table/Index Integrity (Can be intensive)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Checking tables and indexes in catalog...

Tables found: 45
Indexes found: 78

Top 10 tables and indexes:
[Table listing...]

✓ PASS: Catalog accessible, 45 tables and 78 indexes found

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Check 3: Table Bloat (Without full VACUUM)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Analyzing table sizes...

Total database size: 25 MB

Top 10 largest tables:
[Table sizes...]

✓ INFO: Bloat analysis complete
  Note: For detailed bloat analysis, consider using pgstattuple extension

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Check 4: VACUUM Operations (Skipped)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
VACUUM checks are disabled by default
To enable, set RUN_VACUUM=true

==========================================
Consistency Check Summary
==========================================

Checks passed:        3
Checks with warnings: 0
Checks failed:        0

✓ All checks passed successfully!
```

## Performance Considerations

- **Data Checksums Check**: Very fast, < 1 second
- **Integrity Check**: Fast for small databases, can take longer for large databases with many tables
- **Bloat Analysis**: Generally fast, depends on number of tables
- **VACUUM Info**: Fast, just queries statistics

The full check suite is designed to be read-only and safe to run on production databases. However, on very large databases, the integrity check might take some time.

## Comparison with Basic Check

| Feature | Basic Check | Full Check |
|---------|-------------|------------|
| Data Checksums | ✓ | ✓ |
| Table/Index Integrity | ✗ | ✓ |
| Bloat Analysis | ✗ | ✓ |
| VACUUM Recommendations | ✗ | ✓ (optional) |
| Execution Time | < 5s | < 30s (typical) |
| Resource Usage | Minimal | Low to Moderate |

## When to Use Each Check

### Use Basic Check When:
- You just need to verify checksums are enabled
- Running quick CI/CD validations
- Minimal resource usage is critical

### Use Full Check When:
- You want comprehensive database health analysis
- Troubleshooting performance issues
- Regular maintenance checks
- Preparing for upgrades or migrations

## Troubleshooting

### Check Takes Too Long

If the integrity check takes too long, you can disable it:

```yaml
- name: RUN_INTEGRITY
  value: "false"
```

### Permission Errors

Ensure the database user has appropriate permissions:

```sql
GRANT CONNECT ON DATABASE testdb TO postgres;
GRANT USAGE ON SCHEMA public TO postgres;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO postgres;
```

### Memory Issues

If the check job runs out of memory, increase the resource limits in the Job manifest.

## Adding Custom Checks

You can extend `scripts/check-consistency-full.sh` to add your own checks. Follow the pattern:

```bash
# Check N: Your Custom Check
if [ "$RUN_YOUR_CHECK" = "true" ]; then
    echo "Running your check..."
    # Your SQL query here
    RESULT=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST ... -c "YOUR QUERY")
    
    if [ condition ]; then
        echo "✓ PASS: Your check passed"
        ((CHECKS_PASSED++))
    else
        echo "✗ FAIL: Your check failed"
        ((CHECKS_FAILED++))
    fi
fi
```

## Related Documentation

- [CHECKSUMS.md](CHECKSUMS.md) - Deep dive on data checksums
- [README.md](README.md) - Main project documentation
- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture
- [EXAMPLES.md](EXAMPLES.md) - Usage examples
