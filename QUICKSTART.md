# Quick Start Guide

This guide will help you get the EDB Consistency Check running in minutes.

## One-Command Setup

For the fastest setup, use the Makefile:

```bash
make all
```

This will:
1. Setup Minikube
2. Deploy PostgreSQL
3. Run the consistency check
4. Show results

## Step-by-Step Setup

### 1. Ensure you're in the project directory

```bash
cd edb-consistency-check
```

### 2. Make scripts executable (if not already)

```bash
chmod +x scripts/*.sh
```

### 3. Setup Minikube

```bash
./scripts/setup-minikube.sh
```

Or:
```bash
make setup
```

**Expected output:**
- Minikube installation (if needed)
- kubectl installation (if needed)
- Minikube started
- Cluster ready

### 4. Deploy and Check

```bash
./scripts/deploy-and-check.sh
```

Or:
```bash
make deploy
make check
```

**Expected output:**
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

### 5. Verify Deployment

```bash
make status
```

**Expected output:**
```
Deployment Status:

Pods:
NAME                        READY   STATUS      RESTARTS   AGE
checksum-check-job-xxxxx    0/1     Completed   0          1m
postgres-xxxxxxxxxx-xxxxx   1/1     Running     0          2m

Services:
NAME               TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
postgres-service   ClusterIP   10.96.xxx.xxx   <none>        5432/TCP   2m
```

## Cleanup

```bash
make cleanup
```

Or to stop Minikube as well:
```bash
make clean
```

## Troubleshooting

### Issue: Minikube fails to start

**Solution:**
```bash
minikube delete
minikube start --driver=docker --memory=2048 --cpus=2
```

### Issue: Check job shows "CrashLoopBackOff"

**Solution:** Check the logs:
```bash
kubectl logs job/checksum-check-job
kubectl describe job checksum-check-job
```

### Issue: PostgreSQL not starting

**Solution:** Check pod status and logs:
```bash
kubectl get pods -l app=postgres
kubectl describe pod <postgres-pod-name>
kubectl logs <postgres-pod-name>
```

## What's Happening Under the Hood?

1. **Minikube Setup**: Creates a local Kubernetes cluster
2. **PostgreSQL Deployment**: 
   - Creates ConfigMap with database settings
   - Creates Secret with password
   - Deploys PostgreSQL container with `data_checksums=on`
   - Exposes it via ClusterIP service
3. **Check Job**:
   - Waits for database to be ready
   - Connects to PostgreSQL
   - Runs `SHOW data_checksums;`
   - Evaluates and reports the result

## Next Steps

- Modify PostgreSQL settings in `k8s/postgres-deployment.yaml`
- Add more consistency checks in `scripts/check-data-checksums.sh`
- Integrate with CI/CD pipelines
- Add monitoring and alerting

## Common Commands

```bash
# View all resources
kubectl get all

# View pod logs
kubectl logs <pod-name>

# Access PostgreSQL directly
kubectl exec -it deployment/postgres -- psql -U postgres -d testdb

# Run SQL command directly
kubectl exec -it deployment/postgres -- psql -U postgres -d testdb -c "SHOW data_checksums;"

# Delete and restart everything
make cleanup
make deploy
make check
```
