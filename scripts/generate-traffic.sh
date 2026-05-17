#!/bin/bash
#
# generate-traffic.sh — hit each service N times against a compose or
# k8s deployment.
#
#   compose mode  → curl localhost:<host-port> directly
#   k8s mode      → kubectl exec into a curl pod, curl <svc>.<ns>:8080
#
# Usage:
#   scripts/generate-traffic.sh compose
#   scripts/generate-traffic.sh k8s
#
# Tunables (env): BATCHES, SLEEP_BETWEEN, NAMESPACE (k8s only).
#
set -euo pipefail

MODE="${1:-}"
if [[ ${MODE} != "compose" && ${MODE} != "k8s" ]]; then
    echo "Usage: $0 <compose|k8s>" >&2
    exit 1
fi

BATCHES="${BATCHES:-20}"
SLEEP_BETWEEN="${SLEEP_BETWEEN:-1}"

# Service catalog. Bash 3-compatible (macOS ships 3.2).
SERVICE_ORDER=(python-service go-service csharp-service rust-service cpp-service)

host_port() {
    case "$1" in
    csharp-service) echo 5001 ;;
    go-service) echo 5002 ;;
    python-service) echo 5003 ;;
    rust-service) echo 5004 ;;
    cpp-service) echo 5005 ;;
    *)
        echo "unknown service: $1" >&2
        return 1
        ;;
    esac
}

# ─── Mode-specific setup ────────────────────────────────────────────────────
if [[ ${MODE} == "k8s" ]]; then
    NAMESPACE="${NAMESPACE:-default}"

    AVAILABLE=()
    for svc in "${SERVICE_ORDER[@]}"; do
        if kubectl get svc "${svc}" -n "${NAMESPACE}" >/dev/null 2>&1; then
            AVAILABLE+=("${svc}")
        fi
    done

    if [ ${#AVAILABLE[@]} -eq 0 ]; then
        echo "No otel-poc services found in namespace ${NAMESPACE}" >&2
        exit 1
    fi

    POD="traffic-gen-$$"
    trap 'kubectl delete pod "${POD}" -n "${NAMESPACE}" --ignore-not-found --grace-period=0 --force >/dev/null 2>&1 || true' EXIT

    kubectl run "${POD}" -n "${NAMESPACE}" \
        --image=curlimages/curl:latest \
        --restart=Never \
        --command -- sleep 3600 >/dev/null

    kubectl wait --for=condition=Ready pod/"${POD}" \
        -n "${NAMESPACE}" --timeout=60s >/dev/null

    SERVICES=("${AVAILABLE[@]}")
else
    # Compose mode: discover which services are actually responding.
    AVAILABLE=()
    for svc in "${SERVICE_ORDER[@]}"; do
        port=$(host_port "${svc}")
        if curl -s -o /dev/null --max-time 1 "http://localhost:${port}/api/hello" 2>/dev/null; then
            AVAILABLE+=("${svc}")
        fi
    done

    if [ ${#AVAILABLE[@]} -eq 0 ]; then
        echo "No services responding on localhost:5001-5005" >&2
        echo "Did you run 'make compose-start' first?" >&2
        exit 1
    fi

    SERVICES=("${AVAILABLE[@]}")
fi

echo "Mode:    ${MODE}"
echo "Hitting: ${SERVICES[*]}"
echo "Batches: ${BATCHES}, sleep between: ${SLEEP_BETWEEN}s"
echo ""

# ─── Per-mode request helpers ───────────────────────────────────────────────
hit_compose() {
    local svc="$1" port
    port=$(host_port "${svc}")
    curl -s -o /dev/null -w '%{http_code}' --max-time 5 \
        "http://localhost:${port}/api/hello" 2>/dev/null || echo "ERR"
}

hit_k8s() {
    local svc="$1"
    kubectl exec -n "${NAMESPACE}" "${POD}" -- \
        curl -s -o /dev/null -w '%{http_code}' --max-time 5 \
        "http://${svc}.${NAMESPACE}.svc.cluster.local:8080/api/hello" 2>/dev/null ||
        echo "ERR"
}

# ─── Main loop ──────────────────────────────────────────────────────────────
for i in $(seq 1 "${BATCHES}"); do
    echo "Batch ${i}/${BATCHES}"
    for svc in "${SERVICES[@]}"; do
        if [[ ${MODE} == "k8s" ]]; then
            code=$(hit_k8s "${svc}")
        else
            code=$(hit_compose "${svc}")
        fi
        if [[ ${code} == "200" ]]; then
            echo "  ✓ ${svc} (${code})"
        else
            echo "  ✗ ${svc} (${code})"
        fi
    done
    sleep "${SLEEP_BETWEEN}"
done

echo ""
echo "Traffic generation complete"
echo "  Traces: http://localhost:16686 (Jaeger)"
echo "  Logs:   http://localhost:3000  (Grafana)"
