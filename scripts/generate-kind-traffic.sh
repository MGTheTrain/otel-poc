#!/bin/bash
#
# generate-kind-traffic.sh — hit each service N times from inside the cluster.
#
# Spins up a single curl pod and shells out to it, instead of creating one
# pod per request. ~50x faster and you actually see whether requests
# succeed.
#
set -euo pipefail

NAMESPACE="${NAMESPACE:-default}"
BATCHES="${BATCHES:-20}"
SLEEP_BETWEEN="${SLEEP_BETWEEN:-1}"

# Discover services dynamically — skip the ones not deployed.
SERVICES=()
for candidate in \
    python-otel-service \
    go-otel-service \
    csharp-otel-service \
    rust-otel-service \
    cpp-otel-service
do
    if kubectl get svc "${candidate}" -n "${NAMESPACE}" >/dev/null 2>&1; then
        SERVICES+=("${candidate}")
    fi
done

if [ ${#SERVICES[@]} -eq 0 ]; then
    echo "No otel-poc services found in namespace ${NAMESPACE}" >&2
    exit 1
fi

echo "Will hit: ${SERVICES[*]}"
echo "Batches: ${BATCHES}, sleep between: ${SLEEP_BETWEEN}s"
echo ""

# ─── Provision one curl pod for the duration of the run ─────────────────────
POD="traffic-gen-$$"
trap 'kubectl delete pod "${POD}" -n "${NAMESPACE}" --ignore-not-found --grace-period=0 --force >/dev/null 2>&1 || true' EXIT

kubectl run "${POD}" -n "${NAMESPACE}" \
    --image=curlimages/curl:latest \
    --restart=Never \
    --command -- sleep 3600 >/dev/null

# Wait until it's actually Running before exec'ing.
kubectl wait --for=condition=Ready pod/"${POD}" -n "${NAMESPACE}" --timeout=60s >/dev/null

# ─── Hit each service ───────────────────────────────────────────────────────
for i in $(seq 1 "${BATCHES}"); do
    echo "Batch ${i}/${BATCHES}"
    for svc in "${SERVICES[@]}"; do
        url="http://${svc}.${NAMESPACE}.svc.cluster.local:8080/api/hello"
        # -o /dev/null hides the body; -w prints the status code.
        # --max-time 5 stops the request hanging if a service is broken.
        code=$(kubectl exec -n "${NAMESPACE}" "${POD}" -- \
            curl -s -o /dev/null -w '%{http_code}' --max-time 5 "${url}" || echo "ERR")
        if [ "${code}" = "200" ]; then
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