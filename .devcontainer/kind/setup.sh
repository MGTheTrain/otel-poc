#!/bin/bash
set -e

# Color definitions
BLUE='\033[0;34m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                 Kind Cluster Setup Script                   ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Architecture detection
if [ $(uname -m) = x86_64 ]; then
    ARCH="amd64"
elif [ $(uname -m) = aarch64 ]; then
    ARCH="arm64"
else
    echo -e "${RED}Unsupported architecture: $(uname -m)${NC}"
    exit 1
fi
echo -e "${BLUE}Detected architecture: $ARCH${NC}"

# Docker daemon check
echo -e "${BLUE}Waiting for Docker daemon to be ready...${NC}"
timeout 30 bash -c 'until docker info > /dev/null 2>&1; do sleep 1; done' || {
    echo -e "${RED}Docker daemon failed to start within 30 seconds${NC}"
    exit 1
}
echo -e "${GREEN}Docker daemon is ready${NC}"

# Install Kind
KIND_RELEASE="v0.29.0"
echo -e "${BLUE}Installing Kind...${NC}"
curl -Lo ./kind https://kind.sigs.k8s.io/dl/$KIND_RELEASE/kind-linux-${ARCH}
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Create cluster
kind delete cluster --name kind || true
echo -e "${BLUE}Creating kind cluster with fixed ports...${NC}"
kind create cluster --name kind --wait=180s

# Store kubeconfig
kind get kubeconfig --name kind --internal=false > ~/.kube/config

# Test cluster
if kubectl get nodes > /dev/null 2>&1; then
    echo -e "${GREEN}Kind cluster ready${NC}"
    kubectl cluster-info
    kubectl get nodes
    kubectl get pods --all-namespaces
else
    echo -e "${RED}Cluster failed to start properly${NC}"
    docker logs kind-control-plane
    exit 1
fi

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    Sample Commands                           ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${CYAN}Helm commands:${NC}"
echo -e "${YELLOW}# Lint specific chart:${NC}"
echo -e "helm lint charts/services/python-otel-service/"
echo ""
echo -e "${YELLOW}# Template chart:${NC}"
echo -e "helm template charts/services/python-otel-service/"
echo ""
echo -e "${YELLOW}# Check dependencies:${NC}"
echo -e "helm dependency update charts/services/python-otel-service/"
echo ""

echo -e "${GREEN}Setup complete. Use the commands above to test your charts.${NC}"