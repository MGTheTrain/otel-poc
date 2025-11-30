# OpenTelemetry Observability Stack PoC

![Work in Progress](https://img.shields.io/badge/status-WIP-yellow)

Complete observability platform with OpenTelemetry demonstrating traces, metrics, and logs across C#, Go, Python, Rust and C++.

## Quick Start

```bash
make start    # Start the entire stack
make test     # Generate test traffic
make grafana  # Open Grafana UI
```

## What's Included

### Observability Backend
- **OpenTelemetry Collector** - Central telemetry hub (ports 4317/4318)
- **Jaeger** - Distributed tracing UI (http://localhost:16686)
- **Prometheus** - Metrics storage (http://localhost:9090)
- **Loki** - Log aggregation (port 3100)
- **Grafana** - Unified dashboard (http://localhost:3000, admin/admin)

### Example Microservices (All OpenTelemetry-Instrumented)
| Service | Language | Port | Endpoint |
|---------|----------|------|----------|
| csharp-service | C# / ASP.NET Core | 5001 | http://localhost:5001/api/hello |
| go-service | Go / Gin | 5002 | http://localhost:5002/api/hello |
| python-service | Python / FastAPI | 5003 | http://localhost:5003/api/hello |
| rust-service | Rust / Actix-web | 5004 | http://localhost:5004/api/hello |
| cpp-service | C++ / cpp-httplib | 5005 | http://localhost:5005/api/hello |

## Architecture

```
Microservices (C#, Go, Python, Rust, C++)
               ↓ OTLP (gRPC/HTTP)
   OpenTelemetry Collector
      ↙        ↓        ↘
  Jaeger  Prometheus   Loki
      ↘        ↓        ↙
         Grafana (UI)
```

**Data Flow**: Services automatically export traces, metrics and logs via OpenTelemetry SDK → OTLP Collector → respective backends → unified visualization in Grafana.

## Available Commands

```bash
Usage: make [target]

Available targets:
  help            Show this help message
  start           Start all services
  stop            Stop all services
  restart         Restart all services
  logs            Show logs from all services
  build           Build all service images
  clean           Stop services and remove volumes
  status          Show status of all services
  test            Generate test traffic
  start-infra     Start only infrastructure (no app services)
  start-csharp    Start only C# service
  start-go        Start only Go service
  start-python    Start only Python service
  start-rust      Start only Rust service
  start-cpp       Start only C++ service
  grafana         Open Grafana in browser
  jaeger          Open Jaeger in browser
  prometheus      Open Prometheus in browser
```

## Development

### Using Dev Containers (Recommended)
Each service includes a VS Code dev container with all dependencies pre-installed and [docker-in-docker](https://github.com/devcontainers/features/tree/main/src/docker-in-docker) capabilities for proper debugging:

**Setup Steps:**
1. Launch the dev container for the chosen service in VS Code
2. Once the dev container builds, start backend services:
   ```bash
   make start-infra
   ```
3. Set breakpoints in your code and start debugging
4. Service connects to `localhost:4317` (forwarded to `otel-collector`)

**Dev Container Advantages:**
- Zero setup - all dependencies pre-installed
- Consistent environment across team
- Full IDE support (IntelliSense, debugging)
- Isolated from host system
- Works on any OS (Windows, Mac, Linux)
- Docker-in-docker for running containers within the dev environment

## Viewing Telemetry

### Distributed Traces (Grafana + Jaeger)
```bash
# 1. Open Grafana
make grafana

# 2. Navigate to Explore → Jaeger

# 3. Select a service (e.g. "python-service")
```

![](./images/grafana-jaeger-sample-traces.png)

### Metrics (Grafana + Prometheus)
```bash
# 1. Open Grafana
make grafana

# 2. Navigate to Explore → Prometheus
# 3. Sample queries:
rate(http_server_request_count_total[5m])  # Request rate
histogram_quantile(0.95, http_server_duration_milliseconds_bucket)  # P95 latency
```

### Logs (Grafana + Loki)
```bash
# 1. Open Grafana
make grafana

# 2. Navigate to Explore → Loki
# 3. Sample queries:
{service_name="python-service"}                     # All Python logs
{service_name=~".*-service"} |= "Hello"             # Logs containing "Hello"
{service_name=~".*-service"} |= "error" or "Error"  # Error logs
```

![](./images/grafana-loki-sample-logs.png)

## Project Structure

```
.
├── .devcontainer/                   # DevContainer's for each internal service
├── Makefile                         # Command management (START HERE)
├── docker-compose.otel-stack.yml    # Main orchestration
├── otel-collector-config.yml        # Collector configuration
├── prometheus/prometheus.yml        # Prometheus config
├── grafana/provisioning/            # Auto-configured datasources
└── services/
    ├── csharp/                      # C# service 
    ├── go/                          # Go service
    ├── python/                      # Python service
    ├── rust/                        # Rust service
    └── cpp/                         # C++ service
```

## OpenTelemetry Advantages

- **Vendor Neutral**: Not locked to any specific vendor
- **Single Standard**: One API/SDK across all languages
- **Auto-Instrumentation**: Framework-level telemetry included
- **Context Propagation**: Automatic trace context across services
- **Future Proof**: CNCF standard with broad industry support

## Common Use Cases

### Debugging a Slow Request
1. Find Jaeger traces by trace ID or time in Grafana or Jaeger dashboard
2. Identify slow span/operation
3. Check metrics for that service in Grafana
4. View logs from that timeframe in Loki
5. Fix and verify with new traces

### Performance Monitoring
1. Set up Grafana dashboard with key metrics
2. Track request rates, error rates, latencies
3. Set alerts on SLO violations
4. Correlate metrics with traces for investigation

## Troubleshooting

```bash
# Check what's running
docker ps

# View all logs
make logs

# View specific service logs
docker logs python-otel-service

# Check collector logs
docker logs otel-collector

# Restart everything
make restart

# Clean restart (removes volumes)
make clean && make start
```

### No Telemetry Data?
1. Verify collector is running: `docker ps | grep otel-collector`
2. Check collector logs: `docker logs otel-collector`
3. Ensure services can reach collector (all in `otel-network`)
4. Generate traffic: `make test`

### Port Conflicts?
Edit port mappings (left side of colon) in `docker-compose.otel-stack.yml`

## Customization

### Add Custom Metrics
```python
# Python example
from opentelemetry import metrics
meter = metrics.get_meter(__name__)
counter = meter.create_counter("my_custom_counter")
counter.add(1)
```

### Add Custom Spans
```python
# Python example
from opentelemetry import trace
tracer = trace.get_tracer(__name__)
with tracer.start_as_current_span("my_operation"):
    # Your code here
```

### Add Service-to-Service Calls
Trace context automatically propagates via HTTP headers. Just make HTTP calls between services.

## Production Considerations

### Local Kubernetes (Development/Testing)
This Docker Compose setup can be migrated to Kubernetes using tools like kind or minikube for local testing:

- Convert services to Kubernetes deployments and services
- Use ConfigMaps for collector/prometheus configurations
- Deploy with Helm charts for easier management
- Test scaling, rolling updates, and service mesh integration

### Deployment (Cloud & On-Premises)
For production in public clouds (AWS, GCP, Azure) or on-premises environments:

- Use Kubernetes (managed like EKS/GKE/AKS or self-hosted) for orchestration
- Consider managed or self-hosted monitoring/observability tools (Prometheus, Grafana, tracing)
- Implement appropriate storage (cloud disks or on-premises persistent storage)
- Leverage load balancers and ingress controllers or [Gateway API](https://kubernetes.io/docs/concepts/services-networking/gateway/) suitable for the environment
- Use IAM or equivalent access control for authentication and authorization

### Essential Security & Reliability
- [ ] Enable TLS for all endpoints
- [ ] Add authentication and authorization
- [ ] Implement sampling strategies (reduce data volume)
- [ ]  Set resource limits (CPU/memory)
- [ ] Configure backup and retention policies
- [ ] Set up high availability (multiple replicas)
- [ ] Review and adjust collector configuration
- [ ] Implement proper secret management (Vault, cloud KMS)

## Resources

- [OpenTelemetry Docs](https://opentelemetry.io/docs/)
- [Jaeger Docs](https://www.jaegertracing.io/docs/)
- [Prometheus Docs](https://prometheus.io/docs/)
- [Loki Docs](https://grafana.com/docs/loki/)
- [Grafana Docs](https://grafana.com/docs/)

## Tech Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| Instrumentation | OpenTelemetry SDK | Traces, metrics, logs |
| Collector | OpenTelemetry Collector | Telemetry pipeline |
| Tracing | Jaeger | Distributed tracing |
| Metrics | Prometheus | Time-series metrics |
| Logs | Loki | Log aggregation |
| Visualization | Grafana | Unified dashboard |
| Services | C#, Go, Python, Rust, C++ | Example microservices |
| Dev Env | VS Code Dev Containers | Isolated development |
