.PHONY: help start stop restart logs clean build status test start-infra grafana jaeger prometheus kind-deploy kind-clean kind-fwd-obs kind-fwd-svc kind-fwd kind-traffic

help: ## Show this help message
	@echo 'Usage: make [target] [SERVICES="service1 service2"]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

start: ## Start services (use SERVICES="svc1 svc2" for specific services)
	@docker compose -f docker-compose.otel-stack.yml up -d $(SERVICES)

stop: ## Stop services (use SERVICES="svc1 svc2" for specific services)
	@echo "Stopping services..."
	$(if $(SERVICES),@docker compose -f docker-compose.otel-stack.yml stop $(SERVICES),@docker compose -f docker-compose.otel-stack.yml down)

restart: stop start ## Restart services

logs: ## Show logs (use SERVICES="svc1 svc2" for specific services)
	@docker compose -f docker-compose.otel-stack.yml logs -f $(SERVICES)

build: ## Build service images (use SERVICES="svc1 svc2" for specific services)
	@echo "Building service images..."
	@docker compose -f docker-compose.otel-stack.yml build --no-cache $(SERVICES)

clean: stop ## Stop services and remove volumes
	@echo "Cleaning up..."
	@docker compose -f docker-compose.otel-stack.yml down -v
	@docker system prune -f

status: ## Show status of all services
	@docker compose -f docker-compose.otel-stack.yml ps

test: ## Generate test traffic
	@./scripts/generate-traffic.sh

start-infra: ## Start only infrastructure services
	@docker compose -f docker-compose.otel-stack.yml up -d otel-collector jaeger prometheus loki grafana

grafana: ## Open Grafana in browser
	@echo "Opening Grafana..."
	@open http://localhost:3000 2>/dev/null || xdg-open http://localhost:3000 2>/dev/null || echo "Open http://localhost:3000 in your browser"

jaeger: ## Open Jaeger in browser
	@echo "Opening Jaeger..."
	@open http://localhost:16686 2>/dev/null || xdg-open http://localhost:16686 2>/dev/null || echo "Open http://localhost:16686 in your browser"

prometheus: ## Open Prometheus in browser
	@echo "Opening Prometheus..."
	@open http://localhost:9090 2>/dev/null || xdg-open http://localhost:9090 2>/dev/null || echo "Open http://localhost:9090 in your browser"

# ============================================================================
# Kind Cluster Targets (requires devcontainer setup from .devcontainer/kind/)
# ============================================================================

kind-deploy: ## Deploy all services to Kind cluster (Kind cluster required - use devcontainer)
	@echo "⚠️  This target requires a Kind cluster (use provided devcontainer.json)"
	@command -v kind >/dev/null 2>&1 || { echo "❌ Kind not found. Please use the devcontainer setup."; exit 1; }
	@kind get clusters | grep -q "^kind$$" || { echo "❌ Kind cluster 'kind' not found. Run devcontainer setup first."; exit 1; }
	@./scripts/deploy-to-kind.sh

kind-clean: ## Remove all deployments from Kind cluster (Kind cluster required)
	@echo "⚠️  This target requires a Kind cluster"
	@command -v kind >/dev/null 2>&1 || { echo "❌ Kind not found."; exit 1; }
	@bash scripts/cleanup-kind.sh

kind-fwd-obs: ## Port-forward observability stack only
	@command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl not found."; exit 1; }
	@kubectl cluster-info >/dev/null 2>&1 || { echo "❌ Kind cluster not running."; exit 1; }
	@bash scripts/port-forward-in-kind.sh --obs

kind-fwd-svc: ## Port-forward OpenTelemetry services only
	@command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl not found."; exit 1; }
	@kubectl cluster-info >/dev/null 2>&1 || { echo "❌ Kind cluster not running."; exit 1; }
	@bash scripts/port-forward-in-kind.sh --svc

kind-fwd: ## Port-forward everything (observability + services)
	@command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl not found."; exit 1; }
	@kubectl cluster-info >/dev/null 2>&1 || { echo "❌ Kind cluster not running."; exit 1; }
	@bash scripts/port-forward-in-kind.sh --all

kind-traffic: ## Generate test traffic to all services (Kind cluster required)
	@echo "⚠️  This target requires a Kind cluster"
	@command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl not found."; exit 1; }
	@./scripts/generate-kind-traffic.sh