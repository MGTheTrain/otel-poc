#!/bin/bash

echo "🚀 Starting OpenTelemetry Observability Stack"
echo "=============================================="

# Start the stack
docker-compose -f docker-compose.otel-stack.yml up -d

echo ""
echo "⏳ Waiting for services to be ready..."
sleep 10

echo ""
echo "✅ Stack is ready! Access the following:"
echo ""
echo "📊 Grafana:        http://localhost:3000 (admin/admin)"
echo "🔍 Jaeger:         http://localhost:16686"
echo "📈 Prometheus:     http://localhost:9090"
echo ""
echo "🔧 Microservices:"
echo "   C#:             http://localhost:5001/api/hello"
echo "   Go:             http://localhost:5002/api/hello"
echo "   Python:         http://localhost:5003/api/hello"
echo "   Rust:           http://localhost:5004/api/hello"
echo "   C++:            http://localhost:5005/api/hello"
echo ""
echo "💡 Generate traffic with: ./generate-traffic.sh"
echo "🛑 Stop stack with: docker-compose -f docker-compose.otel-stack.yml down"
