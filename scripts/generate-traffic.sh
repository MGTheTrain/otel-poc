#!/bin/bash
#
# generate-traffic.sh — hit each service N times against a compose or
# k8s deployment, optionally asserting that telemetry lands in the
# backends.
#
#   compose mode  → curl localhost:<host-port> directly
#   k8s mode      → kubectl exec into a curl pod, curl <svc>.<ns>:8080
#
# Usage:
#   scripts/generate-traffic.sh <compose|k8s> [--assert]
#
# Tunables (env): BATCHES, SLEEP_BETWEEN, NAMESPACE (k8s only),
#                 SETTLE_SECONDS (delay before assertions).
#
set -euo pipefail

MODE="${1:-}"
ASSERT=false
[ "${2:-}" = "--assert" ] && ASSERT=true

if [[ ${MODE} != "compose" && ${MODE} != "k8s" ]]; then
    echo "Usage: $0 <compose|k8s> [--assert]" >&2
    exit 1
fi

BATCHES="${BATCHES:-20}"
SLEEP_BETWEEN="${SLEEP_BETWEEN:-1}"
SETTLE_SECONDS="${SETTLE_SECONDS:-30}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

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
    [ ${#AVAILABLE[@]} -eq 0 ] && {
        echo "No services found in ${NAMESPACE}" >&2
        exit 1
    }

    POD="traffic-gen-$$"
    trap 'kubectl delete pod "${POD}" -n "${NAMESPACE}" --ignore-not-found --grace-period=0 --force >/dev/null 2>&1 || true' EXIT

    kubectl run "${POD}" -n "${NAMESPACE}" \
        --image=curlimages/curl:latest --restart=Never \
        --command -- sleep 3600 >/dev/null
    kubectl wait --for=condition=Ready pod/"${POD}" -n "${NAMESPACE}" --timeout=60s >/dev/null

    SERVICES=("${AVAILABLE[@]}")
else
    AVAILABLE=()
    for svc in "${SERVICE_ORDER[@]}"; do
        port=$(host_port "${svc}")
        if curl -s -o /dev/null --max-time 1 "http://localhost:${port}/api/hello" 2>/dev/null; then
            AVAILABLE+=("${svc}")
        fi
    done
    [ ${#AVAILABLE[@]} -eq 0 ] && {
        echo "No services responding on localhost:5001-5005. Did you run 'make compose-start'?" >&2
        exit 1
    }
    SERVICES=("${AVAILABLE[@]}")
fi

echo "Mode:    ${MODE}"
echo "Hitting: ${SERVICES[*]}"
echo "Batches: ${BATCHES}, sleep between: ${SLEEP_BETWEEN}s"
${ASSERT} && echo "Assertions: enabled (settle ${SETTLE_SECONDS}s before checking)"
echo ""

# ─── Request helpers ────────────────────────────────────────────────────────
hit_compose() {
    local port
    port=$(host_port "$1")
    curl -s -o /dev/null -w '%{http_code}' --max-time 5 \
        "http://localhost:${port}/api/hello" 2>/dev/null || echo "ERR"
}

hit_k8s() {
    kubectl exec -n "${NAMESPACE}" "${POD}" -- \
        curl -s -o /dev/null -w '%{http_code}' --max-time 5 \
        "http://$1.${NAMESPACE}.svc.cluster.local:8080/api/hello" 2>/dev/null || echo "ERR"
}

# In k8s mode we have the curl pod; in compose mode we curl directly.
# Both backends are exposed in compose too if port-forwarded with the
# standard ports (16686, 9090, 3100).
backend_curl() {
    if [[ ${MODE} == "k8s" ]]; then
        kubectl exec -n "${NAMESPACE}" "${POD}" -- curl -s --max-time 5 "$@"
    else
        curl -s --max-time 5 "$@"
    fi
}

backend_url() {
    # service:port for k8s (in-cluster DNS) or localhost:port for compose.
    local k8s_target="$1" compose_target="$2"
    if [[ ${MODE} == "k8s" ]]; then
        echo "${k8s_target}"
    else
        echo "${compose_target}"
    fi
}

# ─── Main loop ──────────────────────────────────────────────────────────────
for i in $(seq 1 "${BATCHES}"); do
    echo "Batch ${i}/${BATCHES}"
    for svc in "${SERVICES[@]}"; do
        if [[ ${MODE} == "k8s" ]]; then code=$(hit_k8s "${svc}"); else code=$(hit_compose "${svc}"); fi
        if [[ ${code} == "200" ]]; then echo "  ✓ ${svc} (${code})"; else echo "  ✗ ${svc} (${code})"; fi
    done
    sleep "${SLEEP_BETWEEN}"
done

echo ""
echo "Traffic generation complete"

# ─── Assert telemetry landed in backends ──────────────────────────
if ${ASSERT}; then
    echo ""
    echo -e "${YELLOW}Waiting ${SETTLE_SECONDS}s for OTel batch flush + Prometheus scrape...${NC}"
    sleep "${SETTLE_SECONDS}"
    echo ""

    PASSED=0
    FAILED=0
    pass() {
        echo -e "  ${GREEN}✓${NC} $1"
        PASSED=$((PASSED + 1))
    }
    fail() {
        echo -e "  ${RED}✗${NC} $1"
        FAILED=$((FAILED + 1))
    }

    jaeger_base=$(backend_url "http://jaeger-query:16686" "http://localhost:16686")
    # prom_base=$(backend_url "http://prometheus-server:80" "http://localhost:9090")
    # loki_base=$(backend_url "http://loki-gateway:80" "http://localhost:3100")

    echo -e "${YELLOW}▶ Jaeger (traces)${NC}"
    for svc in "${SERVICES[@]}"; do
        n=$(backend_curl "${jaeger_base}/api/traces?service=${svc}&lookback=10m&limit=20" |
            grep -oE '"traceID"' | wc -l | tr -d ' ')
        if [ "${n}" -gt 0 ]; then pass "${svc}: ${n} traces"; else fail "${svc}: no traces"; fi
    done
    echo ""

    # TODO:
    # - Assert Prometheus metrics and Loki application logs
    # - Migrate to pytest
    # echo -e "${YELLOW}▶ Prometheus (metrics)${NC}"
    # for svc in "${SERVICES[@]}"; do
    #     q="otel_http_server_request_duration_seconds_count%7Bexported_job%3D%22${svc}%22%7D"
    #     resp=$(backend_curl "${prom_base}/api/v1/query?query=${q}" || echo "")
    #     if echo "${resp}" | grep -q '"status":"success"' && echo "${resp}" | grep -q '"value":\['; then
    #         pass "${svc}: counter present"
    #     else
    #         fail "${svc}: no metrics"
    #     fi
    # done
    # echo ""

    # echo -e "${YELLOW}▶ Loki (logs)${NC}"
    # now_ns=$(date +%s)000000000
    # start_ns=$(( $(date +%s) - 600 ))000000000
    # for svc in "${SERVICES[@]}"; do
    #     q="%7Bpod%3D~%22${svc}.%2A%22%7D"
    #     resp=$(backend_curl "${loki_base}/loki/api/v1/query_range?query=${q}&start=${start_ns}&end=${now_ns}&limit=10" || echo "")
    #     if echo "${resp}" | grep -q '"status":"success"' && echo "${resp}" | grep -q '"values":\[\['; then
    #         pass "${svc}: logs present"
    #     else
    #         fail "${svc}: no logs"
    #     fi
    # done
    echo ""

    echo "Assertions: ${PASSED} passed, ${FAILED} failed"
    if [ "${FAILED}" -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
fi
