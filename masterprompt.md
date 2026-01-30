# Master Prompt: PostgreSQL Consistency Check Project

## Project Overview

Create a complete PostgreSQL consistency checking tool that runs on Kubernetes (Minikube) in GitHub Codespaces. This project provides comprehensive database health checks including data checksums verification, table/index integrity validation, bloat analysis, and VACUUM recommendations.

## Project Purpose

The project verifies PostgreSQL data integrity and database health through automated consistency checks. The primary focus is detecting potential storage corruption and database health issues using safe, read-only SQL queries that can be run in production environments.

## Technology Stack

- **Container Orchestration**: Kubernetes (Minikube for local development)
- **Database**: PostgreSQL 15 Alpine
- **Scripting**: Bash shell scripts
- **Deployment**: Kubernetes manifests (YAML)
- **CI/CD**: GitHub Actions
- **Build Tool**: GNU Make
- **Documentation**: Markdown

## Core Features

1. **Basic Consistency Check**
   - Data checksums verification using `SHOW data_checksums;`
   - Fast, safe, read-only check
   - Color-coded output with clear pass/fail indicators

2. **Full Consistency Check Suite**
   - Data checksums (safe)
   - Table/Index integrity check (can be intensive)
   - Table bloat analysis
   - VACUUM recommendations (optional)

3. **Kubernetes Deployment**
   - PostgreSQL with data checksums enabled
   - ConfigMap-based configuration
   - Secret management for credentials
   - ClusterIP service for internal access

4. **Automation Scripts**
   - Minikube setup and initialization
   - One-command deployment and checking
   - Interactive PostgreSQL access
   - Resource cleanup utilities

5. **Comprehensive Documentation**
   - Main README with quick start
   - Architecture documentation with diagrams
   - Deep dive on data checksums
   - Usage examples and sample outputs
   - Quick start guide

## Project Structure

```
edb-consistency-check/
├── .github/
│   └── workflows/
│       └── ci.yaml                     # GitHub Actions CI/CD pipeline
├── k8s/                                # Kubernetes manifests directory
│   ├── postgres-deployment.yaml        # PostgreSQL deployment with checksums
│   ├── check-job.yaml                  # Basic consistency check job
│   └── full-check-job.yaml             # Full consistency check suite job
├── scripts/                            # Shell scripts directory
│   ├── setup-minikube.sh               # Minikube installation and setup
│   ├── deploy-and-check.sh             # Full deployment workflow
│   ├── check-data-checksums.sh         # Standalone checksum verification
│   ├── check-consistency-full.sh       # Full consistency check script
│   ├── cleanup.sh                      # Resource cleanup script
│   ├── interactive-psql.sh             # Interactive database access
│   └── validate.sh                     # Pre-deployment validation
├── ARCHITECTURE.md                     # System architecture and diagrams
├── CHECKSUMS.md                        # Deep dive on data checksums
├── EXAMPLES.md                         # Sample outputs and usage examples
├── FULL_CHECK.md                       # Full consistency check documentation
├── PROJECT_SUMMARY.md                  # Project summary and achievements
├── QUICKSTART.md                       # Quick start guide
├── README.md                           # Main project documentation
├── Makefile                            # Build automation and convenience commands
└── .gitignore                          # Git ignore patterns
```

## Detailed Implementation Instructions

### 1. Kubernetes Manifests

#### File: k8s/postgres-deployment.yaml
Create a Kubernetes manifest with the following resources:

**ConfigMap (postgres-config):**
- Store non-sensitive database configuration
- Keys: POSTGRES_DB (testdb), POSTGRES_USER (postgres)

**Secret (postgres-secret):**
- Store database password securely
- Key: POSTGRES_PASSWORD
- **Example value for testing**: "postgres123"
- **IMPORTANT**: Use strong, randomly generated passwords in production
- Never commit actual production passwords to version control

**Deployment (postgres):**
- Image: postgres:15-alpine
- Replicas: 1
- Container port: 5432
- **Critical**: Add args `["-c", "data_checksums=on"]` to enable checksums during initialization
  - Note: This works because PostgreSQL checks this setting during initdb when the data directory is empty
  - On first startup with empty volume, PostgreSQL runs initdb with checksums enabled
- Environment variables from ConfigMap and Secret
- Volume: emptyDir for /var/lib/postgresql/data
- Resource limits: 512Mi memory, 500m CPU
- Resource requests: 256Mi memory, 250m CPU

**Service (postgres-service):**
- Type: ClusterIP
- Port: 5432
- Selector: app=postgres

#### File: k8s/check-job.yaml
Create a Kubernetes Job manifest:

**ConfigMap (check-scripts):**
- Embed the check-data-checksums.sh script content
- Set defaultMode: 0755 for executability

**Job (checksum-check-job):**
- restartPolicy: Never
- Container image: postgres:15-alpine
- Command: Install bash, then run /scripts/check-data-checksums.sh
- Environment variables: DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD
- Mount check-scripts ConfigMap to /scripts

#### File: k8s/full-check-job.yaml
Similar to check-job.yaml but:
- Job name: full-consistency-check-job
- Runs check-consistency-full.sh script
- Environment variables to enable/disable checks:
  - RUN_CHECKSUMS (true)
  - RUN_INTEGRITY (true)
  - RUN_BLOAT (true)
  - RUN_VACUUM (false)
- Longer timeout (180s instead of 120s)

### 2. Shell Scripts

#### File: scripts/setup-minikube.sh
Bash script that:
1. Checks if minikube is installed, installs if needed
2. Checks if kubectl is installed, installs if needed
3. Starts minikube with: --driver=docker --memory=4096 --cpus=4
4. Waits for cluster to be ready
5. Displays minikube status

Key features:
- Use `set -e` for error handling
- Curl downloads for minikube and kubectl
- Conditional installation checks
- kubectl wait for node readiness

#### File: scripts/check-data-checksums.sh
Bash script that:
1. Sets color codes for output (RED, GREEN, YELLOW, NC)
2. Defines database connection parameters with defaults
3. Prints header banner
4. Waits for PostgreSQL to be ready (max 30 attempts, 2s sleep)
5. Runs `SHOW data_checksums;` query
6. Parses result and evaluates:
   - "on" → Exit 0 with green success message
   - "off" → Exit 1 with yellow warning message
   - Other → Exit 1 with red error message

Key features:
- Database readiness loop
- PGPASSWORD environment variable for authentication
- Color-coded output
- Clear success/failure indicators

#### File: scripts/check-consistency-full.sh
Extended bash script that runs multiple checks:
1. Data checksums check (same as basic)
2. Table/Index integrity check:
   - Count tables: `SELECT COUNT(*) FROM pg_catalog.pg_class WHERE relkind = 'r'`
   - Count indexes: `SELECT COUNT(*) FROM pg_catalog.pg_class WHERE relkind = 'i'`
   - List top 10 tables/indexes by size
3. Bloat analysis:
   - Database size: `SELECT pg_size_pretty(pg_database_size('database'))`
   - Top 10 largest tables
4. VACUUM recommendations (optional):
   - Query pg_stat_user_tables for autovacuum statistics

Features:
- Configurable checks via environment variables
- Pass/fail counters
- Summary statistics at end
- Detailed output for each check

#### File: scripts/deploy-and-check.sh
Orchestration script that:
1. Deploys PostgreSQL: `kubectl apply -f k8s/postgres-deployment.yaml`
2. Waits for pod readiness: `kubectl wait --for=condition=ready pod -l app=postgres`
3. Additional 60s sleep for database initialization
4. Deploys check job: `kubectl apply -f k8s/check-job.yaml`
5. Waits for job completion: `kubectl wait --for=condition=complete job/checksum-check-job`
6. Displays results: `kubectl logs job/checksum-check-job`
7. Shows deployment status

#### File: scripts/cleanup.sh
Cleanup script that:
1. Deletes check job and ConfigMap
2. Deletes PostgreSQL deployment, service, ConfigMap, and Secret
3. Shows remaining resources

Use `--ignore-not-found=true` for idempotent operations.

#### File: scripts/interactive-psql.sh
Interactive script that:
1. Finds the PostgreSQL pod
2. Presents menu of options:
   - Open psql interactive shell
   - Run SHOW data_checksums
   - Run SHOW all
   - Show PostgreSQL version
   - List databases
   - Exit
3. Executes chosen command using `kubectl exec`

#### File: scripts/validate.sh
Validation script that checks:
1. All required files exist
2. YAML files have valid syntax (using Python's yaml module)
3. Shell scripts have valid bash syntax (using bash -n)
4. Scripts are executable
5. Key configuration values are present (data_checksums=on, etc.)

### 3. Makefile

Create a Makefile with these targets:

- **help**: Display available commands
- **setup**: Run setup-minikube.sh
- **deploy**: Deploy PostgreSQL and wait for readiness
- **check**: Run basic consistency check
- **check-full**: Run full consistency check suite
- **all**: setup + deploy + check (complete workflow)
- **all-full**: setup + deploy + check-full
- **status**: Show pods, services, and jobs
- **cleanup**: Run cleanup.sh
- **clean**: cleanup + stop minikube

Use `.PHONY` for all targets.

### 4. Documentation Files

#### File: README.md (200+ lines)
Main documentation including:
1. Project title and overview
2. What are data checksums (explanation)
3. Prerequisites (GitHub Codespaces requirements)
4. Quick start guide with code examples
5. Expected output (basic and full checks)
6. Project structure tree
7. Manual deployment steps
8. Running checks directly in pods
9. Cleanup instructions
10. Customization options
11. Troubleshooting section
12. Contributing and license info

#### File: ARCHITECTURE.md (280+ lines)
Architecture documentation with:
1. ASCII architecture diagrams showing:
   - GitHub Codespaces → Minikube → Kubernetes components
   - Network communication flow
   - Data flow from user commands to results
2. Component descriptions (ConfigMap, Secret, Deployment, Service, Job)
3. Execution flow diagrams for each phase
4. File structure explanation
5. Security considerations
6. Scalability notes
7. Extension points

#### File: CHECKSUMS.md (195+ lines)
Deep dive on data checksums:
1. What are data checksums
2. Why they're important (corruption detection)
3. The SHOW data_checksums query explained
4. How the check works (flow diagram)
5. Performance impact (~5% write, ~2% read)
6. Important notes about enabling checksums
7. What happens when corruption is detected
8. Best practices
9. Implementation details
10. Testing instructions
11. Additional resources

#### File: QUICKSTART.md (188+ lines)
Quick start guide with:
1. Prerequisites
2. One-command setup: `make all`
3. Step-by-step manual setup
4. Expected outputs at each stage
5. Verification steps
6. Cleanup commands
7. Troubleshooting tips
8. What's happening under the hood
9. Next steps
10. Common commands reference

#### File: EXAMPLES.md (410+ lines)
Sample outputs document:
1. Setup output (Minikube starting)
2. Deployment output (resources created)
3. Makefile usage examples
4. Interactive psql output examples
5. Validation output
6. Manual kubectl commands and their outputs
7. Cleanup output
8. Different check scenarios:
   - Checksums enabled (success)
   - Checksums disabled (warning)
   - Database connection failed (error)
9. Summary of features

#### File: FULL_CHECK.md (297+ lines)
Full consistency check documentation:
1. Overview of all four checks
2. SQL queries used for each check
3. Usage instructions (Makefile, kubectl, scripts)
4. Configuration options (environment variables)
5. Expected output for successful run
6. Performance considerations
7. Comparison table: basic vs full check
8. When to use each check
9. Troubleshooting
10. Adding custom checks (with code template)

#### File: PROJECT_SUMMARY.md (235+ lines)
Project summary including:
1. What was built
2. Key features checklist
3. Project structure tree
4. Core components description
5. How it works (4-phase workflow)
6. The check explanation
7. Usage examples
8. Validation information
9. CI/CD integration details
10. Production readiness assessment
11. Technical highlights
12. Files created table
13. Key achievements list
14. Testing details
15. Next steps for users
16. Conclusion

#### File: .gitignore
Standard Git ignore patterns:
- Log files (*.log)
- OS files (.DS_Store, Thumbs.db)
- Editor files (.vscode/, .idea/, *.swp)
- Temporary files (/tmp/, *.tmp)
- Kubernetes files (*.kubeconfig)
- Environment files (.env, .env.local)

### 5. GitHub Actions CI/CD

#### File: .github/workflows/ci.yaml
Create a CI workflow with two jobs:

**Job 1: validate**
- Runs on: ubuntu-latest
- Steps:
  1. Checkout code
  2. Setup Python 3.x
  3. Install PyYAML
  4. Make scripts executable
  5. Run validation script

**Job 2: test-consistency-check**
- Depends on: validate
- Runs on: ubuntu-latest
- Steps:
  1. Checkout code
  2. Start Minikube (4GB RAM, 4 CPUs)
  3. Verify Minikube
  4. Deploy PostgreSQL
  5. Wait 60s for initialization
  6. Show deployment status
  7. Run consistency check
  8. Show check results
  9. Verify check passed (check job succeeded)
  10. Cleanup (always run)

Triggers:
- Push to main/develop branches
- Pull requests to main/develop
- Manual workflow_dispatch

## Key Technical Details

### Data Checksums
- Enable during initialization with `-c data_checksums=on` argument
  - This works when the data directory is empty (first startup)
  - PostgreSQL passes this to initdb during initial cluster creation
- Cannot be enabled on existing clusters without reinitializing
- SQL command: `SHOW data_checksums;`
- Returns "on" or "off"
- ~5% write overhead, ~2% read overhead

### Database Connection
- Host: postgres-service (Kubernetes service name)
- Port: 5432
- Database: testdb
- User: postgres
- Password: [CHANGE-ME-IN-PRODUCTION] (stored in Secret)
  - **SECURITY WARNING**: Never use simple passwords like "postgres123" in production
  - Example uses "postgres123" for demonstration only
  - Generate strong passwords for production deployments

### Color Coding
Use ANSI escape codes in bash scripts:
- GREEN: '\033[0;32m' (success)
- RED: '\033[0;31m' (error)
- YELLOW: '\033[1;33m' (warning)
- NC: '\033[0m' (no color/reset)

### Kubernetes Best Practices
1. Use ConfigMaps for non-sensitive data
2. Use Secrets for passwords
3. Set resource limits and requests
4. Use ClusterIP for internal services
5. Set appropriate labels for all resources
6. Use kubectl wait for readiness
7. Set restartPolicy: Never for Jobs

### Script Best Practices
1. Start with shebang: #!/bin/bash
2. Use `set -e` for error handling
3. Provide default values for environment variables
4. Use meaningful variable names in UPPERCASE
5. Add comments for complex logic
6. Print clear, user-friendly output
7. Exit with appropriate codes (0=success, 1=failure)

## Development Workflow

1. **Local Development**:
   - Clone repository
   - Run `./scripts/validate.sh` to verify setup
   - Run `make all` to deploy and test

2. **Testing Changes**:
   - Modify files as needed
   - Run validation
   - Test deployment
   - Verify check results

3. **CI/CD**:
   - Push to GitHub
   - GitHub Actions automatically validates and tests
   - Review CI results

4. **Cleanup**:
   - Run `make cleanup` to remove resources
   - Run `minikube stop` or `make clean` to stop cluster

## Expected Outcomes

### Successful Basic Check Output
```
======================================
EDB Consistency Check - Data Checksums
======================================

✓ Database is ready

Running consistency check: SHOW data_checksums
--------------------------------------
Result: on

✓ PASS: Data checksums are ENABLED
  This means PostgreSQL will detect data corruption by verifying checksums
  on data pages when they are read from disk.
```

### Successful Full Check Output
```
==========================================
EDB Full Consistency Check Suite
==========================================

Check 1: Data Checksums (Safe)
Check 2: Table/Index Integrity
Check 3: Table Bloat Analysis
Check 4: VACUUM Recommendations

Checks passed:        3
Checks with warnings: 0
Checks failed:        0

✓ All checks passed successfully!
```

## Success Criteria

The project is complete when:
- ✅ All files are created with correct content
- ✅ Validation script passes all checks
- ✅ Minikube can be set up successfully
- ✅ PostgreSQL deploys with checksums enabled
- ✅ Basic consistency check runs and passes
- ✅ Full consistency check runs and passes
- ✅ All scripts are executable and working
- ✅ Documentation is comprehensive and accurate
- ✅ CI/CD pipeline passes all tests
- ✅ Cleanup works correctly

## Total Project Scope

- **Kubernetes Manifests**: 3 files, ~300 lines
- **Shell Scripts**: 7 files, ~800 lines
- **Documentation**: 6 markdown files, ~2000 lines
- **Build Automation**: 1 Makefile, ~76 lines
- **CI/CD**: 1 GitHub Actions workflow, ~102 lines
- **Total**: ~3,278 lines of code and documentation across 18 files

## Special Considerations

1. **Resource Requirements**: Ensure sufficient resources for Minikube (4GB RAM, 4 CPUs recommended)
2. **Database Initialization**: Wait 60 seconds after pod ready for full initialization
3. **Job Idempotency**: Delete existing jobs before recreating with same name
4. **Security**: 
   - Use Secrets for passwords, never hardcode credentials in code
   - The example password "postgres123" is for demonstration only
   - Generate strong, random passwords for any real deployment
   - Never commit production credentials to version control
5. **Portability**: Works in GitHub Codespaces, local Docker, or any Kubernetes cluster
6. **Production Use**: This is a development/testing setup; production would need:
   - Persistent volumes (not emptyDir)
   - Strong, randomly generated passwords
   - High availability configuration
   - Monitoring and alerting
   - Regular backups
   - SSL/TLS encryption

## Usage Examples

### Quickest Start (One Command)
```bash
make all
```

### Step-by-Step
```bash
./scripts/setup-minikube.sh
./scripts/deploy-and-check.sh
```

### Full Check Suite
```bash
make all-full
```

### Manual Kubernetes
```bash
kubectl apply -f k8s/postgres-deployment.yaml
kubectl wait --for=condition=ready pod -l app=postgres --timeout=120s
sleep 60
kubectl apply -f k8s/check-job.yaml
kubectl logs job/checksum-check-job
```

### Cleanup
```bash
make cleanup  # Remove resources only
make clean    # Remove resources and stop Minikube
```

## Extension Ideas

1. Add more consistency checks (replication lag, connection count, etc.)
2. Convert Job to CronJob for scheduled checks
3. Add monitoring integration (Prometheus metrics)
4. Add alerting (email, Slack notifications)
5. Support multiple PostgreSQL versions
6. Add persistent volumes for data retention
7. Implement high availability setup
8. Add backup verification checks

## References

- PostgreSQL Documentation: https://www.postgresql.org/docs/
- Kubernetes Documentation: https://kubernetes.io/docs/
- Minikube Documentation: https://minikube.sigs.k8s.io/docs/
- GitHub Actions Documentation: https://docs.github.com/en/actions

## Final Notes

This project demonstrates best practices for:
- Kubernetes deployments
- Database consistency checking
- Shell script automation
- Documentation
- CI/CD integration
- Security and resource management

The entire system is designed to be educational, production-ready in pattern, and easily adaptable to real-world scenarios. All checks are safe and read-only, making them suitable for production environments with appropriate resource allocation.
