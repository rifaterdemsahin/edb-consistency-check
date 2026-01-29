#!/bin/bash

# Deploy PostgreSQL and run consistency check
# This script deploys everything and runs the check

set -e

echo "=========================================="
echo "Deploying EDB Consistency Check"
echo "=========================================="
echo ""

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Deploy PostgreSQL
echo "1. Deploying PostgreSQL..."
kubectl apply -f "$PROJECT_ROOT/k8s/postgres-deployment.yaml"

# Wait for PostgreSQL to be ready
echo "2. Waiting for PostgreSQL pod to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres --timeout=120s

# Give it a few more seconds to fully initialize
echo "   Waiting for database initialization..."
sleep 10

# Deploy and run the check job
echo "3. Deploying consistency check job..."
kubectl delete job checksum-check-job --ignore-not-found=true
kubectl apply -f "$PROJECT_ROOT/k8s/check-job.yaml"

# Wait for job to complete
echo "4. Waiting for check job to complete..."
kubectl wait --for=condition=complete job/checksum-check-job --timeout=120s || true

# Show the results
echo ""
echo "=========================================="
echo "Check Results:"
echo "=========================================="
kubectl logs job/checksum-check-job

echo ""
echo "=========================================="
echo "Deployment Status:"
echo "=========================================="
echo ""
echo "Pods:"
kubectl get pods
echo ""
echo "Services:"
kubectl get services
