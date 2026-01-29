#!/bin/bash

# Setup script for EDB Consistency Check in Minikube
# This script sets up the entire environment in GitHub Codespaces

set -e

echo "=========================================="
echo "EDB Consistency Check - Minikube Setup"
echo "=========================================="
echo ""

# Check if minikube is installed
if ! command -v minikube &> /dev/null; then
    echo "⚠ Minikube not found. Installing minikube..."
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    sudo install minikube-linux-amd64 /usr/local/bin/minikube
    rm minikube-linux-amd64
    echo "✓ Minikube installed"
else
    echo "✓ Minikube is already installed"
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "⚠ kubectl not found. Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
    echo "✓ kubectl installed"
else
    echo "✓ kubectl is already installed"
fi

# Start minikube if not already running
if minikube status &> /dev/null; then
    echo "✓ Minikube is already running"
else
    echo "Starting minikube..."
    minikube start --driver=docker --memory=4096 --cpus=4 --wait all
    echo "✓ Minikube started"
fi

# Wait for minikube to be ready
echo "Waiting for minikube to be ready..."
kubectl wait --for=condition=ready node --all --timeout=120s

echo ""
echo "✓ Setup complete!"
echo ""
echo "Minikube status:"
minikube status
