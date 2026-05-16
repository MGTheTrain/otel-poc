# otel-poc

Umbrella chart for the OpenTelemetry PoC. Aggregates the
[`otel-platform`](../otel-platform) chart (Jaeger, Loki, Prometheus,
OTel Collector, Grafana) and the five service leaf charts under
[`../services/`](../services).

Don't install this directly — go through `make k8s-deploy`, which
builds and kind-loads the service images first.