.PHONY: help setup deploy check check-full cleanup status clean all all-full

help:
	@echo "EDB Consistency Check - Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  make setup      - Setup Minikube environment"
	@echo "  make deploy     - Deploy PostgreSQL to Kubernetes"
	@echo "  make check      - Run basic consistency check (data checksums)"
	@echo "  make check-full - Run full consistency check suite (checksums, integrity, bloat)"
	@echo "  make all        - Setup + Deploy + Basic Check"
	@echo "  make all-full   - Setup + Deploy + Full Check"
	@echo "  make status     - Show deployment status"
	@echo "  make cleanup    - Remove all deployed resources"
	@echo "  make clean      - Cleanup + stop Minikube"

setup:
	@echo "Setting up Minikube..."
	@./scripts/setup-minikube.sh

deploy:
	@echo "Deploying PostgreSQL..."
	@kubectl apply -f k8s/postgres-deployment.yaml
	@echo "Waiting for PostgreSQL to be ready..."
	@kubectl wait --for=condition=ready pod -l app=postgres --timeout=120s
	@echo "Waiting 60 seconds for database to fully initialize..."
	@sleep 60
	@echo "✓ PostgreSQL deployed and ready"

check:
	@echo "Running basic consistency check..."
	@kubectl delete job checksum-check-job --ignore-not-found=true
	@kubectl apply -f k8s/check-job.yaml
	@kubectl wait --for=condition=complete job/checksum-check-job --timeout=120s || true
	@echo ""
	@echo "=========================================="
	@echo "Check Results:"
	@echo "=========================================="
	@kubectl logs job/checksum-check-job

check-full:
	@echo "Running full consistency check suite..."
	@kubectl delete job full-consistency-check-job --ignore-not-found=true
	@kubectl apply -f k8s/full-check-job.yaml
	@kubectl wait --for=condition=complete job/full-consistency-check-job --timeout=180s || true
	@echo ""
	@echo "=========================================="
	@echo "Full Check Results:"
	@echo "=========================================="
	@kubectl logs job/full-consistency-check-job

all: setup deploy check

all-full: setup deploy check-full

status:
	@echo "Deployment Status:"
	@echo ""
	@echo "Pods:"
	@kubectl get pods
	@echo ""
	@echo "Services:"
	@kubectl get services
	@echo ""
	@echo "Jobs:"
	@kubectl get jobs

cleanup:
	@echo "Cleaning up resources..."
	@./scripts/cleanup.sh

clean: cleanup
	@echo "Stopping Minikube..."
	@minikube stop
	@echo "✓ Complete cleanup done"
