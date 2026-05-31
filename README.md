# OpenTelemetry Observability Stack PoC

Complete observability platform demonstrating traces, metrics and logs across C#, Go, Python, Rust and C++ using OpenTelemetry.

## Quick Start

### Docker Compose

```bash
export RUNTIME=compose

# Option 1: Quick start with pre-built images (recommended for first run)
COMPOSE_FILE="./infra/compose/docker-compose.ci.yml" make start

# Option 2: Build all services locally and start everything
make start

# Option 3: Start infrastructure first, then selective services
make start-infra
make start SERVICES="python-otel-service go-otel-service csharp-otel-service"
make start SERVICES="rust-otel-service cpp-otel-service"   # slow on first build

# Generate traffic + open Grafana
make traffic
make open-grafana   # http://localhost:3000 (admin/admin)

# Tear down (compose: down + prune)
make stop
```

### Kubernetes (kind)

Open the matching [dev container](.devcontainer/kind/devcontainer.json) in any IDE that supports [dev containers](https://containers.dev/), then run:

```bash
export RUNTIME=k8s

# Terminal A — deploy
make start

# Terminal B — port-forward everything (observability + services)
make forward

# Terminal A — generate traffic + open Grafana
make traffic
make open-grafana   # http://localhost:3000 (admin/admin)

# Tear down
make stop
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
Each service has a pre-configured [dev container](https://containers.dev/) with debugging support. Open the dev container in a supported IDE for the chosen service → run `make start-infra` inside the container to launch external dependencies → set breakpoints in the service’s source code and start debugging

**Available Commands:**
```bash
OpenTelemetry Observability Stack PoC

  PROJECT_ROOT = /Users/marvingajek/Documents/poc-repos/otel-poc
  RUNTIME      = compose

Usage:
  make <target> [RUNTIME=compose|k8s] [SERVICES="svc1 svc2"]

  help                   Show available targets
  open-grafana           Open Grafana in browser
  open-jaeger            Open Jaeger in browser
  open-prometheus        Open Prometheus in browser
  lint                   Run pre-commit hooks
  start                  Start the platform (compose: SERVICES="svc1 svc2" optional)
  start-infra            Start only infrastructure (observability stack)
  stop                   Stop the platform
  restart                Restart the platform
  logs                   Follow platform logs
  build                  Rebuild service images (compose only; k8s rebuilds via deploy-to-kind.sh)
  status                 Show platform status
  traffic                Generate test traffic
  test                   Run service + telemetry tests
  forward                Port-forward everything (k8s only)
  forward-obs            Port-forward observability only (k8s only)
  forward-svc            Port-forward services only (k8s only)
  forward-bg             Background port-forward (k8s only; writes PID to /tmp/otel-pf.pid)
  forward-stop           Stop background port-forwards
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
