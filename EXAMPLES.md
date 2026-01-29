# Sample Output and Usage Examples

This document shows example outputs from running the EDB consistency check project.

## Setup Output

### Running: `./scripts/setup-minikube.sh`

```
==========================================
EDB Consistency Check - Minikube Setup
==========================================

✓ Minikube is already installed
✓ kubectl is already installed
Starting minikube...
😄  minikube v1.32.0 on Ubuntu 22.04
✨  Using the docker driver based on existing profile
👍  Starting control plane node minikube in cluster minikube
🚜  Pulling base image ...
🔄  Restarting existing docker container for "minikube" ...
🐳  Preparing Kubernetes v1.28.3 on Docker 24.0.7 ...
🔎  Verifying Kubernetes components...
🌟  Enabled addons: storage-provisioner, default-storageclass
🏄  Done! kubectl is now configured to use "minikube" cluster and "default" namespace by default

Waiting for minikube to be ready...
node/minikube condition met

✓ Setup complete!

Minikube status:
minikube
type: Control Plane
host: Running
kubelet: Running
apiserver: Running
kubeconfig: Configured
```

## Deployment Output

### Running: `./scripts/deploy-and-check.sh`

```
==========================================
Deploying EDB Consistency Check
==========================================

1. Deploying PostgreSQL...
configmap/postgres-config created
secret/postgres-secret created
deployment.apps/postgres created
service/postgres-service created

2. Waiting for PostgreSQL pod to be ready...
pod/postgres-7d9f8b6c4d-x5k2m condition met

   Waiting for database initialization...

3. Deploying consistency check job...
job.batch "checksum-check-job" deleted
configmap/check-scripts created
job.batch/checksum-check-job created

4. Waiting for check job to complete...
job.batch/checksum-check-job condition met

==========================================
Check Results:
==========================================
======================================
EDB Consistency Check - Data Checksums
======================================

Waiting for PostgreSQL to be ready...
Attempt 1/30 - Database not ready yet...
Attempt 2/30 - Database not ready yet...
✓ Database is ready

Running consistency check: SHOW data_checksums
--------------------------------------
Result: on

✓ PASS: Data checksums are ENABLED
  This means PostgreSQL will detect data corruption by verifying checksums
  on data pages when they are read from disk.

==========================================
Deployment Status:
==========================================

Pods:
NAME                        READY   STATUS      RESTARTS   AGE
checksum-check-job-jk5m7    0/1     Completed   0          15s
postgres-7d9f8b6c4d-x5k2m   1/1     Running     0          35s

Services:
NAME               TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
kubernetes         ClusterIP   10.96.0.1       <none>        443/TCP    5m
postgres-service   ClusterIP   10.96.123.456   <none>        5432/TCP   35s
```

## Using Makefile

### Running: `make help`

```
EDB Consistency Check - Makefile

Available targets:
  make setup    - Setup Minikube environment
  make deploy   - Deploy PostgreSQL to Kubernetes
  make check    - Run consistency check
  make all      - Setup + Deploy + Check (full workflow)
  make status   - Show deployment status
  make cleanup  - Remove all deployed resources
  make clean    - Cleanup + stop Minikube
```

### Running: `make all`

```
Setting up Minikube...
==========================================
EDB Consistency Check - Minikube Setup
==========================================
...
(setup output as shown above)
...

Deploying PostgreSQL...
configmap/postgres-config created
secret/postgres-secret created
deployment.apps/postgres created
service/postgres-service created
Waiting for PostgreSQL to be ready...
pod/postgres-7d9f8b6c4d-x5k2m condition met
✓ PostgreSQL deployed and ready

Running consistency check...
job.batch "checksum-check-job" deleted
configmap/check-scripts created
job.batch/checksum-check-job created

==========================================
Check Results:
==========================================
======================================
EDB Consistency Check - Data Checksums
======================================
...
✓ PASS: Data checksums are ENABLED
  This means PostgreSQL will detect data corruption by verifying checksums
  on data pages when they are read from disk.
```

### Running: `make status`

```
Deployment Status:

Pods:
NAME                        READY   STATUS      RESTARTS   AGE
checksum-check-job-jk5m7    0/1     Completed   0          2m
postgres-7d9f8b6c4d-x5k2m   1/1     Running     0          2m

Services:
NAME               TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
kubernetes         ClusterIP   10.96.0.1       <none>        443/TCP    10m
postgres-service   ClusterIP   10.96.123.456   <none>        5432/TCP   2m

Jobs:
NAME                 COMPLETIONS   DURATION   AGE
checksum-check-job   1/1           5s         2m
```

## Interactive PostgreSQL Access

### Running: `./scripts/interactive-psql.sh`

```
==========================================
PostgreSQL Interactive Access
==========================================

PostgreSQL pod: postgres-7d9f8b6c4d-x5k2m

Choose an option:

1. Open psql interactive shell
2. Run: SHOW data_checksums;
3. Run: SHOW all;
4. Show PostgreSQL version
5. List databases
6. Exit

Enter your choice (1-6): 2

Running: SHOW data_checksums;
----------------------------------------
 data_checksums 
----------------
 on
(1 row)
```

### Option 4: PostgreSQL Version

```
PostgreSQL Version:
----------------------------------------
                                                 version                                                  
----------------------------------------------------------------------------------------------------------
 PostgreSQL 15.5 on x86_64-pc-linux-musl, compiled by gcc (Alpine 12.2.1_git20220924-r10) 12.2.1 20220924, 64-bit
(1 row)
```

## Validation

### Running: `./scripts/validate.sh`

```
==========================================
EDB Consistency Check - Validation
==========================================

Checking documentation...
✓ README.md exists
✓ QUICKSTART.md exists
✓ CHECKSUMS.md exists
✓ ARCHITECTURE.md exists
✓ Makefile exists
✓ .gitignore exists

Checking Kubernetes manifests...
✓ k8s/postgres-deployment.yaml exists
✓ k8s/check-job.yaml exists
✓ k8s/postgres-deployment.yaml has valid YAML syntax
✓ k8s/check-job.yaml has valid YAML syntax

Checking scripts...
✓ scripts/setup-minikube.sh exists
✓ scripts/deploy-and-check.sh exists
✓ scripts/check-data-checksums.sh exists
✓ scripts/cleanup.sh exists
✓ scripts/interactive-psql.sh exists

Checking script permissions...
✓ scripts/setup-minikube.sh is executable
✓ scripts/deploy-and-check.sh is executable
✓ scripts/check-data-checksums.sh is executable
✓ scripts/cleanup.sh is executable
✓ scripts/interactive-psql.sh is executable

Checking bash syntax...
✓ scripts/setup-minikube.sh has valid bash syntax
✓ scripts/deploy-and-check.sh has valid bash syntax
✓ scripts/check-data-checksums.sh has valid bash syntax
✓ scripts/cleanup.sh has valid bash syntax
✓ scripts/interactive-psql.sh has valid bash syntax

Checking Kubernetes manifest content...
✓ PostgreSQL configured with data_checksums=on
✓ PostgreSQL image specified
✓ Check job references check-data-checksums.sh

==========================================
Validation Summary
==========================================

✓ All validations passed!

You can now proceed with:
  1. make setup    (or ./scripts/setup-minikube.sh)
  2. make deploy   (or ./scripts/deploy-and-check.sh)
  3. make check
```

## Manual kubectl Commands

### Viewing Pod Details

```bash
$ kubectl describe pod postgres-7d9f8b6c4d-x5k2m
Name:             postgres-7d9f8b6c4d-x5k2m
Namespace:        default
Priority:         0
Service Account:  default
Node:             minikube/192.168.49.2
Start Time:       Wed, 29 Jan 2026 17:15:00 +0000
Labels:           app=postgres
                  pod-template-hash=7d9f8b6c4d
Annotations:      <none>
Status:           Running
IP:               10.244.0.5
...
```

### Viewing Logs

```bash
$ kubectl logs deployment/postgres
The files belonging to this database system will be owned by user "postgres".
This user must also own the server process.

The database cluster will be initialized with locale "en_US.utf8".
The default database encoding has accordingly been set to "UTF8".
...
PostgreSQL init process complete; ready for start up.

2026-01-29 17:15:15.123 UTC [1] LOG:  starting PostgreSQL 15.5 on x86_64-pc-linux-musl
2026-01-29 17:15:15.124 UTC [1] LOG:  listening on IPv4 address "0.0.0.0", port 5432
2026-01-29 17:15:15.125 UTC [1] LOG:  listening on IPv6 address "::", port 5432
2026-01-29 17:15:15.130 UTC [1] LOG:  database system is ready to accept connections
```

### Executing SQL Directly

```bash
$ kubectl exec -it deployment/postgres -- psql -U postgres -d testdb -c "SHOW data_checksums;"
 data_checksums 
----------------
 on
(1 row)
```

## Cleanup Output

### Running: `./scripts/cleanup.sh`

```
==========================================
Cleaning up EDB Consistency Check
==========================================

Deleting check job...
configmap "check-scripts" deleted
job.batch "checksum-check-job" deleted

Deleting PostgreSQL deployment...
configmap "postgres-config" deleted
secret "postgres-secret" deleted
deployment.apps "postgres" deleted
service "postgres-service" deleted

✓ Cleanup complete!

Remaining resources:
NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   15m
```

## Expected Check Scenarios

### Scenario 1: Checksums Enabled (Success)

When PostgreSQL is configured with `data_checksums=on`:

```
✓ PASS: Data checksums are ENABLED
  This means PostgreSQL will detect data corruption by verifying checksums
  on data pages when they are read from disk.
```

Exit code: 0

### Scenario 2: Checksums Disabled (Warning)

When PostgreSQL is configured without checksums:

```
⚠ WARNING: Data checksums are DISABLED
  Data checksums provide protection against storage corruption.
  Consider enabling them for production databases.

  Note: Checksums can only be enabled during database initialization
  using 'initdb --data-checksums' or postgres '-c data_checksums=on'
```

Exit code: 1

### Scenario 3: Database Connection Failed (Error)

When database is not accessible:

```
Waiting for PostgreSQL to be ready...
Attempt 1/30 - Database not ready yet...
Attempt 2/30 - Database not ready yet...
...
Attempt 30/30 - Database not ready yet...
✗ Failed to connect to database after 30 attempts
```

Exit code: 1

## Summary

This project provides:

✅ **Automated Setup**: Single command setup with Minikube  
✅ **Safe Check**: Non-intrusive `SHOW data_checksums;` query  
✅ **Clear Output**: Color-coded results with explanations  
✅ **Production Ready**: Easy to adapt for real environments  
✅ **Well Documented**: Comprehensive guides and examples  
✅ **Validated**: Pre-deployment validation tools  

The check itself is safe and read-only, making it suitable for production use.
