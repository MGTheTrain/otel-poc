.PHONY: help start stop restart logs clean build status test start-infra grafana jaeger prometheus

help: ## Show this help message
	@echo 'Usage: make [target] [SERVICES="service1 service2"]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ''
	@echo 'Examples:'
	@echo '  make start                                   # Start all services'
	@echo '  make start SERVICES="otel-collector jaeger"  # Start specific services'
	@echo '  make build SERVICES="rust-service"           # Build specific service'
	@echo '  make logs SERVICES="python-service"          # View specific logs'

start: ## Start services (use SERVICES="svc1 svc2" for specific services)
	@docker-compose -f docker-compose.otel-stack.yml up -d $(SERVICES)

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