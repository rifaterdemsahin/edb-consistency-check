# Project Architecture

## Overview

This project demonstrates how to run PostgreSQL consistency checks in a Kubernetes environment using Minikube in GitHub Codespaces.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     GitHub Codespaces                            │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    Minikube Cluster                         │ │
│  │                                                              │ │
│  │  ┌──────────────────────────────────────────────────────┐  │ │
│  │  │              Kubernetes Resources                     │  │ │
│  │  │                                                        │  │ │
│  │  │  ┌─────────────────────────────────────────────────┐ │  │ │
│  │  │  │        ConfigMap: postgres-config               │ │  │ │
│  │  │  │  - POSTGRES_DB: testdb                          │ │  │ │
│  │  │  │  - POSTGRES_USER: postgres                      │ │  │ │
│  │  │  └─────────────────────────────────────────────────┘ │  │ │
│  │  │                                                        │  │ │
│  │  │  ┌─────────────────────────────────────────────────┐ │  │ │
│  │  │  │        Secret: postgres-secret                  │ │  │ │
│  │  │  │  - POSTGRES_PASSWORD: (encrypted)               │ │  │ │
│  │  │  └─────────────────────────────────────────────────┘ │  │ │
│  │  │                                                        │  │ │
│  │  │  ┌─────────────────────────────────────────────────┐ │  │ │
│  │  │  │        Deployment: postgres                     │ │  │ │
│  │  │  │                                                  │ │  │ │
│  │  │  │  ┌────────────────────────────────────────────┐ │ │  │ │
│  │  │  │  │  Pod: postgres-xxxxx                       │ │ │  │ │
│  │  │  │  │                                            │ │ │  │ │
│  │  │  │  │  Container: postgres:15-alpine             │ │ │  │ │
│  │  │  │  │  Args: ["-c", "data_checksums=on"]         │ │ │  │ │
│  │  │  │  │  Port: 5432                                │ │ │  │ │
│  │  │  │  │                                            │ │ │  │ │
│  │  │  │  │  Volume: postgres-storage (emptyDir)       │ │ │  │ │
│  │  │  │  └────────────────────────────────────────────┘ │ │  │ │
│  │  │  └─────────────────────────────────────────────────┘ │  │ │
│  │  │                         │                             │  │ │
│  │  │                         │ Exposes                     │  │ │
│  │  │                         ▼                             │  │ │
│  │  │  ┌─────────────────────────────────────────────────┐ │  │ │
│  │  │  │        Service: postgres-service                │ │  │ │
│  │  │  │  Type: ClusterIP                                │ │  │ │
│  │  │  │  Port: 5432 → 5432                              │ │  │ │
│  │  │  └─────────────────────────────────────────────────┘ │  │ │
│  │  │                         │                             │  │ │
│  │  │                         │ Used by                     │  │ │
│  │  │                         ▼                             │  │ │
│  │  │  ┌─────────────────────────────────────────────────┐ │  │ │
│  │  │  │        ConfigMap: check-scripts                 │ │  │ │
│  │  │  │  - check-data-checksums.sh                      │ │  │ │
│  │  │  └─────────────────────────────────────────────────┘ │  │ │
│  │  │                         │                             │  │ │
│  │  │                         │ Mounted by                  │  │ │
│  │  │                         ▼                             │  │ │
│  │  │  ┌─────────────────────────────────────────────────┐ │  │ │
│  │  │  │        Job: checksum-check-job                  │ │  │ │
│  │  │  │                                                  │ │  │ │
│  │  │  │  ┌────────────────────────────────────────────┐ │ │  │ │
│  │  │  │  │  Pod: checksum-check-job-xxxxx             │ │ │  │ │
│  │  │  │  │                                            │ │ │  │ │
│  │  │  │  │  Container: postgres:15-alpine             │ │ │  │ │
│  │  │  │  │  Command: /scripts/check-data-checksums.sh │ │ │  │ │
│  │  │  │  │                                            │ │ │  │ │
│  │  │  │  │  Connects to: postgres-service:5432        │ │ │  │ │
│  │  │  │  │  Runs: SHOW data_checksums;                │ │ │  │ │
│  │  │  │  └────────────────────────────────────────────┘ │ │  │ │
│  │  │  └─────────────────────────────────────────────────┘ │  │ │
│  │  └────────────────────────────────────────────────────────┘  │ │
│  └──────────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────────┘
```

## Component Descriptions

### 1. GitHub Codespaces
- Cloud-based development environment
- Provides Docker runtime for Minikube
- Accessible via browser or local VS Code

### 2. Minikube
- Local Kubernetes cluster
- Runs in Docker container
- Provides single-node cluster for testing

### 3. PostgreSQL Deployment

#### ConfigMap (postgres-config)
- Stores non-sensitive configuration
- Database name, username

#### Secret (postgres-secret)
- Stores sensitive data (password)
- Base64 encoded in Kubernetes

#### Deployment (postgres)
- Manages PostgreSQL pod lifecycle
- Ensures 1 replica is always running
- Configures resource limits
- Enables data checksums via args

#### Service (postgres-service)
- Provides stable network endpoint
- ClusterIP for internal access only
- Maps port 5432 to PostgreSQL

### 4. Consistency Check Job

#### ConfigMap (check-scripts)
- Contains the check script
- Mounted as executable in Job pod

#### Job (checksum-check-job)
- Runs check script once
- Completes when check finishes
- Can be re-run by deleting and recreating

## Data Flow

```
1. User runs: make deploy
   │
   ├─→ Creates ConfigMap & Secret
   ├─→ Creates Deployment
   │   └─→ Starts PostgreSQL pod
   │       └─→ Initializes with data_checksums=on
   └─→ Creates Service
       └─→ Makes PostgreSQL accessible at postgres-service:5432

2. User runs: make check
   │
   ├─→ Creates ConfigMap with check script
   ├─→ Creates Job
   │   └─→ Starts checker pod
   │       ├─→ Waits for database ready
   │       ├─→ Connects to postgres-service:5432
   │       ├─→ Runs: SHOW data_checksums;
   │       ├─→ Parses result (on/off)
   │       └─→ Reports success/warning
   └─→ Job completes
       └─→ Logs contain check results
```

## Network Communication

```
┌─────────────────────┐
│   Checker Pod       │
│  (Job Container)    │
└──────────┬──────────┘
           │
           │ Connection Request
           │ postgres-service:5432
           │
           ▼
┌─────────────────────┐
│ Kubernetes Service  │
│  postgres-service   │
│   (ClusterIP)       │
└──────────┬──────────┘
           │
           │ Routes to
           │ Pod IP:5432
           │
           ▼
┌─────────────────────┐
│  PostgreSQL Pod     │
│  postgres-xxxxx     │
│  Listening on       │
│  0.0.0.0:5432       │
└─────────────────────┘
```

## File Structure

```
edb-consistency-check/
├── README.md                      # Main documentation
├── QUICKSTART.md                  # Quick start guide
├── CHECKSUMS.md                   # Deep dive on checksums
├── ARCHITECTURE.md                # This file
├── Makefile                       # Convenience commands
├── .gitignore                     # Git ignore rules
│
├── k8s/                           # Kubernetes manifests
│   ├── postgres-deployment.yaml   # PostgreSQL resources
│   └── check-job.yaml             # Check job resources
│
└── scripts/                       # Shell scripts
    ├── setup-minikube.sh          # Install and start Minikube
    ├── deploy-and-check.sh        # Full deployment workflow
    ├── check-data-checksums.sh    # Standalone check script
    ├── cleanup.sh                 # Remove all resources
    └── interactive-psql.sh        # Interactive database access
```

## Execution Flow

### Setup Phase
```bash
./scripts/setup-minikube.sh
```
1. Check if minikube installed → Install if needed
2. Check if kubectl installed → Install if needed
3. Start minikube cluster
4. Wait for node ready

### Deploy Phase
```bash
kubectl apply -f k8s/postgres-deployment.yaml
```
1. Create ConfigMap
2. Create Secret
3. Create Deployment
   - Pull postgres:15-alpine image
   - Initialize PostgreSQL with data_checksums=on
   - Start accepting connections
4. Create Service
   - Expose PostgreSQL internally

### Check Phase
```bash
kubectl apply -f k8s/check-job.yaml
```
1. Create check-scripts ConfigMap
2. Create Job
   - Pull postgres:15-alpine image (client tools)
   - Mount check script
   - Wait for PostgreSQL ready
   - Run SHOW data_checksums;
   - Parse and report result
3. Job completes
4. View logs for results

### Cleanup Phase
```bash
./scripts/cleanup.sh
```
1. Delete Job
2. Delete Deployment (terminates pods)
3. Delete Service
4. Delete ConfigMaps
5. Delete Secrets

## Security Considerations

1. **Secrets**: Password stored in Kubernetes Secret
2. **Network**: ClusterIP service (internal only)
3. **Resources**: Memory and CPU limits applied
4. **Credentials**: Not hardcoded in deployment (use env vars)

## Scalability Notes

This is a **single-node, single-replica** setup suitable for:
- Development
- Testing
- Learning
- CI/CD checks

For production, you would need:
- Persistent volumes (not emptyDir)
- High availability (replicas)
- Monitoring and alerting
- Backup and recovery
- Network policies
- Resource scaling

## Extension Points

1. **Add More Checks**: Extend check-job.yaml to run multiple checks
2. **Schedule Regular Checks**: Convert Job to CronJob
3. **Monitoring Integration**: Export metrics to Prometheus
4. **Alert on Failures**: Integrate with alerting system
5. **Multi-Database**: Check multiple databases
6. **Report Generation**: Save results to persistent storage
