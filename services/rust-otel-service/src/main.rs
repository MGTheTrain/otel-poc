use actix_web::{get, web, App, HttpServer, Responder};
use opentelemetry::{global, trace::TracerProvider};
use opentelemetry_otlp::WithExportConfig;
use opentelemetry_sdk::{logs::SdkLoggerProvider, Resource, runtime};
use opentelemetry_appender_tracing::layer::OpenTelemetryTracingBridge;
use serde::Serialize;
use std::env;
use tracing::{info, Level};
use tracing_subscriber::{layer::SubscriberExt, Registry};
use tracing::info_span;

#[derive(Serialize)]
struct Message {
    message: String,
    timestamp: String,
}

#[tracing::instrument(name = "root_endpoint")]
#[get("/")]
async fn root() -> impl Responder {
    let _span = info_span!("root_endpoint").entered();
    web::Json(Message {
        message: "Rust OpenTelemetry Service".to_string(),
        timestamp: chrono::Utc::now().to_rfc3339(),
    })
}

#[tracing::instrument(name = "hello_endpoint")]
#[get("/api/hello")]
async fn hello() -> impl Responder {
    let _span = info_span!("hello_endpoint").entered();
    info!("Hello endpoint called from Rust service");
    
    web::Json(Message {
        message: "Hello from Rust with OpenTelemetry!".to_string(),
        timestamp: chrono::Utc::now().to_rfc3339(),
    })
}

fn init_telemetry() -> Result<(), Box<dyn std::error::Error>> {
    let service_name = env::var("OTEL_SERVICE_NAME")
        .unwrap_or_else(|_| "rust-service".to_string());
    let otlp_endpoint = env::var("OTEL_EXPORTER_OTLP_ENDPOINT")
        .unwrap_or_else(|_| "http://localhost:4317".to_string());

    // Resource
    let resource = Resource::builder()
        .with_service_name(service_name.clone())
        .build();

    // Tracing
    let trace_exporter = opentelemetry_otlp::SpanExporter::builder()
        .with_tonic()
        .with_endpoint(otlp_endpoint.clone())
        .build()?;

    let tracer_provider = opentelemetry_sdk::trace::SdkTracerProvider::builder()
        .with_batch_exporter(trace_exporter)
        .with_resource(resource.clone())
        .build();

    global::set_tracer_provider(tracer_provider.clone());

    // Metrics
    let metric_exporter = opentelemetry_otlp::MetricExporter::builder()
        .with_tonic()
        .with_endpoint(otlp_endpoint.clone())
        .build()?;

    let meter_provider = opentelemetry_sdk::metrics::SdkMeterProvider::builder()
        .with_reader(
            opentelemetry_sdk::metrics::PeriodicReader::builder(metric_exporter)
                .build()
        )
        .with_resource(resource.clone())
        .build();

    global::set_meter_provider(meter_provider);

    // Logs
    let log_exporter = opentelemetry_otlp::LogExporter::builder()
        .with_tonic()
        .with_endpoint(otlp_endpoint)
        .build()?;

    let logger_provider = SdkLoggerProvider::builder()
        .with_batch_exporter(log_exporter)
        .with_resource(resource)
        .build();

    // Tracing subscriber
    let telemetry_layer = tracing_opentelemetry::layer()
        .with_tracer(tracer_provider.tracer("rust-service"));
    let otel_log_layer = OpenTelemetryTracingBridge::new(&logger_provider);
    
    let subscriber = Registry::default()
        .with(tracing_subscriber::fmt::layer())
        .with(telemetry_layer)
        .with(otel_log_layer)
        .with(tracing_subscriber::filter::LevelFilter::from_level(Level::INFO));

    tracing::subscriber::set_global_default(subscriber)?;

    Ok(())
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    init_telemetry().expect("Failed to initialize telemetry");

    println!("Starting Rust OpenTelemetry service on :8080");

    HttpServer::new(|| {
        App::new()
            .service(root)
            .service(hello)
    })
    .bind(("0.0.0.0", 8080))?
    .run()
    .await
}
