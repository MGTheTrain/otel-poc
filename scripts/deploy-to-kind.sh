#!/bin/bash
#
# deploy-to-kind.sh — install otel-poc into a kind cluster.
#
# Pipeline:
#   1. Add Helm repos (idempotent)
#   2. Resolve chart dependencies (platform first, then umbrella)
#   3. helm upgrade --install otel-poc
#
set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

# ─── 2. Resolve chart dependencies ──────────────────────────────────────────
# Bottom-up: platform first (pulls upstream observability charts), then
# umbrella (pulls the now-complete platform tgz + service charts). The
# platform step is the one that breaks subtly if skipped — the umbrella
# packages otel-platform without its own deps and silently installs
# an empty subchart.
echo -e "${YELLOW}⎈ Resolving chart dependencies...${NC}"
helm dependency update ./infra/helm-charts/otel-platform >/dev/null
helm dependency update "${UMBRELLA_CHART}" >/dev/null
echo -e "${GREEN}✓ Dependencies resolved${NC}"
echo ""

# ─── 3. Helm install the umbrella ──────────────────────────────────────────
echo -e "${YELLOW}⎈ Installing otel-poc umbrella chart...${NC}"
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
helm list -n default || true
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Port-forward:   make forward"
echo "  2.1. Generate load:  make traffic"
echo "  2.2. Generate load and assert telemetry lands: make test"
echo "  3. Open Grafana:   http://localhost:3000"
echo ""
