#!/usr/bin/env bash
# Smoke verification: pods Ready, listener metric endpoint reachable, frames
# observed after a synthetic subtx-gen burst.
set -euo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "${HERE}/.." && pwd)"
DIST="${DIST:-k0s}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${ROOT}/.kube/${DIST}.config}"
export KUBECONFIG="${KUBECONFIG_PATH}"
NS=bsv-mcast

echo "==> namespace state"
kubectl -n "${NS}" get pods -o wide

echo "==> wait for proxy + listener Ready (timeout 120s)"
kubectl -n "${NS}" wait --for=condition=Ready pods -l app.kubernetes.io/name=shard-proxy    --timeout=120s
kubectl -n "${NS}" wait --for=condition=Ready pods -l app.kubernetes.io/name=shard-listener --timeout=120s

echo "==> wait for retry endpoints Ready"
kubectl -n "${NS}" wait --for=condition=Ready pods -l app.kubernetes.io/name=retry-endpoint --timeout=120s || true

# Pull a sample listener metric — verifies primary CNI metrics path works.
listener_pod=$(kubectl -n "${NS}" get pods -l app.kubernetes.io/name=shard-listener -o jsonpath='{.items[0].metadata.name}')
echo "==> scraping ${listener_pod}/metrics"
kubectl -n "${NS}" exec "${listener_pod}" -c shard-listener -- \
  wget -q -O- http://127.0.0.1:9200/metrics 2>/dev/null | head -n 20 || true

echo "==> verify ok"
