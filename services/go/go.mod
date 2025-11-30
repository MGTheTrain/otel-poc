module go-otel-service

go 1.21

require (
	github.com/gin-gonic/gin v1.9.1
	go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin v0.49.0
	go.opentelemetry.io/otel v1.24.0
	go.opentelemetry.io/otel/exporters/otlp/otlplog/otlploggrpc v0.0.0-20240221224432-82ca00d6b0cc
	go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc v1.24.0
	go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc v1.24.0
	go.opentelemetry.io/otel/log v0.0.0-20240221224432-82ca00d6b0cc
	go.opentelemetry.io/otel/sdk v1.24.0
	go.opentelemetry.io/otel/sdk/log v0.0.0-20240221224432-82ca00d6b0cc
	go.opentelemetry.io/otel/sdk/metric v1.24.0
)
