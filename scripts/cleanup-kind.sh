#!/bin/bash
set -e

# Color definitions
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Kind Cluster Cleanup Script                    ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 1. Uninstall Helm releases
echo -e "${YELLOW}1. Uninstalling Helm releases...${NC}"
RELEASES=(
    "python-otel-service"
    "go-otel-service"
    "csharp-otel-service"
    "rust-otel-service"
    "cpp-otel-service"
    "otel-collector"
    "jaeger"
    "prometheus"
    "loki"
    "grafana"
)

for release in "${RELEASES[@]}"; do
    if helm list -q | grep -q "^${release}$"; then
        echo -e "${BLUE}  Uninstalling ${release}...${NC}"
        helm uninstall "${release}" 2>/dev/null || true
    fi
done
echo -e "${GREEN}✓ Helm releases uninstalled${NC}"
echo ""

# 2. Clean up Jaeger resources specifically
echo -e "${YELLOW}2. Cleaning up Jaeger resources...${NC}"
kubectl delete svc -l app.kubernetes.io/name=jaeger --ignore-not-found=true 2>/dev/null || true
kubectl delete deployment -l app.kubernetes.io/name=jaeger --ignore-not-found=true 2>/dev/null || true
kubectl delete statefulset -l app.kubernetes.io/name=jaeger --ignore-not-found=true 2>/dev/null || true
kubectl delete replicaset -l app.kubernetes.io/name=jaeger --ignore-not-found=true 2>/dev/null || true
kubectl delete pod -l app.kubernetes.io/name=jaeger --force --grace-period=0 --ignore-not-found=true 2>/dev/null || true
kubectl delete configmap -l app.kubernetes.io/name=jaeger --ignore-not-found=true 2>/dev/null || true
kubectl delete serviceaccount -l app.kubernetes.io/name=jaeger --ignore-not-found=true 2>/dev/null || true
kubectl delete secret -l app.kubernetes.io/name=jaeger --ignore-not-found=true 2>/dev/null || true
echo -e "${GREEN}✓ Jaeger resources cleaned${NC}"
echo ""

# 2a. Clean up Loki StatefulSet and PVCs
echo -e "${YELLOW}2a. Cleaning up Loki StatefulSet...${NC}"
kubectl delete statefulset -l app.kubernetes.io/name=loki --ignore-not-found=true 2>/dev/null || true
kubectl delete pvc -l app.kubernetes.io/name=loki --ignore-not-found=true 2>/dev/null || true
echo -e "${GREEN}✓ Loki StatefulSet cleaned${NC}"
echo ""

# 2b. Clean up Prometheus StatefulSet (if exists)
echo -e "${YELLOW}2b. Cleaning up Prometheus StatefulSet...${NC}"
kubectl delete statefulset -l app.kubernetes.io/name=prometheus --ignore-not-found=true 2>/dev/null || true
echo -e "${GREEN}✓ Prometheus StatefulSet cleaned${NC}"
echo ""

# 3. Delete all completed test pods
echo -e "${YELLOW}3. Cleaning up completed test pods...${NC}"
COMPLETED_PODS=$(kubectl get pods --field-selector=status.phase==Succeeded -o name 2>/dev/null || echo "")
if [ -n "$COMPLETED_PODS" ]; then
    COMPLETED_COUNT=$(echo "$COMPLETED_PODS" | wc -l)
    echo -e "${BLUE}  Deleting ${COMPLETED_COUNT} completed pods...${NC}"
    kubectl delete pod --field-selector=status.phase==Succeeded --ignore-not-found=true 2>/dev/null || true
    echo -e "${GREEN}✓ Completed pods deleted${NC}"
else
    echo -e "${GREEN}✓ No completed pods to clean${NC}"
fi
echo ""

# 4. Delete failed pods
echo -e "${YELLOW}4. Cleaning up failed pods...${NC}"
FAILED_PODS=$(kubectl get pods --field-selector=status.phase==Failed -o name 2>/dev/null || echo "")
if [ -n "$FAILED_PODS" ]; then
    FAILED_COUNT=$(echo "$FAILED_PODS" | wc -l)
    echo -e "${BLUE}  Deleting ${FAILED_COUNT} failed pods...${NC}"
    kubectl delete pod --field-selector=status.phase==Failed --ignore-not-found=true 2>/dev/null || true
    echo -e "${GREEN}✓ Failed pods deleted${NC}"
else
    echo -e "${GREEN}✓ No failed pods to clean${NC}"
fi
echo ""

# 5. Clean up orphaned PVCs (if any)
echo -e "${YELLOW}5. Checking for orphaned PVCs...${NC}"
PVCS=$(kubectl get pvc -o name 2>/dev/null | grep -v "loki" || echo "")
if [ -n "$PVCS" ]; then
    echo -e "${BLUE}  Found orphaned PVCs:${NC}"
    kubectl get pvc 2>/dev/null | grep -v "loki" || true
    echo -e "${YELLOW}  Skipping deletion (manual review recommended)${NC}"
else
    echo -e "${GREEN}✓ No orphaned PVCs${NC}"
fi
echo ""

# 6. Summary
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                      Cleanup Summary                         ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}Current cluster state:${NC}"
echo -e "${YELLOW}Pods:${NC}"
kubectl get pods -o wide 2>/dev/null || echo "None"
echo ""
echo -e "${YELLOW}Services:${NC}"
kubectl get svc 2>/dev/null || echo "None"
echo ""
echo -e "${YELLOW}Helm releases:${NC}"
helm list 2>/dev/null || echo "None"
echo ""

echo -e "${GREEN}✓ Cleanup complete${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  Deploy fresh: make k8s-deploy"
echo ""