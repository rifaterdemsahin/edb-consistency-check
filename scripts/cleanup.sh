#!/bin/bash

# Cleanup script - removes all deployed resources

set -e

echo "=========================================="
echo "Cleaning up EDB Consistency Check"
echo "=========================================="
echo ""

# Delete the check job
echo "Deleting check job..."
kubectl delete -f k8s/check-job.yaml --ignore-not-found=true

# Delete PostgreSQL deployment
echo "Deleting PostgreSQL deployment..."
kubectl delete -f k8s/postgres-deployment.yaml --ignore-not-found=true

echo ""
echo "✓ Cleanup complete!"
echo ""
echo "Remaining resources:"
kubectl get all
