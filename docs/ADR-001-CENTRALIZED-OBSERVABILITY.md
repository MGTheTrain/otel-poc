---
parent: Decisions
nav_order: 001
title: OpenTelemetry Collector for Observability Pipeline
status: accepted
date: 2025-12-14
decision-makers: Architecture Team, Platform Engineering
consulted: Development Teams (C#, Go, Python, Rust, C++)
informed: Operations Team, SRE Team
---

# OpenTelemetry Collector for Centralized Observability Pipeline

## Context and Problem Statement

We need a comprehensive observability solution for distributed services written in multiple languages (C#, Go, Python, Rust, C++). The solution must collect traces, metrics, and logs from heterogeneous services and route them to backend systems. How do we achieve this while avoiding vendor lock-in, minimizing per-service instrumentation complexity, and maintaining flexibility to change backend systems as requirements evolve?

## Decision Drivers

* **Vendor Neutrality**: Avoid lock-in to proprietary observability platforms
* **Multi-Language Support**: Unified approach across C#, Go, Python, Rust, C++
* **Backend Flexibility**: Ability to switch between backend systems (Jaeger/Tempo, Prometheus/Mimir, Loki/Elasticsearch) without code changes
* **Centralized Processing**: Single pipeline for filtering, sampling, and enrichment across all services
* **Production Readiness**: Proven in cloud-native production environments
* **Developer Experience**: Simple instrumentation with minimal per-service configuration
* **Future-Proofing**: Industry standard with long-term ecosystem support

## Considered Options

* **OpenTelemetry Collector** - Vendor-neutral telemetry pipeline with CNCF standard
* **Direct Backend Integration** - Services send telemetry directly to Jaeger/Prometheus/Loki
* **Proprietary APM Platform** - Datadog/New Relic/Dynatrace agents and managed services

## Decision Outcome

Chosen option: **OpenTelemetry Collector**, because it provides vendor-neutral observability with backend flexibility, centralized processing, and CNCF standard compliance. The collector enables switching backend systems through configuration changes alone, avoiding code changes across multiple services and languages. While it introduces an additional infrastructure component, the architectural flexibility and vendor independence justify the operational complexity.

### Consequences

* Good, because backend-agnostic design enables switching from Jaeger to Tempo or Prometheus to Mimir with configuration changes only
* Good, because single OTLP protocol across all languages simplifies instrumentation and reduces language-specific SDK complexity
* Good, because centralized pipeline enables consistent sampling, filtering, and enrichment policies across all services
* Good, because CNCF graduated project status provides long-term ecosystem support and industry-wide adoption
* Good, because multi-backend export capability enables sending same telemetry to multiple systems (e.g., Jaeger + Zipkin simultaneously)
* Good, because open-source ownership eliminates vendor lock-in costs and enables customization
* Bad, because introduces additional infrastructure component requiring deployment, monitoring, and operational expertise
* Bad, because collector configuration requires understanding of receivers, processors, and exporters concepts
* Bad, because collector becomes single point of failure unless clustered (mitigated in production with HA deployment)
* Neutral, because additional operational complexity trades off against architectural flexibility and long-term cost benefits

### Confirmation

Decision validated through PoC implementation demonstrating:
- All five languages (C#, Go, Python, Rust, C++) successfully sending telemetry via OTLP to collector
- Traces visible in Jaeger UI with proper span relationships
- Metrics scraped by Prometheus with correct labels and dimensions
- Logs ingested by Loki with trace correlation
- Backend switch verified by changing collector configuration from Jaeger to alternative backend (test pending)

Implementation demonstrates zero application code changes required when switching backend systems, confirming architectural flexibility goal.

## Pros and Cons of the Options

### OpenTelemetry Collector

* Good, because vendor-neutral design eliminates lock-in to specific backend platforms
* Good, because backend flexibility enables changing from Jaeger to Tempo or Prometheus to Graphite with configuration changes only
* Good, because centralized processing consolidates sampling, filtering, and enrichment logic in single location
* Good, because multi-backend export sends same telemetry to multiple systems without application changes
* Good, because CNCF graduated project status ensures industry-wide adoption and long-term support
* Good, because language-agnostic OTLP protocol simplifies instrumentation across heterogeneous services
* Good, because telemetry correlation (shared trace_id/span_id across traces, metrics, logs) simplifies troubleshooting
* Good, because open-source ownership enables customization and self-hosting without licensing constraints
* Neutral, because additional infrastructure component requires deployment planning and operational expertise
* Bad, because collector becomes single point of failure requiring high-availability deployment in production
* Bad, because YAML pipeline configuration has moderate learning curve for receivers, processors, exporters

### Direct Backend Integration

* Good, because fewer infrastructure components reduces deployment complexity
* Good, because simpler initial setup with direct service-to-backend connections
* Good, because eliminates collector as potential failure point
* Bad, because vendor lock-in—switching from Jaeger to Tempo requires code changes in every service
* Bad, because language-specific SDKs require different instrumentation approaches per language
* Bad, because no centralized processing—sampling and filtering logic duplicated across services
* Bad, because multi-backend support requires complex application-level logic to send to multiple destinations
* Bad, because tight coupling between services and backend infrastructure violates separation of concerns
* Bad, because backend migration requires coordinated code changes, testing, and deployment across all services

### Proprietary APM Platform

* Good, because comprehensive all-in-one solution with integrated observability features
* Good, because advanced capabilities (anomaly detection, alerting, APM) included out-of-box
* Good, because managed service reduces operational overhead for backend systems
* Good, because polished user interfaces and dashboards optimized for specific platform
* Neutral, because cloud-native platforms (Azure Monitor, AWS CloudWatch, GCP Cloud Trace) support OTLP export, reducing some lock-in concerns
* Bad, because severe vendor lock-in makes migration difficult and expensive (especially for traditional APMs)
* Bad, because cost scales with volume—per-host, per-GB, or per-span pricing can be expensive at scale
* Bad, because proprietary SDKs and agents tie applications to vendor-specific APIs (though OTLP support improving)
* Bad, because data gravity—historical telemetry data locked in platform complicates migration
* Bad, because no self-hosting option for cost control or data sovereignty requirements
* Neutral, because comprehensive features valuable if long-term commitment acceptable

## More Information

**Decision Context**:
This decision prioritizes long-term architectural flexibility and vendor independence over initial operational simplicity. For organizations with existing APM investments or strong vendor relationships, proprietary platforms may be appropriate. For greenfield projects or those requiring multi-cloud portability, OpenTelemetry Collector provides superior flexibility.

**Cost Considerations** (qualitative comparison):
- **Self-hosted OpenTelemetry**: Infrastructure costs only (compute, storage)
- **Managed Grafana Cloud**: Pay-as-you-go with predictable per-GB pricing
- **Proprietary APM**: Per-host + per-GB pricing often significantly higher

Organizations should evaluate total cost of ownership including operational overhead, vendor pricing, and data volume growth projections.

**Backend Evolution Path**:
The collector enables iterative backend evolution without application impact:
- **Today**: Jaeger + Prometheus + Loki (self-hosted)
- **Future**: Tempo + Mimir + Loki (optimized for cloud-native scale)
- **Cloud-Native**: Azure Monitor, AWS CloudWatch/X-Ray, or GCP Cloud Operations (OTLP-native)
- **Managed OSS**: Grafana Cloud or equivalent as requirements evolve

All transitions accomplished through collector configuration updates without service code changes.

**Production Deployment Considerations**:
- Deploy collector as Kubernetes DaemonSet or Deployment for high availability
- Configure persistent storage backends for production scale
- Implement backend redundancy (primary + backup exporters)
- Monitor collector health and resource utilization
- Consider managed services with OTLP support: Azure Monitor, AWS CloudWatch (via OTLP/ADOT), GCP Cloud Trace/Operations, or Grafana Cloud

**Related Resources**:
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Collector Configuration Reference](https://opentelemetry.io/docs/collector/configuration/)

**Related Decisions**:
- Future ADR: Observability backend selection (Tempo vs Jaeger, Mimir vs Prometheus)

**Re-evaluation Triggers**:
- If operational overhead of collector becomes prohibitive, consider managed OpenTelemetry services
- If organization standardizes on specific APM platform long-term, re-evaluate vendor lock-in tradeoffs
- If backend switching proves unnecessary in practice, simpler direct integration may suffice
- If collector performance becomes bottleneck, evaluate architecture patterns (sidecar vs centralized)