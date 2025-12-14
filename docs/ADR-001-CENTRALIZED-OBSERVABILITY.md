---
parent: Decisions
nav_order: 001
title: OpenTelemetry Collector for Observability Pipeline
status: accepted
date: 2025-12-14
---

# OpenTelemetry Collector for Centralized Observability Pipeline

## Context and Problem Statement

We need a comprehensive observability solution for distributed services written in multiple languages (C#, Go, Python, Rust, C++). How do we collect, process and route traces, metrics and logs to backend systems while avoiding vendor lock-in and minimizing instrumentation complexity?

## Decision Drivers

* **Vendor Neutrality**: Avoid lock-in to proprietary observability platforms
* **Multi-Language Support**: Unified approach across C#, Go, Python, Rust, C++
* **Backend Flexibility**: Ability to switch between Jaeger/Tempo, Prometheus/Graphite, Loki/Elasticsearch
* **Centralized Processing**: Single pipeline for filtering, sampling and enrichment
* **Production Readiness**: Battle-tested in cloud-native environments
* **Developer Experience**: Simple instrumentation, minimal code changes

## Considered Options

* **Option 1: OpenTelemetry Collector** - Vendor-neutral telemetry pipeline
* **Option 2: Direct Backend Integration** - Services send directly to Jaeger/Prometheus/Loki
* **Option 3: Proprietary APM Platform** - Datadog/New Relic/Dynatrace agents

## Decision Outcome

Chosen option: **OpenTelemetry Collector (Option 1)**, because it provides vendor-neutral observability with backend flexibility, centralized processing and CNCF standard compliance.

### Consequences

* **Good**: Backend-agnostic (switch Jaeger → Tempo without code changes)
* **Good**: Single instrumentation approach across all languages (OTLP protocol)
* **Good**: Centralized pipeline for sampling, filtering, enrichment
* **Good**: Future-proof (CNCF graduated project, industry standard)
* **Good**: No vendor lock-in (open source, portable)
* **Bad**: Additional infrastructure component to manage (collector deployment)
* **Bad**: Learning curve for collector configuration (pipelines, processors, exporters)
* **Neutral**: More moving parts than direct integration (trade complexity for flexibility)

### Confirmation

Success criteria met:
- All 5 languages sending telemetry via OTLP to collector
- Traces visible in Jaeger, metrics in Prometheus, logs in Loki

Success criteria to be addressed:
- Backend switch tested (Jaeger → Zipkin requires only collector config change)
- Centralized sampling and filtering working
- Zero code changes needed to switch backends

Post-Decision Testing:
1. Backend switch test: `scripts/test-backend-switch.sh` (**TODO**)
2. Performance: `make compose-test` (generates load)

## Pros and Cons of the Options

### Option 1: OpenTelemetry Collector (Chosen)

* **Good**: **Vendor-neutral** - No lock-in to specific backends
* **Good**: **Backend flexibility** - Change Jaeger → Tempo, Prometheus → Graphite with config only
* **Good**: **Centralized processing** - Sampling, filtering, enrichment in one place
* **Good**: **Multi-backend export** - Send same data to multiple backends (e.g., Jaeger + Zipkin)
* **Good**: **CNCF standard** - Industry-wide adoption, future-proof
* **Good**: **Language-agnostic** - Same OTLP protocol for all services
* **Good**: **Telemetry correlation** - Traces, metrics, logs share trace_id/span_id
* **Neutral**: Additional component to deploy and monitor
* **Bad**: Collector is single point of failure (mitigated by clustering in production)
* **Bad**: Configuration complexity (YAML pipelines)
* **Implementation**:
  ```yaml
  # Collector config - single change switches backends
  exporters:
    jaeger:  # Change to zipkin/tempo/otlp
      endpoint: jaeger:14250
    prometheus:  # Change to graphite/influxdb
      endpoint: prometheus:9090
  ```

### Option 2: Direct Backend Integration

* **Good**: Fewer components (no collector)
* **Good**: Simpler initial setup
* **Bad**: **Vendor lock-in** - Code changes needed to switch backends
* **Bad**: **Language-specific SDKs** - Different instrumentation per language
* **Bad**: **No centralized processing** - Sampling/filtering logic in each service
* **Bad**: **Multi-backend requires code changes** - Can't send to both Jaeger + Zipkin easily
* **Bad**: **Tight coupling** - Services know about backend infrastructure
* **Example Problem**:
  ```go
  // Switching from Jaeger to Tempo requires code changes
  // Before (Jaeger):
  exporter, _ := jaeger.New(jaeger.WithCollectorEndpoint(...))
  
  // After (Tempo):
  exporter, _ := otlpgrpc.New(context.Background(), 
      otlpgrpc.WithEndpoint("tempo:4317"))
  // Every service needs redeployment
  ```

### Option 3: Proprietary APM Platform (Datadog, New Relic, Dynatrace)

* **Good**: Comprehensive all-in-one solution
* **Good**: Advanced features (alerting, anomaly detection, APM)
* **Good**: Managed service (less operational overhead)
* **Bad**: **Vendor lock-in** - Difficult/expensive to migrate
* **Bad**: **Cost** - Per-host or per-GB pricing can be expensive at scale
* **Bad**: **Proprietary SDKs** - Tied to vendor-specific APIs
* **Bad**: **Data gravity** - Historical data locked in platform
* **Bad**: **Not open source** - Can't customize or self-host
* **Example Cost**:
  ```
  Datadog APM: ~$31/host/month + $1.27/GB ingested
  10 hosts + 50GB/day = $310 + $1,905 = $2,215/month
  
  vs OpenTelemetry + self-hosted: Infrastructure cost only (~$100-300/month)
  ```

## Implementation Architecture

### Current Setup

```
┌─────────────────────────────────────────────────────────┐
│                 OpenTelemetry Services                   │
│  C# | Go | Python | Rust | C++                          │
│  ↓    ↓     ↓       ↓      ↓                            │
│  OTLP (gRPC) - Port 4317                                │
└─────────────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────────┐
│           OpenTelemetry Collector                        │
│  ┌────────────────────────────────────────────────┐    │
│  │ Receivers → Processors → Exporters             │    │
│  │  (OTLP)    (sampling,     (Jaeger, Prom, Loki)│    │
│  │            filtering)                          │    │
│  └────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
          ↓                 ↓                ↓
    ┌─────────┐      ┌───────────┐   ┌──────────┐
    │ Jaeger  │      │Prometheus │   │  Loki    │
    │(Traces) │      │(Metrics)  │   │ (Logs)   │
    └─────────┘      └───────────┘   └──────────┘
          ↓                 ↓                ↓
              ┌─────────────────────────┐
              │       Grafana           │
              │ (Unified Visualization) │
              └─────────────────────────┘
```

### Backend Switch Example (Zero Code Changes)

**Scenario**: Switch from Jaeger to Tempo for traces

```yaml
# Before (Jaeger)
exporters:
  jaeger:
    endpoint: jaeger:14250
    tls:
      insecure: true

# After (Tempo) - Only collector config changed
exporters:
  otlp:
    endpoint: tempo:4317
    tls:
      insecure: true

# Services continue sending OTLP, no changes needed
```

### Centralized Processing Benefits

```yaml
processors:
  # Tail sampling (1% of traces)
  probabilistic_sampler:
    sampling_percentage: 1.0
  
  # Add environment labels
  resource:
    attributes:
      - key: environment
        value: production
        action: upsert
  
  # Drop noisy metrics
  filter:
    metrics:
      exclude:
        match_type: regexp
        metric_names:
          - "health_check.*"
```

## Tradeoffs Explained

| Aspect | Collector | Direct Integration | Proprietary APM |
|--------|-----------|-------------------|-----------------|
| **Vendor Lock-in** | ✅ None | ❌ High | ❌ Very High |
| **Backend Flexibility** | ✅ Config-only | ❌ Code changes | ❌ Impossible |
| **Instrumentation** | ✅ Unified OTLP | ⚠️ Per-language | ⚠️ Vendor SDK |
| **Centralized Processing** | ✅ Yes | ❌ No | ✅ Yes (managed) |
| **Cost (Self-hosted)** | ⚠️ Infra only | ✅ Minimal | ❌ $$$$ |
| **Complexity** | ⚠️ Moderate | ✅ Simple | ✅ Simple (managed) |
| **Multi-backend Export** | ✅ Easy | ❌ Hard | ❌ Impossible |
| **Open Source** | ✅ Yes | ⚠️ Depends | ❌ No |

## Migration Path & Future Considerations

### Current (PoC)
- Docker Compose deployment
- Jaeger + Prometheus + Loki
- Single collector instance

### Production Ready
1. **High Availability**: Deploy collector as DaemonSet/Deployment in K8s
2. **Persistent Storage**: Use cloud storage for Prometheus/Loki/Tempo
3. **Backend Upgrade**: Switch to Tempo (better for cloud-native traces)
4. **Managed Options**: 
   - Grafana Cloud (managed Tempo/Loki/Prometheus)
   - AWS CloudWatch (via OTLP exporter)
   - Azure Monitor (via OTLP exporter)
5. **Advanced Features**:
   - Adaptive sampling
   - Trace-based alerts
   - Service mesh integration (Istio telemetry)

### Backend Evolution (No Code Changes)

```
Today:       Jaeger + Prometheus + Loki
Next Month:  Tempo + Mimir + Loki (better cloud-native)
Next Year:   Grafana Cloud (fully managed)

All via collector config updates only
```

## More Information

**Resources**:
- [OpenTelemetry Docs](https://opentelemetry.io/docs/)
- [Collector Configuration](https://opentelemetry.io/docs/collector/configuration/)
- [CNCF Observability Landscape](https://landscape.cncf.io/card-mode?category=observability-and-analysis)
- [Prometheus vs Graphite](https://prometheus.io/docs/introduction/comparison/)
- [Jaeger vs Tempo vs Zipkin](https://signoz.io/blog/jaeger-vs-tempo/)

**Cost Analysis**:
- Self-hosted (PoC): ~$0 (local Docker)
- Self-hosted (Production): ~$200-500/month (K8s cluster + storage)
- Grafana Cloud: ~$500-2000/month (pay-as-you-go)
- Datadog APM: ~$2000-5000/month (10-host example)

---

**Decision Rationale**:

OpenTelemetry Collector provides the optimal balance of:
1. **Flexibility**: Switch backends without code changes
2. **Standardization**: CNCF standard, future-proof
3. **Control**: Self-hosted, open source
4. **Cost**: No per-host/per-GB fees
5. **Simplicity**: Unified instrumentation across languages

The additional operational complexity (managing collector) is justified by:
- Avoiding vendor lock-in costs
- Future-proofing observability stack
- Enabling multi-cloud/hybrid deployments
- Maintaining data sovereignty and control
