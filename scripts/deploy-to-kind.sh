#!/bin/bash
#
# deploy-to-kind.sh — install otel-poc into a kind cluster.
#
# Pipeline:
#   1. Add Helm repos (idempotent)
#   2. Build and kind-load service images
#   3. helm dependency update; helm upgrade --install otel-poc
#
set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

CLUSTER_NAME="kind"
SERVICES=(
    "python-otel-service"
    "go-otel-service"
    "csharp-otel-service"
    "rust-otel-service"
    "cpp-otel-service"
)
UMBRELLA_CHART="./infra/helm-charts/otel-poc"

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      Deploy otel-poc on Kind                                ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ─── 1. Helm repos ──────────────────────────────────────────────────────────
echo -e "${YELLOW}📚 Adding Helm repositories...${NC}"
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts >/dev/null 2>&1 || true
helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1 || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null
echo -e "${GREEN}✓ Repositories ready${NC}"
echo ""

# ─── 2. Build + kind-load service images ────────────────────────────────────
echo -e "${YELLOW}📦 Building and loading service images...${NC}"
for service in "${SERVICES[@]}"; do
    IMAGE="${service}:latest"
    if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
        echo -e "${BLUE}  Building ${IMAGE}...${NC}"
        docker build -t "${IMAGE}" \
            -f "services/${service}/Dockerfile" \
            "services/${service}" >/dev/null
    fi
    if ! docker exec "${CLUSTER_NAME}-control-plane" crictl images 2>/dev/null |
        grep -q "${service}"; then
        echo -e "${BLUE}  Loading ${IMAGE} into kind...${NC}"
        kind load docker-image "${IMAGE}" --name "${CLUSTER_NAME}" >/dev/null
    fi
done
echo -e "${GREEN}✓ Images ready${NC}"
echo ""

# ─── 3. Helm install the umbrella ──────────────────────────────────────────
echo -e "${YELLOW}⎈ Resolving chart dependencies...${NC}"
helm dependency update ./infra/helm-charts/otel-platform >/dev/null
helm dependency update "${UMBRELLA_CHART}" >/dev/null
echo -e "${GREEN}✓ Dependencies resolved${NC}"

echo -e "${YELLOW}⎈ Installing otel-poc umbrella chart...${NC}"
helm dependency update "${UMBRELLA_CHART}" >/dev/null
helm upgrade --install otel-poc "${UMBRELLA_CHART}" \
    --namespace default \
    --wait --timeout 5m
echo -e "${GREEN}✓ otel-poc deployed${NC}"
echo ""

# ─── Summary ───────────────────────────────────────────────────────────────
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    Deployment Complete                       ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Releases:${NC}"
helm list -n default 2>/dev/null | tail -n +2 || true
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Port-forward:   make k8s-forward"
echo "  2. Generate load:  make k8s-traffic"
echo "  3. Open Grafana:   http://localhost:3000"
echo ""
