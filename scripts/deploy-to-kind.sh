#!/bin/bash
set -e

# Color definitions
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

CLUSTER_NAME="kind"
SERVICES=("python-otel-service" "go-otel-service" "csharp-otel-service" "rust-otel-service" "cpp-otel-service")

# Chart versions (locked to tested versions)
JAEGER_CHART_VERSION="3.3.3"           # Jaeger 1.53.0
LOKI_CHART_VERSION="6.46.0"            # Loki 3.5.7
PROMETHEUS_CHART_VERSION="27.50.0"     # Prometheus v3.8.0
OTEL_CHART_VERSION="0.140.1"           # OTel Collector 0.140.1
GRAFANA_CHART_VERSION="10.3.0"         # Grafana 12.3.0

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          Build and Deploy Services to Kind Cluster          ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Add Helm repositories (conditional)
echo -e "${YELLOW}📚 Step 1/5: Checking Helm repositories...${NC}"
REPOS_NEEDED=false

if ! helm repo list | grep -q "^open-telemetry"; then
    echo -e "${BLUE}Adding open-telemetry repository...${NC}"
    helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
    REPOS_NEEDED=true
fi

if ! helm repo list | grep -q "^prometheus-community"; then
    echo -e "${BLUE}Adding prometheus-community repository...${NC}"
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    REPOS_NEEDED=true
fi

if ! helm repo list | grep -q "^grafana"; then
    echo -e "${BLUE}Adding grafana repository...${NC}"
    helm repo add grafana https://grafana.github.io/helm-charts
    REPOS_NEEDED=true
fi

if ! helm repo list | grep -q "^jaegertracing"; then
    echo -e "${BLUE}Adding jaegertracing repository...${NC}"
    helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
    REPOS_NEEDED=true
fi

if [ "$REPOS_NEEDED" = true ]; then
    echo -e "${BLUE}Updating Helm repositories...${NC}"
    helm repo update
    echo -e "${GREEN}✓ Helm repositories added and updated${NC}"
else
    echo -e "${GREEN}✓ All Helm repositories already configured${NC}"
fi
echo ""

# Step 2: Deploy observability stack
echo -e "${YELLOW}🔭 Step 2/5: Deploying observability stack...${NC}"

# Jaeger (deploy first as OTel Collector depends on it)
echo -e "${BLUE}Installing Jaeger ${JAEGER_CHART_VERSION}...${NC}"
helm upgrade --install jaeger jaegertracing/jaeger \
  --version ${JAEGER_CHART_VERSION} \
  --set provisionDataStore.cassandra=false \
  --set storage.type=memory \
  --set allInOne.enabled=true \
  --set agent.enabled=false \
  --set collector.enabled=false \
  --set query.enabled=false \
  --wait --timeout 3m
    
# Loki
echo -e "${BLUE}Installing Loki ${LOKI_CHART_VERSION}...${NC}"
cat > /tmp/loki-values.yaml <<EOF
deploymentMode: SingleBinary

loki:
  auth_enabled: false
  useTestSchema: true
  commonConfig:
    replication_factor: 1
  storage:
    type: filesystem

singleBinary:
  replicas: 1

# Explicitly disable all distributed components
write:
  replicas: 0
read:
  replicas: 0
backend:
  replicas: 0
ingester:
  replicas: 0
distributor:
  replicas: 0
querier:
  replicas: 0
queryFrontend:
  replicas: 0
compactor:
  replicas: 0
indexGateway:
  replicas: 0

# Disable caches
chunksCache:
  enabled: false
resultsCache:
  enabled: false

minio:
  enabled: false

gateway:
  enabled: true
  service:
    type: ClusterIP
EOF

helm upgrade --install loki grafana/loki \
    --version ${LOKI_CHART_VERSION} \
    -f /tmp/loki-values.yaml \
    --wait --timeout 3m

# Prometheus
echo -e "${BLUE}Installing Prometheus ${PROMETHEUS_CHART_VERSION}...${NC}"
cat > /tmp/prometheus-values.yaml <<EOF
alertmanager:
  enabled: false
kube-state-metrics:
  enabled: true
prometheus-node-exporter:
  enabled: true
pushgateway:
  enabled: false
server:
  service:
    type: ClusterIP

serverFiles:
  prometheus.yml:
    scrape_configs:
      - job_name: 'otel-collector'
        scrape_interval: 15s
        static_configs:
          - targets: ['otel-collector-opentelemetry-collector.default.svc.cluster.local:8889']
EOF

helm upgrade --install prometheus prometheus-community/prometheus \
    --version ${PROMETHEUS_CHART_VERSION} \
    -f /tmp/prometheus-values.yaml \
    --wait --timeout 3m

# OpenTelemetry Collector
echo -e "${BLUE}Installing OpenTelemetry Collector ${OTEL_CHART_VERSION}...${NC}"

cat > /tmp/otel-values.yaml <<EOF
mode: deployment

image:
  repository: otel/opentelemetry-collector-contrib
  tag: ""  # Uses chart's default version

config:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318
  processors:
    batch:
      timeout: 1s
      send_batch_size: 1024
  exporters:
    otlp/jaeger:
      endpoint: jaeger-collector.default.svc.cluster.local:4317
      tls:
        insecure: true
    prometheus:
      endpoint: "0.0.0.0:8889"
      namespace: otel
    otlphttp/loki:
      endpoint: http://loki-gateway:80/otlp
      tls:
        insecure: true
    debug:
      verbosity: detailed
  service:
    pipelines:
      traces:
        receivers: [otlp]
        processors: [batch]
        exporters: [otlp/jaeger, debug]
      metrics:
        receivers: [otlp]
        processors: [batch]
        exporters: [prometheus, debug]
      logs:
        receivers: [otlp]
        processors: [batch]
        exporters: [otlphttp/loki, debug]
ports:
  otlp:
    enabled: true
  otlp-http:
    enabled: true
  metrics:
    enabled: true
    containerPort: 8889
    servicePort: 8889
    protocol: TCP
EOF

helm upgrade --install otel-collector open-telemetry/opentelemetry-collector \
    --version ${OTEL_CHART_VERSION} \
    -f /tmp/otel-values.yaml \
    --wait --timeout 3m

# Grafana
echo -e "${BLUE}Installing Grafana ${GRAFANA_CHART_VERSION}...${NC}"
cat > /tmp/grafana-values.yaml <<EOF
service:
  type: ClusterIP
adminPassword: admin
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        url: http://prometheus-server:80
        isDefault: true
      - name: Jaeger
        type: jaeger
        url: http://jaeger-query:16686
      - name: Loki
        type: loki
        url: http://loki-gateway:80
env:
  GF_AUTH_ANONYMOUS_ENABLED: "true"
  GF_AUTH_ANONYMOUS_ORG_ROLE: "Admin"
EOF

helm upgrade --install grafana grafana/grafana \
    --version ${GRAFANA_CHART_VERSION} \
    -f /tmp/grafana-values.yaml \
    --wait --timeout 3m

echo -e "${GREEN}✓ Observability stack deployed${NC}"
echo ""

# Step 3: Build all images
echo -e "${YELLOW}📦 Step 3/5: Building Docker images...${NC}"
IMAGES_TO_BUILD=()

for service in "${SERVICES[@]}"; do
    if ! docker image inspect otel-poc-${service}:latest >/dev/null 2>&1; then
        echo -e "${BLUE}Image otel-poc-${service}:latest not found, will build${NC}"
        IMAGES_TO_BUILD+=("$service")
    else
        echo -e "${GREEN}Image otel-poc-${service}:latest already exists, skipping${NC}"
    fi
done

if [ ${#IMAGES_TO_BUILD[@]} -gt 0 ]; then
    # Split into two groups (cpp builds separately)
    CPP_SERVICE="cpp-otel-service"
    OTHER_SERVICES=()
    
    for svc in "${IMAGES_TO_BUILD[@]}"; do
        if [ "$svc" = "$CPP_SERVICE" ]; then
            :  # Skip, will build separately
        else
            OTHER_SERVICES+=("$svc")
        fi
    done
    
    if [ ${#OTHER_SERVICES[@]} -gt 0 ]; then
        echo -e "${BLUE}Building: ${OTHER_SERVICES[@]}${NC}"
        make build SERVICES="${OTHER_SERVICES[*]}"
    fi
    
    if [[ " ${IMAGES_TO_BUILD[@]} " =~ " ${CPP_SERVICE} " ]]; then
        echo -e "${BLUE}Building: cpp service${NC}"
        make build SERVICES="cpp-otel-service"
    fi
    
    echo -e "${GREEN}✓ Images built successfully${NC}"
else
    echo -e "${GREEN}✓ All images already exist, skipping build${NC}"
fi
echo ""

# Step 4: Load images into Kind cluster (only if not already loaded)
echo -e "${YELLOW}🚀 Step 4/5: Loading images into Kind cluster...${NC}"
for service in "${SERVICES[@]}"; do
    IMAGE_NAME="otel-poc-${service}:latest"
    # Check if image exists in Kind cluster
    if docker exec ${CLUSTER_NAME}-control-plane crictl images | grep -q "otel-poc-${service}"; then
        echo -e "${GREEN}Image ${IMAGE_NAME} already in cluster, skipping${NC}"
    else
        echo -e "${BLUE}Loading ${IMAGE_NAME} into cluster...${NC}"
        kind load docker-image ${IMAGE_NAME} --name ${CLUSTER_NAME}
    fi
done
echo -e "${GREEN}✓ All images loaded into Kind cluster${NC}"
echo ""

# Step 5: Install service Helm charts
echo -e "${YELLOW}⎈ Step 5/5: Installing service Helm charts...${NC}"
for service in "${SERVICES[@]}"; do
    echo -e "${BLUE}Installing ${service}...${NC}"
    
    if [ "$service" = "rust-otel-service" ]; then
        OTEL_ENDPOINT="http://otel-collector-opentelemetry-collector:4317"
    else
        OTEL_ENDPOINT="otel-collector-opentelemetry-collector:4317"
    fi
    
    helm upgrade --install ${service} ./charts/services/${service} \
        --set image.repository=otel-poc-${service} \
        --set image.tag=latest \
        --set image.pullPolicy=Never \
        --set service.type=ClusterIP \
        --set service.port=8080 \
        --set service.targetPort=8080 \
        --set livenessProbe.httpGet.port=8080 \
        --set readinessProbe.httpGet.port=8080 \
        --set-string "env[0].name=OTEL_EXPORTER_OTLP_ENDPOINT" \
        --set-string "env[0].value=${OTEL_ENDPOINT}" \
        --set-string "env[1].name=OTEL_SERVICE_NAME" \
        --set-string "env[1].value=${service}" \
        --wait --timeout 2m
done
echo -e "${GREEN}✓ All service Helm charts installed${NC}"
echo ""

# Summary
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                     Deployment Summary                      ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Chart Versions Deployed:${NC}"
echo "  Jaeger:          ${JAEGER_CHART_VERSION} (app: 1.53.0)"
echo "  Loki:            ${LOKI_CHART_VERSION} (app: 3.5.7)"
echo "  Prometheus:      ${PROMETHEUS_CHART_VERSION} (app: v3.8.0)"
echo "  OTel Collector:  ${OTEL_CHART_VERSION} (app: 0.140.1)"
echo "  Grafana:         ${GRAFANA_CHART_VERSION} (app: 12.3.0)"
echo ""
echo -e "${GREEN}Observability Stack:${NC}"
kubectl get pods -l 'app.kubernetes.io/name in (opentelemetry-collector,jaeger,prometheus,loki,grafana)'
echo ""
echo -e "${GREEN}Microservices:${NC}"
kubectl get pods -l 'app.kubernetes.io/instance in (python-otel-service,go-otel-service,csharp-otel-service,rust-otel-service,cpp-otel-service)'
echo ""
echo -e "${GREEN}Services:${NC}"
kubectl get svc | grep -E "(otel-collector|jaeger|prometheus|loki|grafana|otel-service)"
echo ""
echo -e "${YELLOW}Access UIs via port-forward:${NC}"
echo "Grafana:    kubectl port-forward svc/grafana 3000:80"
echo "Jaeger:     kubectl port-forward svc/jaeger-query 16686:16686"
echo "Prometheus: kubectl port-forward svc/prometheus-server 9090:80"
echo ""
echo -e "${YELLOW}🔍 Troubleshooting Commands:${NC}"
echo "Check Jaeger logs:     kubectl logs -l app.kubernetes.io/name=jaeger --tail=50"
echo "Check OTel exports:    kubectl logs -l app.kubernetes.io/name=opentelemetry-collector --tail=100"
echo "Verify trace flow:     curl -s http://localhost:16686/api/services"
echo ""
echo -e "${GREEN}✓ Deployment complete with locked chart versions${NC}"