#include <iostream>
#include <memory>
#include <string>
#include <cstdlib>
#include <chrono>
#include <iomanip>
#include <sstream>

#include "httplib.h"
#include "nlohmann/json.hpp"

#include "opentelemetry/exporters/otlp/otlp_grpc_exporter_factory.h"
#include "opentelemetry/exporters/otlp/otlp_grpc_metric_exporter_factory.h"
#include "opentelemetry/exporters/otlp/otlp_grpc_log_record_exporter_factory.h"
#include "opentelemetry/sdk/trace/tracer_provider_factory.h"
#include "opentelemetry/sdk/trace/simple_processor_factory.h"
#include "opentelemetry/sdk/metrics/meter_provider_factory.h"
#include "opentelemetry/sdk/metrics/export/periodic_exporting_metric_reader.h"
#include "opentelemetry/sdk/logs/logger_provider_factory.h"
#include "opentelemetry/sdk/logs/simple_log_record_processor_factory.h"
#include "opentelemetry/trace/provider.h"
#include "opentelemetry/metrics/provider.h"
#include "opentelemetry/logs/provider.h"

using json = nlohmann::json;
namespace trace_api = opentelemetry::trace;
namespace trace_sdk = opentelemetry::sdk::trace;
namespace metrics_api = opentelemetry::metrics;
namespace metrics_sdk = opentelemetry::sdk::metrics;
namespace logs_api = opentelemetry::logs;
namespace logs_sdk = opentelemetry::sdk::logs;
namespace otlp = opentelemetry::exporter::otlp;

std::string get_env(const std::string& key, const std::string& default_value) {
    const char* val = std::getenv(key.c_str());
    return val ? std::string(val) : default_value;
}

std::string get_current_timestamp() {
    auto now = std::chrono::system_clock::now();
    auto time = std::chrono::system_clock::to_time_t(now);
    std::stringstream ss;
    ss << std::put_time(std::gmtime(&time), "%Y-%m-%dT%H:%M:%SZ");
    return ss.str();
}

void init_telemetry() {
    std::string service_name = get_env("OTEL_SERVICE_NAME", "cpp-service");
    std::string otlp_endpoint = get_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4317");

    opentelemetry::sdk::resource::ResourceAttributes attributes = {
        {"service.name", service_name}
    };
    auto resource = opentelemetry::sdk::resource::Resource::Create(attributes);

    // Tracing
    otlp::OtlpGrpcExporterOptions trace_opts;
    trace_opts.endpoint = otlp_endpoint;
    trace_opts.use_ssl_credentials = false;

    auto trace_exporter = otlp::OtlpGrpcExporterFactory::Create(trace_opts);
    auto processor = trace_sdk::SimpleSpanProcessorFactory::Create(std::move(trace_exporter));
    std::shared_ptr<trace_api::TracerProvider> provider =
        trace_sdk::TracerProviderFactory::Create(std::move(processor), resource);
    trace_api::Provider::SetTracerProvider(provider);

    // Metrics - FIX: Convert unique_ptr to shared_ptr
    otlp::OtlpGrpcMetricExporterOptions metric_opts;
    metric_opts.endpoint = otlp_endpoint;
    metric_opts.use_ssl_credentials = false;

    auto metric_exporter = otlp::OtlpGrpcMetricExporterFactory::Create(metric_opts);
    metrics_sdk::PeriodicExportingMetricReaderOptions reader_options;
    reader_options.export_interval_millis = std::chrono::milliseconds(1000);
    auto reader = std::make_unique<metrics_sdk::PeriodicExportingMetricReader>(
        std::move(metric_exporter), reader_options);
    
    auto meter_provider_unique = metrics_sdk::MeterProviderFactory::Create();
    auto meter_provider_raw = meter_provider_unique.release(); // Release from unique_ptr
    std::shared_ptr<metrics_api::MeterProvider> meter_provider(meter_provider_raw); // Wrap in shared_ptr
    
    std::static_pointer_cast<metrics_sdk::MeterProvider>(meter_provider)->AddMetricReader(std::move(reader));
    metrics_api::Provider::SetMeterProvider(meter_provider);

    // Logs
    otlp::OtlpGrpcLogRecordExporterOptions log_opts;
    log_opts.endpoint = otlp_endpoint;
    log_opts.use_ssl_credentials = false;

    auto log_exporter = otlp::OtlpGrpcLogRecordExporterFactory::Create(log_opts);
    auto log_processor = logs_sdk::SimpleLogRecordProcessorFactory::Create(std::move(log_exporter));
    std::shared_ptr<logs_api::LoggerProvider> logger_provider =
        logs_sdk::LoggerProviderFactory::Create(std::move(log_processor), resource);
    logs_api::Provider::SetLoggerProvider(logger_provider);

    std::cout << "Telemetry initialized for service: " << service_name << std::endl;
}

int main() {
    init_telemetry();

    httplib::Server svr;

    svr.Get("/", [](const httplib::Request&, httplib::Response& res) {
        json response = {
            {"message", "C++ OpenTelemetry Service"}
        };
        res.set_content(response.dump(), "application/json");
    });

    svr.Get("/api/hello", [](const httplib::Request&, httplib::Response& res) {
        // Get tracer and create a span
        auto tracer = trace_api::Provider::GetTracerProvider()->GetTracer("cpp-service");
        auto span = tracer->StartSpan("handle_hello");
        auto scope = tracer->WithActiveSpan(span);
        
        // Add span attributes
        span->SetAttribute("http.method", "GET");
        span->SetAttribute("http.route", "/api/hello");
        
        // Emit log
        auto logger = logs_api::Provider::GetLoggerProvider()->GetLogger("cpp-service");
        logger->EmitLogRecord(logs_api::Severity::kInfo, "Hello endpoint called from C++ service");
        
        // Record metric
        auto meter = metrics_api::Provider::GetMeterProvider()->GetMeter("cpp-service");
        auto counter = meter->CreateUInt64Counter("http.server.requests");
        counter->Add(1, {{"http.route", "/api/hello"}, {"http.method", "GET"}});
        
        json response = {
            {"message", "Hello from C++ with OpenTelemetry!"},
            {"timestamp", get_current_timestamp()}
        };
        res.set_content(response.dump(), "application/json");
        
        span->End();
    });

    std::cout << "Starting C++ OpenTelemetry service on :8080" << std::endl;
    svr.listen("0.0.0.0", 8080);

    return 0;
}
