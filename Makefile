.PHONY: help start stop restart logs clean build status test start-infra grafana jaeger prometheus kind-deploy kind-clean kind-status kind-logs kind-port-forward

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
	@echo "Cleaning up Kind deployments..."
	@helm uninstall python-otel-service go-otel-service csharp-otel-service rust-otel-service cpp-otel-service 2>/dev/null || true
	@helm uninstall otel-collector jaeger prometheus loki grafana 2>/dev/null || true
	@echo "✓ Kind cluster cleaned"

kind-status: ## Show status of Kind cluster deployments (Kind cluster required)
	@echo "⚠️  This target requires a Kind cluster"
	@command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl not found."; exit 1; }
	@echo "=== Observability Stack ==="
	@kubectl get pods -l 'app.kubernetes.io/name in (opentelemetry-collector,jaeger,prometheus,loki,grafana)' 2>/dev/null || echo "No observability pods found"
	@echo ""
	@echo "=== Microservices ==="
	@kubectl get pods -l 'app.kubernetes.io/instance in (python-otel-service,go-otel-service,csharp-otel-service,rust-otel-service,cpp-otel-service)' 2>/dev/null || echo "No service pods found"
	@echo ""
	@echo "=== Services ==="
	@kubectl get svc

kind-logs: ## Show logs from Kind cluster (use SERVICES="svc1" for specific service, Kind cluster required)
	@echo "⚠️  This target requires a Kind cluster"
	@command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl not found."; exit 1; }
	$(if $(SERVICES), \
		@kubectl logs -l app.kubernetes.io/instance=$(SERVICES) -f, \
		@echo "Specify service: make kind-logs SERVICES=python-otel-service")

kind-port-forward: ## Start port-forwarding for UIs (Kind cluster required)
	@echo "⚠️  This target requires a Kind cluster"
	@command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl not found."; exit 1; }
	@echo "Starting port-forwards (press Ctrl+C to stop)..."
	@echo "Grafana:    http://localhost:3000"
	@echo "Jaeger:     http://localhost:16686"
	@echo "Prometheus: http://localhost:9090"
	@echo ""
	@kubectl port-forward svc/grafana 3000:80 & \
	kubectl port-forward svc/jaeger-query 16686:16686 & \
	kubectl port-forward svc/prometheus-server 9090:80 & \
	wait