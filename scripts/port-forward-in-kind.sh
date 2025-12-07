#!/bin/bash

set -e

# Parse arguments
FORWARD_OBS=false
FORWARD_SVC=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --obs|--observability)
            FORWARD_OBS=true
            shift
            ;;
        --svc|--services)
            FORWARD_SVC=true
            shift
            ;;
        --all)
            FORWARD_OBS=true
            FORWARD_SVC=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--obs|--observability] [--svc|--services] [--all]"
            exit 1
            ;;
    esac
done

# Default to all if nothing specified
if [ "$FORWARD_OBS" = false ] && [ "$FORWARD_SVC" = false ]; then
    FORWARD_OBS=true
    FORWARD_SVC=true
fi

# Trap to cleanup all background jobs on exit
cleanup() {
    echo ""
    echo "Stopping all port-forwards..."
    jobs -p | xargs -r kill 2>/dev/null || true
    exit 0
}

trap cleanup SIGINT SIGTERM EXIT

echo "Starting port-forwards for Kind cluster..."
echo ""

# Display and forward observability stack
if [ "$FORWARD_OBS" = true ]; then
    echo "Observability Stack:"
    echo "  Grafana:    http://localhost:3000"
    echo "  Jaeger:     http://localhost:16686"
    echo "  Prometheus: http://localhost:9090"
    echo ""
    
    kubectl port-forward -n default svc/grafana 3000:80 &
    kubectl port-forward -n default svc/jaeger-query 16686:16686 &
    kubectl port-forward -n default svc/prometheus-server 9090:80 &
fi

# Display and forward OpenTelemetry services
if [ "$FORWARD_SVC" = true ]; then
    echo "OpenTelemetry Services:"
    echo "  C#:     http://localhost:5001"
    echo "  Go:     http://localhost:5002"
    echo "  Python: http://localhost:5003"
    echo "  Rust:   http://localhost:5004"
    echo "  C++:    http://localhost:5005"
    echo ""
    
    kubectl port-forward -n default svc/csharp-otel-service 5001:8080 &
    kubectl port-forward -n default svc/go-otel-service 5002:8080 &
    kubectl port-forward -n default svc/python-otel-service 5003:8080 &
    kubectl port-forward -n default svc/rust-otel-service 5004:8080 &
    kubectl port-forward -n default svc/cpp-otel-service 5005:8080 &
fi

echo "Press Ctrl+C to stop all port-forwards"
echo ""

# Wait for all background jobs
wait