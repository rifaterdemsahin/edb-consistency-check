# EDB Consistency Check

A PostgreSQL/EnterpriseDB consistency checking tool that runs on Minikube in GitHub Codespaces. This project provides both basic and comprehensive consistency checks to detect potential storage corruption and database health issues.

## Overview

This project provides:
- **Basic Check**: Quick data checksums verification
- **Full Check Suite**: Comprehensive checks including data checksums, table/index integrity, bloat analysis, and VACUUM recommendations
- Kubernetes deployment configurations for PostgreSQL with data checksums enabled
- Automated consistency check scripts
- Easy setup for GitHub Codespaces environment with Minikube

## What are Data Checksums?

Data checksums in PostgreSQL are a feature that helps detect data corruption. When enabled:
- PostgreSQL calculates a checksum for each data page when writing to disk
- When reading data pages, PostgreSQL verifies the checksum
- Any mismatch indicates potential data corruption from storage failures

**Note**: Data checksums can only be enabled during database initialization using `initdb --data-checksums` or the postgres argument `-c data_checksums=on`.

## Prerequisites

- GitHub Codespaces (4-core or larger machine type recommended) or a Linux environment with Docker
- At least 4GB of available RAM (for Minikube with 4GB allocation)
- At least 4 CPU cores available
- Internet connection for downloading container images

## Quick Start

### 1. Setup Minikube

First, set up Minikube in your environment:

```bash
chmod +x scripts/*.sh
./scripts/setup-minikube.sh
```

This script will:
- Install Minikube (if not already installed)
- Install kubectl (if not already installed)
- Start Minikube with appropriate resources
- Verify the cluster is ready

### 2. Deploy and Run Check

Deploy PostgreSQL and run the basic consistency check:

```bash
./scripts/deploy-and-check.sh
```

Or run the full consistency check suite:

```bash
make deploy
make check-full
```

This will:
- Deploy PostgreSQL with data checksums enabled
- Wait for the database to be ready
- Run the consistency check job(s)
- Display the results

### 3. Expected Output

#### Basic Check (Data Checksums Only)

When checksums are enabled (which they are in this setup), you should see:

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

#### Full Check Suite

The full check runs multiple checks and provides comprehensive output:

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

See [FULL_CHECK.md](FULL_CHECK.md) for detailed information on the full check suite.

## Project Structure

```
edb-consistency-check/
├── k8s/
│   ├── postgres-deployment.yaml  # PostgreSQL deployment with checksums enabled
│   └── check-job.yaml           # Kubernetes Job for running checks
├── scripts/
│   ├── setup-minikube.sh        # Setup Minikube environment
│   ├── deploy-and-check.sh      # Deploy and run consistency check
│   ├── check-data-checksums.sh  # Standalone check script
│   └── cleanup.sh               # Clean up all resources
└── README.md
```

## Manual Steps

If you prefer to run steps manually:

### Start Minikube

```bash
minikube start --driver=docker --memory=2048 --cpus=2
```

### Deploy PostgreSQL

```bash
kubectl apply -f k8s/postgres-deployment.yaml
kubectl wait --for=condition=ready pod -l app=postgres --timeout=120s
```

### Run the Consistency Check

```bash
kubectl apply -f k8s/check-job.yaml
kubectl wait --for=condition=complete job/checksum-check-job --timeout=120s
kubectl logs job/checksum-check-job
```

### Check Deployment Status

```bash
kubectl get pods
kubectl get services
kubectl get jobs
```

## Running the Check Directly in a Pod

You can also run the check script directly in a pod:

```bash
# Copy the script to a running pod
kubectl cp scripts/check-data-checksums.sh postgres-<pod-id>:/tmp/

# Exec into the pod and run it
kubectl exec -it postgres-<pod-id> -- bash /tmp/check-data-checksums.sh
```

Or run it directly:

```bash
kubectl exec -it deployment/postgres -- bash -c "
export DB_HOST=localhost
export DB_NAME=testdb
export DB_USER=postgres
export DB_PASSWORD=postgres123
PGPASSWORD=\$DB_PASSWORD psql -h localhost -U postgres -d testdb -c 'SHOW data_checksums;'
"
```

## Cleanup

To remove all deployed resources:

```bash
./scripts/cleanup.sh
```

Or manually:

```bash
kubectl delete -f k8s/check-job.yaml
kubectl delete -f k8s/postgres-deployment.yaml
```

To stop Minikube:

```bash
minikube stop
```

To delete the Minikube cluster:

```bash
minikube delete
```

## Customization

### Using Different PostgreSQL Versions

Edit `k8s/postgres-deployment.yaml` and change the image:

```yaml
image: postgres:14-alpine  # or postgres:16-alpine, etc.
```

### Disabling Checksums (for testing)

Remove or modify the args in `k8s/postgres-deployment.yaml`:

```yaml
# Remove this line to disable checksums
args: ["-c", "data_checksums=on"]
```

### Changing Database Credentials

Edit the ConfigMap and Secret in `k8s/postgres-deployment.yaml`:

```yaml
data:
  POSTGRES_DB: your_database
  POSTGRES_USER: your_user
stringData:
  POSTGRES_PASSWORD: your_password
```

## Troubleshooting

### Minikube won't start

Try deleting and recreating:
```bash
minikube delete
minikube start --driver=docker --memory=2048 --cpus=2
```

### Pod is stuck in Pending

Check available resources:
```bash
kubectl describe pod postgres-<pod-id>
minikube status
```

### Check job failed

View logs:
```bash
kubectl logs job/checksum-check-job
kubectl describe job checksum-check-job
```

### Database connection issues

Check if PostgreSQL is running:
```bash
kubectl get pods -l app=postgres
kubectl logs deployment/postgres
```

## Contributing

Feel free to submit issues and enhancement requests!

## License

This project is provided as-is for educational and testing purposes.