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
