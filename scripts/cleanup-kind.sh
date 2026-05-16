#!/bin/bash
#
# cleanup-kind.sh — tear down otel-poc and clean up leftovers.
#
set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Kind Cluster Cleanup                            ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 1. Uninstall the umbrella — cascades to all subcharts.
echo -e "${YELLOW}⎈ Uninstalling otel-poc...${NC}"
helm uninstall otel-poc --ignore-not-found 2>/dev/null || true
echo -e "${GREEN}✓ Uninstalled${NC}"
echo ""

# 2. PVCs from StatefulSets (Loki / Prometheus) — Helm leaves these.
echo -e "${YELLOW}🗑  Removing PVCs left by StatefulSets...${NC}"
kubectl delete pvc -l app.kubernetes.io/instance=otel-poc --ignore-not-found=true 2>/dev/null || true
echo -e "${GREEN}✓ PVCs cleared${NC}"
echo ""

# 3. Stray completed/failed pods.
echo -e "${YELLOW}🧹 Sweeping completed and failed pods...${NC}"
kubectl delete pod --field-selector=status.phase==Succeeded --ignore-not-found=true 2>/dev/null || true
kubectl delete pod --field-selector=status.phase==Failed --ignore-not-found=true 2>/dev/null || true
echo -e "${GREEN}✓ Swept${NC}"
echo ""

echo -e "${GREEN}✓ Cleanup complete — 'make k8s-deploy' to redeploy.${NC}"
