# OpenTelemetry Observability Stack PoC

Complete observability platform demonstrating traces, metrics and logs across C#, Go, Python, Rust and C++ using OpenTelemetry.

## Quick Start

### Docker Compose (Local Development)

```bash
# Option 1: Quick start all services using pre-built images (skips local compilation, Recommended)
COMPOSE_FILE="./infra/compose/docker-compose.ci.yml" make compose-start

# Option 2: Build internal services locally and start all services
make compose-start

# Option 3: Start infrastructure services, build and start specific internal services
make compose-start-infra
make compose-start SERVICES="python-service go-service csharp-service"
make compose-start SERVICES="rust-service cpp-service" # Compile and start heavy services separately (slow on first run)

# Terminal A - Generate traffic + assert telemetry landed
make compose-traffic-assert
# Open Grafana in browser
make open-grafana # http://localhost:3000 (admin/admin)

# Stop services and remove volumes
make compose-clean
```

### Kubernetes Kind (Local Development)

Open the matching [dev container](.devcontainer/kind/devcontainer.json) in any IDE that supports [dev containers](https://containers.dev/), then run:

```bash
# Terminal A - Deploy all services to the Kind cluster
make k8s-deploy

# Terminal B - Port-forward everything (observability + services)
make k8s-fwd

# Terminal A - Generate traffic + assert telemetry landed
make k8s-traffic-assert
# Open Grafana in browser
make open-grafana  # http://localhost:3000 (admin/admin)

# Remove all deployments from Kind cluster
make k8s-clean
```

## What's Included

**Observability Stack:**
- **OpenTelemetry Collector** (port 4317) - Central telemetry hub
- **Jaeger** (port 16686) - Distributed tracing
- **Prometheus** (port 9090) - Metrics storage
- **Loki** (port 3100) - Log aggregation
- **Grafana** (port 3000) - Unified visualization

**Example Services:**
| Language | Port | Endpoint |
|----------|------|----------|
| C# (ASP.NET) | 5001 | http://localhost:5001/api/hello |
| Go (Gin) | 5002 | http://localhost:5002/api/hello |
| Python (FastAPI) | 5003 | http://localhost:5003/api/hello |
| Rust (Actix) | 5004 | http://localhost:5004/api/hello |
| C++ (httplib) | 5005 | http://localhost:5005/api/hello |

**Architecture:**
```
Services → OTLP (gRPC) → Collector → Jaeger/Prometheus/Loki → Grafana
```

**Why OpenTelemetry?**
- Vendor-neutral standard (CNCF)
- Single API across all languages
- Auto-instrumentation for common frameworks
- Future-proof observability
- Backend-agnostic (easily switch Jaeger/Tempo, Prometheus/Graphite, Loki/Elasticsearch)

## Viewing Telemetry

### 1. Traces (Jaeger)
```bash
make open-grafana
# Navigate to: Explore → Jaeger → Select service
```
![Traces](./images/grafana-jaeger-sample-traces.png)

### 2. Metrics (Prometheus)

```bash
# Request rate (Go, C# services)
otel_http_server_request_duration_seconds_count
rate(otel_http_server_request_duration_seconds_count[5m]) # per-second request rate based on the otel_http_server_request_duration_seconds_count counter, averaged over the last 5 minutes

# Response size (Go service)
otel_http_server_response_body_size_bytes_count
rate(otel_http_server_response_body_size_bytes_count[5m]) # per-second increase of the response body size counter over the last 5 minutes

# 95th percentile latency (Go service)
histogram_quantile(0.95, rate(otel_http_server_request_duration_seconds_bucket[5m])) # histogram_quantile(0.95, rate(otel_http_server_request_duration_seconds_bucket[5m])) calculates the 95th percentile request duration over the last 5 minutes

# Browse all HTTP metrics
{__name__=~"otel_http.*"}

# Note: Not all services export the same metrics due to varying auto-instrumentation support:
# - Go: ✅ Full HTTP metrics (Gin auto-instrumentation)
# - C#: Partial (client metrics only, server metrics missing)
# - Python: Different metric names (use response_size instead of duration)
# - Rust: ❌ No HTTP metrics (Actix has no auto-instrumentation)
# - C++: Manual counter only
#
# TODO: Add manual HTTP metric instrumentation for Rust/C++ services.
# Refer to OpenTelemetry examples for your language:
# - Rust: https://github.com/open-telemetry/opentelemetry-rust/tree/main/examples
# - Python: https://opentelemetry.io/docs/languages/python/instrumentation/
# - C++: https://github.com/open-telemetry/opentelemetry-cpp/tree/main/examples
```

### 3. Logs (Loki)
```bash
# In Grafana Explore → Loki, try:
{service_name="rust-service"}
{service_name=~".*-service"} |= "error"
```
![Logs](./images/grafana-loki-sample-logs.png)

## Development

**Dev Containers:**
Each service has a pre-configured [dev container](https://containers.dev/) with debugging support. Open the dev container in a supported IDE for the chosen service → run `make compose-start-infra` inside the container to launch external dependencies → set breakpoints in the service’s source code and start debugging

**Available Commands:**
```bash
Usage: make [target]

  PROJECT_ROOT   = /Users/marvingajek/Documents/poc-repos/otel-poc

Common targets:
  open-grafana       Open Grafana in browser
  open-jaeger        Open Jaeger in browser
  open-prometheus    Open Prometheus in browser

Docker Compose targets:
  compose-start      Start services (use SERVICES="svc1 svc2" for specific)
  compose-stop       Stop services
  compose-restart    Restart services
  compose-logs       Show logs
  compose-build      Build service images
  compose-clean      Stop services and remove volumes
  compose-status     Show status of all services
  compose-traffic    Generate test traffic
  compose-traffic-assert Generate traffic  assert telemetry landed
  compose-start-infra      Start only infrastructure services

Kubernetes targets:
  k8s-deploy         Deploy all services to Kind cluster
  k8s-clean          Remove all deployments from Kind cluster
  k8s-redeploy       Uninstall + install (full reset)
  k8s-fwd-obs        Port-forward observability stack only
  k8s-fwd-svc        Port-forward OpenTelemetry services only
  k8s-forward        Port-forward everything (observability + services)
  k8s-forward-bg     Same, but background — writes PID to /tmp/otel-pf.pid
  k8s-forward-stop   Kill the background port-forwards
  k8s-traffic        Generate test traffic to all services
  k8s-traffic-assert Generate traffic + assert telemetry landed

Development:
  lint               Run pre-commit hooks on specific files
```

## Resources

### Technical Documentation

- [Jaeger Docs](https://www.jaegertracing.io/docs/)
- [Grafana Docs](https://grafana.com/docs/)
- [OpenTelemetry Rust Examples](https://github.com/open-telemetry/opentelemetry-rust/tree/main/examples)
- [OpenTelemetry C++ Examples](https://github.com/open-telemetry/opentelemetry-cpp/tree/main/examples)
- [OpenTelemetry Go Examples](https://github.com/open-telemetry/opentelemetry-go-contrib/tree/main/examples)
- [OpenTelemetry .NET Examples](https://github.com/open-telemetry/opentelemetry-dotnet/tree/main/examples)
- [OpenTelemetry Python Getting Started](https://opentelemetry.io/docs/languages/python/getting-started/)
- [OpenTelemetry Docs](https://opentelemetry.io/docs/)
- [OpenTelemetry Collector Documentation](https://opentelemetry.io/docs/collector/)
- [Prometheus Docs](https://prometheus.io/docs/)
- [Loki Docs](https://grafana.com/docs/loki/)

### ADRs

- [ADR-001: OpenTelemetry Collector for Centralized Observability Pipeline](./docs/ADR-001-CENTRALIZED-OBSERVABILITY.md)

## Common Use Cases

### Debugging a Slow Request
1. Find Jaeger traces by trace ID or time in Grafana or Jaeger Web UI
2. Identify slow span/operation
3. Check metrics for that service in Grafana
4. View logs from that timeframe in Grafana
5. Fix and verify with new traces

### Performance Monitoring
1. Set up Grafana dashboard with key metrics
2. Track request rates, error rates, latencies
3. Set alerts on SLO violations
4. Correlate metrics with traces for investigation

## Production / Kubernetes Considerations

This PoC can be migrated to Kubernetes or deployed in the cloud:

- **Cloud/On-prem:** Deploy on managed/self-hosted Kubernetes; configure persistent storage, load balancers and ingress controllers or [Gateway API](https://kubernetes.io/docs/concepts/services-networking/gateway/).
- **Best practices:** Enable TLS, authentication/authorization, resource limits, sampling and backups for reliability.
