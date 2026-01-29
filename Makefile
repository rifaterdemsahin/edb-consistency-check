.PHONY: help setup deploy check cleanup status clean all

help:
	@echo "EDB Consistency Check - Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  make setup    - Setup Minikube environment"
	@echo "  make deploy   - Deploy PostgreSQL to Kubernetes"
	@echo "  make check    - Run consistency check"
	@echo "  make all      - Setup + Deploy + Check (full workflow)"
	@echo "  make status   - Show deployment status"
	@echo "  make cleanup  - Remove all deployed resources"
	@echo "  make clean    - Cleanup + stop Minikube"

setup:
	@echo "Setting up Minikube..."
	@./scripts/setup-minikube.sh

deploy:
	@echo "Deploying PostgreSQL..."
	@kubectl apply -f k8s/postgres-deployment.yaml
	@echo "Waiting for PostgreSQL to be ready..."
	@kubectl wait --for=condition=ready pod -l app=postgres --timeout=120s
	@sleep 10
	@echo "✓ PostgreSQL deployed and ready"

check:
	@echo "Running consistency check..."
	@kubectl delete job checksum-check-job --ignore-not-found=true
	@kubectl apply -f k8s/check-job.yaml
	@kubectl wait --for=condition=complete job/checksum-check-job --timeout=120s || true
	@echo ""
	@echo "=========================================="
	@echo "Check Results:"
	@echo "=========================================="
	@kubectl logs job/checksum-check-job

all: setup deploy check

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
