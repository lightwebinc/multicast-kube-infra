#!/usr/bin/env bash
# Apply bsv-mcast/* node labels driven by hosts.env.
# Idempotent: kubectl label --overwrite.
set -euo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "${HERE}/.." && pwd)"
DIST="${DIST:-k0s}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${ROOT}/.kube/${DIST}.config}"
export KUBECONFIG="${KUBECONFIG_PATH}"

if [[ "${DIST}" != "k0s" ]]; then
  echo "label-nodes only implemented for DIST=k0s; skipping."
  exit 0
fi

hosts_env="${ROOT}/distributions/k0s/hosts.env"
[[ -f "${hosts_env}" ]] || { echo "missing ${hosts_env}"; exit 1; }
# shellcheck disable=SC1090
source "${hosts_env}"

# Resolve the k8s node name for a given SSH host. k0sctl uses the SSH address
# by default but the node name in kubectl is the OS hostname. Look it up.
node_name_for() {
  local ssh_addr="$1"
  ssh -i "${SSH_KEY}" -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
    "${SSH_USER}@${ssh_addr}" 'hostname' 2>/dev/null
}

label_node() {
  local node="$1" iface="$2" role_csv="$3" node_id="$4"
  echo "  ${node}: role=${role_csv} iface=${iface} node=${node_id}"
  kubectl label node "${node}" --overwrite "bsv-mcast/fabric-iface=${iface}" >/dev/null
  kubectl label node "${node}" --overwrite "bsv-mcast/node=${node_id}"      >/dev/null
  IFS=',' read -ra roles <<<"${role_csv}"
  for r in "${roles[@]}"; do
    kubectl label node "${node}" --overwrite "bsv-mcast/role-${r}=true" >/dev/null
  done
  # Also set the "primary" role label for nodeSelector (chart uses singular key).
  kubectl label node "${node}" --overwrite "bsv-mcast/role=${roles[0]}" >/dev/null
}

echo "==> labeling nodes"
n0=$(node_name_for "${NODE0_ADDR}")
# Single-node default: this node hosts proxy + listener + retry-1.
label_node "${n0}" "${NODE0_FABRIC_IFACE}" "proxy,listener,retry-endpoint" "retry-1"

if [[ -n "${NODE1_ADDR:-}" ]]; then
  n1=$(node_name_for "${NODE1_ADDR}")
  label_node "${n1}" "${NODE1_FABRIC_IFACE}" "listener,retry-endpoint" "retry-2"
fi

if [[ -n "${NODE2_ADDR:-}" ]]; then
  n2=$(node_name_for "${NODE2_ADDR}")
  label_node "${n2}" "${NODE2_FABRIC_IFACE}" "listener,retry-endpoint" "retry-3"
fi

kubectl get nodes --show-labels | grep -o 'bsv-mcast/[^,]*' | sort -u || true
