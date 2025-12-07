#!/bin/bash

echo "Generating traffic to all services in Kind cluster..."
echo ""

# Service endpoints (use kubectl port-forward or direct pod IPs)
SERVICES=(
    "python-otel-service:8080"
    "go-otel-service:8080"
    "csharp-otel-service:8080"
    "rust-otel-service:8080"
    "cpp-otel-service:8080"
)

for i in {1..20}; do
    echo "Request batch $i/20"
    
    for svc in "${SERVICES[@]}"; do
        SERVICE_NAME="${svc%%:*}"
        PORT="${svc##*:}"
        
        # Use kubectl exec to curl from within the cluster
        if kubectl get svc "$SERVICE_NAME" -n default &>/dev/null; then
            kubectl run curl-test-$RANDOM --rm -i --restart=Never --image=curlimages/curl:latest -- \
                curl -s "http://${SERVICE_NAME}.default.svc.cluster.local:${PORT}/api/hello" &>/dev/null && \
                echo "  ✓ $SERVICE_NAME" || echo "  ✗ $SERVICE_NAME (failed)"
        fi
    done
    
    echo ""
    sleep 1
done

echo "Traffic generation complete"
echo "View traces at: http://localhost:16686 (Jaeger)"
echo "View logs at: http://localhost:3000 (Grafana)"