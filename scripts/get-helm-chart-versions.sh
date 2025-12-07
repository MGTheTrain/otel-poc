#!/bin/bash

echo "=== DEPLOYED CHART VERSIONS ==="
echo ""

echo "Jaeger:"
helm list -o json | jq -r '.[] | select(.name=="jaeger") | "  Chart: \(.chart)\n  App Version: \(.app_version)"'

echo ""
echo "Loki:"
helm list -o json | jq -r '.[] | select(.name=="loki") | "  Chart: \(.chart)\n  App Version: \(.app_version)"'

echo ""
echo "Prometheus:"
helm list -o json | jq -r '.[] | select(.name=="prometheus") | "  Chart: \(.chart)\n  App Version: \(.app_version)"'

echo ""
echo "OTel Collector:"
helm list -o json | jq -r '.[] | select(.name=="otel-collector") | "  Chart: \(.chart)\n  App Version: \(.app_version)"'

echo ""
echo "Grafana:"
helm list -o json | jq -r '.[] | select(.name=="grafana") | "  Chart: \(.chart)\n  App Version: \(.app_version)"'