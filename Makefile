# OTel PoC — developer commands

SHELL       := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c

export PROJECT_ROOT ?= $(CURDIR)

RUNTIME ?= compose

COMPOSE_FILE   ?= infra/compose/docker-compose.yml
COMPOSE        := docker compose -f $(COMPOSE_FILE)
UMBRELLA_CHART := ./infra/helm-charts/otel-poc

PYTEST   ?= pytest
SERVICES ?=

# ── Runtime abstraction ─────────────────────────────────────────────

ifeq ($(RUNTIME),compose)
else ifeq ($(RUNTIME),k8s)
else
$(error Unsupported RUNTIME='$(RUNTIME)' (expected compose|k8s))
endif

# ── Help ────────────────────────────────────────────────────────────

.PHONY: help
help: ## Show available targets
	@echo ''
	@echo 'OpenTelemetry Observability Stack PoC'
	@echo ''
	@echo '  PROJECT_ROOT = $(PROJECT_ROOT)'
	@echo '  RUNTIME      = $(RUNTIME)'
	@echo ''
	@echo 'Usage:'
	@echo '  make <target> [RUNTIME=compose|k8s] [SERVICES="svc1 svc2"]'
	@echo ''
	@awk 'BEGIN {FS = ":.*?## "}; /^[a-zA-Z0-9_-]+:.*?## / {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# ── Common ──────────────────────────────────────────────────────────

.PHONY: open-grafana open-jaeger open-prometheus lint
open-grafana: ## Open Grafana in browser
	@open http://localhost:3000 2>/dev/null || xdg-open http://localhost:3000 2>/dev/null || echo "Open http://localhost:3000"

open-jaeger: ## Open Jaeger in browser
	@open http://localhost:16686 2>/dev/null || xdg-open http://localhost:16686 2>/dev/null || echo "Open http://localhost:16686"

open-prometheus: ## Open Prometheus in browser
	@open http://localhost:9090 2>/dev/null || xdg-open http://localhost:9090 2>/dev/null || echo "Open http://localhost:9090"

lint: ## Run pre-commit hooks
	@pre-commit run --all-files

# ── Runtime lifecycle ───────────────────────────────────────────────

.PHONY: start start-infra stop restart logs build status traffic test
start: ## Start the platform (compose: SERVICES="svc1 svc2" optional)
ifeq ($(RUNTIME),compose)
	@$(COMPOSE) up -d --build $(SERVICES)
else
	@bash scripts/deploy-to-kind.sh
endif

start-infra: ## Start only infrastructure (observability stack)
ifeq ($(RUNTIME),compose)
	@$(COMPOSE) up -d --build otel-collector jaeger prometheus loki grafana
else
	@echo "k8s: deploy-to-kind.sh installs the whole umbrella; use 'make start'"
endif

stop: ## Stop the platform
ifeq ($(RUNTIME),compose)
	@$(COMPOSE) down
else
	@bash scripts/cleanup-kind.sh
endif

restart: stop start ## Restart the platform

logs: ## Follow platform logs
ifeq ($(RUNTIME),compose)
	@$(COMPOSE) logs -f $(SERVICES)
else
	@echo "Use kubectl logs for specific pods:"
	@kubectl get pods -n default
endif

build: ## Rebuild service images (compose only; k8s rebuilds via deploy-to-kind.sh)
ifeq ($(RUNTIME),compose)
	@$(COMPOSE) build $(SERVICES)
else
	@echo "Rebuild not applicable for k8s — handled by deploy-to-kind.sh"
endif

status: ## Show platform status
ifeq ($(RUNTIME),compose)
	@$(COMPOSE) ps
else
	@kubectl get pods,svc -n default
endif

traffic: ## Generate test traffic
	@bash scripts/generate-traffic.sh $(RUNTIME)

test: ## Run service + telemetry tests
	$(PYTEST) tests/ --env=$(RUNTIME)

# ── K8s extras (no compose equivalent) ──────────────────────────────

.PHONY: forward forward-obs forward-svc forward-bg forward-stop
forward: ## Port-forward everything (k8s only)
ifeq ($(RUNTIME),k8s)
	@bash scripts/port-forward-in-kind.sh --all
else
	@echo "Compose exposes services on host ports directly"
endif

forward-obs: ## Port-forward observability only (k8s only)
ifeq ($(RUNTIME),k8s)
	@bash scripts/port-forward-in-kind.sh --obs
else
	@echo "Compose exposes services on host ports directly"
endif

forward-svc: ## Port-forward services only (k8s only)
ifeq ($(RUNTIME),k8s)
	@bash scripts/port-forward-in-kind.sh --svc
else
	@echo "Compose exposes services on host ports directly"
endif

forward-bg: ## Background port-forward (k8s only; writes PID to /tmp/otel-pf.pid)
ifeq ($(RUNTIME),k8s)
	@bash scripts/port-forward-in-kind.sh --all > /tmp/otel-pf.log 2>&1 & echo $$! > /tmp/otel-pf.pid
	@echo " Port-forwards started in background (PID $$(cat /tmp/otel-pf.pid))"
else
	@echo "forward-bg is k8s-only"
endif

forward-stop: ## Stop background port-forwards
ifeq ($(RUNTIME),k8s)
	@if [ -f /tmp/otel-pf.pid ]; then kill $$(cat /tmp/otel-pf.pid) 2>/dev/null || true; rm -f /tmp/otel-pf.pid; fi
else
	@echo "forward-stop is k8s-only"
endif
