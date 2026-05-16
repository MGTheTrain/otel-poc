#!/bin/bash
#
# port-forward-in-kind.sh — port-forward observability + service endpoints.
#
set -euo pipefail

NAMESPACE="${NAMESPACE:-default}"

# Parse flags
FORWARD_OBS=false
FORWARD_SVC=false
while [[ $# -gt 0 ]]; do
    case "$1" in
    --obs | --observability)
        FORWARD_OBS=true
        shift
        ;;
    --svc | --services)
        FORWARD_SVC=true
        shift
        ;;
    --all)
        FORWARD_OBS=true
        FORWARD_SVC=true
        shift
        ;;
    *)
        echo "Usage: $0 [--obs|--observability] [--svc|--services] [--all]" >&2
        exit 1
        ;;
    esac
done
if ! ${FORWARD_OBS} && ! ${FORWARD_SVC}; then
    FORWARD_OBS=true
    FORWARD_SVC=true
fi

cleanup() {
    echo ""
    echo "Stopping port-forwards..."
    jobs -p | xargs -r kill 2>/dev/null || true
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# Forward a Service by name.
forward() {
    local svc="$1" local_port="$2" remote_port="$3"
    if kubectl get svc "${svc}" -n "${NAMESPACE}" >/dev/null 2>&1; then
        kubectl port-forward -n "${NAMESPACE}" "svc/${svc}" "${local_port}:${remote_port}" &
        echo "  ${svc} → http://localhost:${local_port}"
    else
        echo "  ${svc} (skip — not deployed)"
    fi
}

# Forward a Deployment by name (used for headless services where the
# service-port resolution path doesn't work cleanly).
forward_deploy() {
    local deploy="$1" local_port="$2" container_port="$3"
    if kubectl get deploy "${deploy}" -n "${NAMESPACE}" >/dev/null 2>&1; then
        kubectl port-forward -n "${NAMESPACE}" "deploy/${deploy}" "${local_port}:${container_port}" &
        echo "  ${deploy} (deploy) → http://localhost:${local_port}"
    else
        echo "  ${deploy} (skip — not deployed)"
    fi
}

echo "Starting port-forwards for kind..."
echo ""

if ${FORWARD_OBS}; then
    echo "Observability:"
    forward grafana 3000 80
    forward_deploy jaeger 16686 16686
    forward prometheus-server 9090 80
    echo ""
fi

if ${FORWARD_SVC}; then
    echo "Services:"
    forward csharp-otel-service 5001 8080
    forward go-otel-service 5002 8080
    forward python-otel-service 5003 8080
    forward rust-otel-service 5004 8080
    forward cpp-otel-service 5005 8080
    echo ""
fi

echo "Press Ctrl+C to stop."
wait
