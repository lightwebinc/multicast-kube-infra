#!/usr/bin/env bash
# Re-fetch the kubeconfig from the active distribution. Idempotent.
set -euo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "${HERE}/.." && pwd)"

DIST="${DIST:-k0s}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${ROOT}/.kube/${DIST}.config}"
mkdir -p "$(dirname "${KUBECONFIG_PATH}")"

case "${DIST}" in
  k0s)
    cd "${ROOT}/distributions/k0s"
    [[ -f k0sctl.yaml ]] || { echo "no k0sctl.yaml; run bootstrap first" >&2; exit 1; }
    k0sctl kubeconfig --config k0sctl.yaml > "${KUBECONFIG_PATH}"
    ;;
  *)
    echo "unknown DIST=${DIST}" >&2; exit 1
    ;;
esac

chmod 600 "${KUBECONFIG_PATH}"
echo "kubeconfig -> ${KUBECONFIG_PATH}"
