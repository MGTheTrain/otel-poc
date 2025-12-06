using OpenTelemetry;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using OpenTelemetry.Metrics;
using OpenTelemetry.Logs;

var builder = WebApplication.CreateBuilder(args);

var serviceName = Environment.GetEnvironmentVariable("OTEL_SERVICE_NAME") ?? "csharp-service";
var otlpEndpoint = Environment.GetEnvironmentVariable("OTEL_EXPORTER_OTLP_ENDPOINT") ?? "localhost:4317";

builder.Services.AddOpenTelemetry()
    .ConfigureResource(resource => resource.AddService(serviceName))
    .WithTracing(tracing => tracing
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddOtlpExporter(options => 
        {
            options.Endpoint = new Uri($"http://{otlpEndpoint}");
            options.Protocol = OpenTelemetry.Exporter.OtlpExportProtocol.Grpc;
        }))
    .WithMetrics(metrics => metrics
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddOtlpExporter(options => 
        {
            options.Endpoint = new Uri($"http://{otlpEndpoint}");
            options.Protocol = OpenTelemetry.Exporter.OtlpExportProtocol.Grpc;
        }));

// Configure logging
builder.Logging.AddOpenTelemetry(logging =>
{
    logging.IncludeFormattedMessage = true;
    logging.IncludeScopes = true;
    logging.AddOtlpExporter(options => 
    {
        options.Endpoint = new Uri($"http://{otlpEndpoint}");
        options.Protocol = OpenTelemetry.Exporter.OtlpExportProtocol.Grpc;
    });
});

var app = builder.Build();

app.MapGet("/", () => "C# OpenTelemetry Service");

app.MapGet("/api/hello", (ILogger<Program> logger) =>
{
    logger.LogInformation("Hello endpoint called from C# service");
    return new { message = "Hello from C# with OpenTelemetry!", timestamp = DateTime.UtcNow };
});

app.Run();