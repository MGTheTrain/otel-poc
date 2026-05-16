SHELL       := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c

export PROJECT_ROOT   ?= $(CURDIR)

COMPOSE_FILE := infra/compose/docker-compose.yml
COMPOSE      := docker compose -f $(COMPOSE_FILE)

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo "  PROJECT_ROOT   = $(PROJECT_ROOT)"
	@echo ''
	@echo 'Common targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## \[Common\]/ {printf "  \033[35m%-18s\033[0m %s\n", $$1, substr($$2, 10)}' $(MAKEFILE_LIST)
	@echo ''
	@echo 'Docker Compose targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^compose-[a-zA-Z_-]+:.*?## \[Compose\]/ {printf "  \033[36m%-18s\033[0m %s\n", $$1, substr($$2, 11)}' $(MAKEFILE_LIST)
	@echo ''
	@echo 'Kubernetes targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^k8s-[a-zA-Z_-]+:.*?## \[K8s\]/ {printf "  \033[33m%-18s\033[0m %s\n", $$1, substr($$2, 7)}' $(MAKEFILE_LIST)

# Common Targets

open-grafana: ## [Common] Open Grafana in browser
	@echo "Opening Grafana..."
	@open http://localhost:3000 2>/dev/null || xdg-open http://localhost:3000 2>/dev/null || echo "Open http://localhost:3000 in your browser"

open-jaeger: ## [Common] Open Jaeger in browser
	@echo "Opening Jaeger..."
	@open http://localhost:16686 2>/dev/null || xdg-open http://localhost:16686 2>/dev/null || echo "Open http://localhost:16686 in your browser"

open-prometheus: ## [Common] Open Prometheus in browser
	@echo "Opening Prometheus..."
	@open http://localhost:9090 2>/dev/null || xdg-open http://localhost:9090 2>/dev/null || echo "Open http://localhost:9090 in your browser"

# Docker Compose Targets

compose-start: ## [Compose] Start services (use SERVICES="svc1 svc2" for specific)
	@$(COMPOSE) up -d $(SERVICES)

compose-stop: ## [Compose] Stop services
	@$(COMPOSE) down

compose-restart: compose-stop compose-start ## [Compose] Restart services

compose-logs: ## [Compose] Show logs
	@$(COMPOSE) logs -f $(SERVICES)

compose-build: ## [Compose] Build service images
	@$(COMPOSE) build $(SERVICES)

compose-clean: compose-stop ## [Compose] Stop services and remove volumes
	@$(COMPOSE) down -v
	@docker system prune -f

compose-status: ## [Compose] Show status of all services
	@$(COMPOSE) ps

compose-traffic: ## [Compose] Generate test traffic
	@bash scripts/generate-traffic.sh

compose-infra: ## [Compose] Start only infrastructure services
	@$(COMPOSE) up -d otel-collector jaeger prometheus loki grafana

# Kubernetes Targets

k8s-deploy: ## [K8s] Deploy all services to Kind cluster
	@bash scripts/deploy-to-kind.sh

k8s-clean: ## [K8s] Remove all deployments from Kind cluster
	@bash scripts/cleanup-kind.sh

k8s-redeploy: ## [K8s] Uninstall + install (full reset)
	@bash scripts/cleanup-kind.sh
	@bash scripts/deploy-to-kind.sh

k8s-fwd-obs: ## [K8s] Port-forward observability stack only
	@bash scripts/port-forward-in-kind.sh --obs

k8s-fwd-svc: ## [K8s] Port-forward OpenTelemetry services only
	@bash scripts/port-forward-in-kind.sh --svc

k8s-forward: ## [K8s] Port-forward everything (observability + services)
	@bash scripts/port-forward-in-kind.sh --all

k8s-traffic: ## [K8s] Generate test traffic to all services
	@bash scripts/generate-kind-traffic.sh