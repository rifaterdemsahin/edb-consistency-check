#!/bin/bash

# Validation script - checks that all necessary files and configurations are present
# This script doesn't require a running cluster

set -e

echo "=========================================="
echo "EDB Consistency Check - Validation"
echo "=========================================="
echo ""

ERRORS=0
WARNINGS=0

# Function to check file exists
check_file() {
    if [ -f "$1" ]; then
        echo "✓ $1 exists"
    else
        echo "✗ $1 missing"
        ((ERRORS++))
    fi
}

# Function to check file is executable
check_executable() {
    if [ -x "$1" ]; then
        echo "✓ $1 is executable"
    else
        echo "⚠ $1 is not executable (run: chmod +x $1)"
        ((WARNINGS++))
    fi
}

# Function to check bash syntax
check_bash_syntax() {
    if bash -n "$1" 2>/dev/null; then
        echo "✓ $1 has valid bash syntax"
    else
        echo "✗ $1 has bash syntax errors"
        ((ERRORS++))
    fi
}

# Function to check YAML syntax
check_yaml_syntax() {
    if python3 -c "import yaml; yaml.safe_load_all(open('$1'))" 2>/dev/null; then
        echo "✓ $1 has valid YAML syntax"
    else
        echo "✗ $1 has YAML syntax errors"
        ((ERRORS++))
    fi
}

echo "Checking documentation..."
check_file "README.md"
check_file "QUICKSTART.md"
check_file "CHECKSUMS.md"
check_file "ARCHITECTURE.md"
check_file "Makefile"
check_file ".gitignore"

echo ""
echo "Checking Kubernetes manifests..."
check_file "k8s/postgres-deployment.yaml"
check_file "k8s/check-job.yaml"
check_yaml_syntax "k8s/postgres-deployment.yaml"
check_yaml_syntax "k8s/check-job.yaml"

echo ""
echo "Checking scripts..."
check_file "scripts/setup-minikube.sh"
check_file "scripts/deploy-and-check.sh"
check_file "scripts/check-data-checksums.sh"
check_file "scripts/cleanup.sh"
check_file "scripts/interactive-psql.sh"

echo ""
echo "Checking script permissions..."
check_executable "scripts/setup-minikube.sh"
check_executable "scripts/deploy-and-check.sh"
check_executable "scripts/check-data-checksums.sh"
check_executable "scripts/cleanup.sh"
check_executable "scripts/interactive-psql.sh"

echo ""
echo "Checking bash syntax..."
check_bash_syntax "scripts/setup-minikube.sh"
check_bash_syntax "scripts/deploy-and-check.sh"
check_bash_syntax "scripts/check-data-checksums.sh"
check_bash_syntax "scripts/cleanup.sh"
check_bash_syntax "scripts/interactive-psql.sh"

echo ""
echo "Checking Kubernetes manifest content..."

# Check if postgres deployment has data_checksums enabled
if grep -q 'data_checksums=on' k8s/postgres-deployment.yaml; then
    echo "✓ PostgreSQL configured with data_checksums=on"
else
    echo "✗ PostgreSQL not configured with data_checksums=on"
    ((ERRORS++))
fi

# Check if postgres image is specified
if grep -q 'image: postgres:' k8s/postgres-deployment.yaml; then
    echo "✓ PostgreSQL image specified"
else
    echo "✗ PostgreSQL image not specified"
    ((ERRORS++))
fi

# Check if check job references the script
if grep -q 'check-data-checksums.sh' k8s/check-job.yaml; then
    echo "✓ Check job references check-data-checksums.sh"
else
    echo "✗ Check job doesn't reference check-data-checksums.sh"
    ((ERRORS++))
fi

echo ""
echo "=========================================="
echo "Validation Summary"
echo "=========================================="
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✓ All validations passed!"
    echo ""
    echo "You can now proceed with:"
    echo "  1. make setup    (or ./scripts/setup-minikube.sh)"
    echo "  2. make deploy   (or ./scripts/deploy-and-check.sh)"
    echo "  3. make check"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo "⚠ Validation passed with $WARNINGS warning(s)"
    echo ""
    echo "Fix warnings before proceeding"
    exit 0
else
    echo "✗ Validation failed with $ERRORS error(s) and $WARNINGS warning(s)"
    echo ""
    echo "Please fix the errors before proceeding"
    exit 1
fi
