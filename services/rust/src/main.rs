use actix_web::{get, web, App, HttpServer, Responder};
use opentelemetry::global;
use opentelemetry::KeyValue;
use opentelemetry_sdk::{runtime, Resource};
use opentelemetry_sdk::trace::TracerProvider;
use opentelemetry_sdk::metrics::MeterProvider;
use opentelemetry_otlp::{WithExportConfig, Protocol};
use serde::Serialize;
use std::env;
use tracing::{info, Level};
use tracing_subscriber::{layer::SubscriberExt, Registry};

#[derive(Serialize)]
struct Message {
    message: String,
    timestamp: String,
}

#[get("/")]
async fn root() -> impl Responder {
    web::Json(Message {
        message: "Rust OpenTelemetry Service".to_string(),
        timestamp: chrono::Utc::now().to_rfc3339(),
    })
}

#[get("/api/hello")]
async fn hello() -> impl Responder {
    info!("Hello endpoint called from Rust service");
    
    web::Json(Message {
        message: "Hello from Rust with OpenTelemetry!".to_string(),
        timestamp: chrono::Utc::now().to_rfc3339(),
    })
}

fn init_telemetry() -> Result<(), Box<dyn std::error::Error>> {
    let service_name = env::var("OTEL_SERVICE_NAME").unwrap_or_else(|_| "rust-service".to_string());
    let otlp_endpoint = env::var("OTEL_EXPORTER_OTLP_ENDPOINT")
        .unwrap_or_else(|_| "http://localhost:4317".to_string());

    // Resource
    let resource = Resource::new(vec![KeyValue::new("service.name", service_name.clone())]);

    // Tracing
    let tracer = opentelemetry_otlp::new_pipeline()
        .tracing()
        .with_exporter(
            opentelemetry_otlp::new_exporter()
                .tonic()
                .with_endpoint(&otlp_endpoint)
                .with_protocol(Protocol::Grpc),
        )
        .with_trace_config(
            opentelemetry_sdk::trace::config().with_resource(resource.clone()),
        )
        .install_batch(runtime::Tokio)?;

    global::set_tracer_provider(TracerProvider::builder()
        .with_config(opentelemetry_sdk::trace::config().with_resource(resource.clone()))
        .build());

    // Metrics
    let meter = opentelemetry_otlp::new_pipeline()
        .metrics(runtime::Tokio)
        .with_exporter(
            opentelemetry_otlp::new_exporter()
                .tonic()
                .with_endpoint(&otlp_endpoint)
                .with_protocol(Protocol::Grpc),
        )
        .with_resource(resource)
        .build()?;

    global::set_meter_provider(meter);

    // Logging with tracing
    let telemetry = tracing_opentelemetry::layer().with_tracer(tracer);
    let subscriber = Registry::default()
        .with(tracing_subscriber::fmt::layer())
        .with(telemetry)
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
