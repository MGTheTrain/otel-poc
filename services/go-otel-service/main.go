package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlplog/otlploggrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	otellog "go.opentelemetry.io/otel/log"
	"go.opentelemetry.io/otel/log/global"
	"go.opentelemetry.io/otel/propagation"
	sdklog "go.opentelemetry.io/otel/sdk/log"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.24.0"
)

func initProvider() (func(), error) {
	ctx := context.Background()

	serviceName := getEnv("OTEL_SERVICE_NAME", "go-service")
	otlpEndpoint := getEnv("OTEL_EXPORTER_OTLP_ENDPOINT", "localhost:4317")

	res, err := resource.New(ctx,
		resource.WithAttributes(semconv.ServiceName(serviceName)),
	)
	if err != nil {
		return nil, err
	}

	// Tracing
	traceExporter, err := otlptracegrpc.New(ctx,
		otlptracegrpc.WithEndpoint(otlpEndpoint),
		otlptracegrpc.WithInsecure(),
	)
	if err != nil {
		return nil, err
	}

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(traceExporter),
		sdktrace.WithResource(res),
	)
	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{},
		propagation.Baggage{},
	))

	// Metrics
	metricExporter, err := otlpmetricgrpc.New(ctx,
		otlpmetricgrpc.WithEndpoint(otlpEndpoint),
		otlpmetricgrpc.WithInsecure(),
	)
	if err != nil {
		return nil, err
	}

	mp := sdkmetric.NewMeterProvider(
		sdkmetric.WithReader(sdkmetric.NewPeriodicReader(metricExporter)),
		sdkmetric.WithResource(res),
	)
	otel.SetMeterProvider(mp)

	// Logs
	logExporter, err := otlploggrpc.New(ctx,
		otlploggrpc.WithEndpoint(otlpEndpoint),
		otlploggrpc.WithInsecure(),
	)
	if err != nil {
		return nil, err
	}

	lp := sdklog.NewLoggerProvider(
		sdklog.WithProcessor(sdklog.NewBatchProcessor(logExporter)),
		sdklog.WithResource(res),
	)
	global.SetLoggerProvider(lp)

	return func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		tp.Shutdown(ctx)
		mp.Shutdown(ctx)
		lp.Shutdown(ctx)
	}, nil
}

func getEnv(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok {
		return value
	}
	return fallback
}

func main() {
	shutdown, err := initProvider()
	if err != nil {
		log.Fatal(err)
	}
	defer shutdown()

	router := gin.Default()
	router.Use(otelgin.Middleware("go-service"))

	router.GET("/", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"message": "Go OpenTelemetry Service"})
	})

	router.GET("/api/hello", func(c *gin.Context) {
		logger := global.GetLoggerProvider().Logger("go-service")

		// Create API log.Record
		var record otellog.Record
		record.SetTimestamp(time.Now())
		record.SetBody(otellog.StringValue("Hello endpoint called from Go service"))
		record.SetSeverity(otellog.SeverityInfo)

		logger.Emit(c.Request.Context(), record)

		c.JSON(http.StatusOK, gin.H{
			"message":   "Hello from Go with OpenTelemetry!",
			"timestamp": time.Now().UTC(),
		})
	})

	log.Println("Server starting on :8080")
	router.Run(":8080")
}
