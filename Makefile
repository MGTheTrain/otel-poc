.PHONY: help start stop restart logs clean build status test start-infra start-csharp start-go start-python start-rust start-cpp grafana jaeger prometheus

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

start: ## Start all services
	@./scripts/start.sh

stop: ## Stop all services
	@echo "🛑 Stopping all services..."
	@docker compose -f docker-compose.otel-stack.yml down

restart: stop start ## Restart all services

logs: ## Show logs from all services
	@docker compose -f docker-compose.otel-stack.yml logs -f

build: ## Build all service images
	@echo "🔨 Building all service images..."
	@docker compose -f docker-compose.otel-stack.yml build

clean: stop ## Stop services and remove volumes
	@echo "🧹 Cleaning up..."
	@docker compose -f docker-compose.otel-stack.yml down -v
	@docker system prune -f

status: ## Show status of all services
	@docker compose -f docker-compose.otel-stack.yml ps

test: ## Generate test traffic
	@./scripts/generate-traffic.sh

# Individual service targets
start-infra: ## Start only infrastructure (no app services)
	@docker compose -f docker-compose.otel-stack.yml up -d otel-collector jaeger prometheus loki grafana

start-csharp: ## Start only C# service
	@docker compose -f docker-compose.otel-stack.yml up -d csharp-service

start-go: ## Start only Go service
	@docker compose -f docker-compose.otel-stack.yml up -d go-service

start-python: ## Start only Python service
	@docker compose -f docker-compose.otel-stack.yml up -d python-service

start-rust: ## Start only Rust service
	@docker compose -f docker-compose.otel-stack.yml up -d rust-service

start-cpp: ## Start only C++ service
	@docker compose -f docker-compose.otel-stack.yml up -d cpp-service

# Monitoring shortcuts
grafana: ## Open Grafana in browser
	@echo "Opening Grafana..."
	@open http://localhost:3000 2>/dev/null || xdg-open http://localhost:3000 2>/dev/null || echo "Open http://localhost:3000 in your browser"

jaeger: ## Open Jaeger in browser
	@echo "Opening Jaeger..."
	@open http://localhost:16686 2>/dev/null || xdg-open http://localhost:16686 2>/dev/null || echo "Open http://localhost:16686 in your browser"

prometheus: ## Open Prometheus in browser
	@echo "Opening Prometheus..."
	@open http://localhost:9090 2>/dev/null || xdg-open http://localhost:9090 2>/dev/null || echo "Open http://localhost:9090 in your browser"
