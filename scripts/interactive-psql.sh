#!/bin/bash

# Interactive script to access the PostgreSQL database directly
# This allows manual testing and inspection

set -e

echo "=========================================="
echo "PostgreSQL Interactive Access"
echo "=========================================="
echo ""

# Check if PostgreSQL pod is running
if ! kubectl get pods -l app=postgres | grep -q "Running"; then
    echo "❌ Error: PostgreSQL pod is not running"
    echo ""
    echo "Deploy it first with:"
    echo "  kubectl apply -f k8s/postgres-deployment.yaml"
    echo "Or:"
    echo "  make deploy"
    exit 1
fi

# Get pod name
POD_NAME=$(kubectl get pods -l app=postgres -o jsonpath='{.items[0].metadata.name}')

echo "PostgreSQL pod: $POD_NAME"
echo ""
echo "Choose an option:"
echo ""
echo "1. Open psql interactive shell"
echo "2. Run: SHOW data_checksums;"
echo "3. Run: SHOW all;"
echo "4. Show PostgreSQL version"
echo "5. List databases"
echo "6. Exit"
echo ""
read -p "Enter your choice (1-6): " choice

case $choice in
    1)
        echo ""
        echo "Opening psql shell..."
        echo "Type '\q' to exit"
        echo ""
        kubectl exec -it $POD_NAME -- psql -U postgres -d testdb
        ;;
    2)
        echo ""
        echo "Running: SHOW data_checksums;"
        echo "----------------------------------------"
        kubectl exec -it $POD_NAME -- psql -U postgres -d testdb -c "SHOW data_checksums;"
        ;;
    3)
        echo ""
        echo "Running: SHOW all;"
        echo "----------------------------------------"
        kubectl exec -it $POD_NAME -- psql -U postgres -d testdb -c "SHOW all;" | less
        ;;
    4)
        echo ""
        echo "PostgreSQL Version:"
        echo "----------------------------------------"
        kubectl exec -it $POD_NAME -- psql -U postgres -d testdb -c "SELECT version();"
        ;;
    5)
        echo ""
        echo "Databases:"
        echo "----------------------------------------"
        kubectl exec -it $POD_NAME -- psql -U postgres -d testdb -c "\l"
        ;;
    6)
        echo "Goodbye!"
        exit 0
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac
