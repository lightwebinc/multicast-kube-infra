#!/usr/bin/env bash
# Idempotent k0s cluster bootstrap.
#
#   - Sources hosts.env (operator-supplied; .gitignored).
#   - Renders k0sctl.yaml from k0sctl.yaml.example + k0s-config.yaml.
#   - Runs `k0sctl apply`.
#   - Fetches the kubeconfig to $KUBECONFIG_PATH (default ../../.kube/k0s.config).
#   - Applies multicast sysctls on each node via SSH.
#   - Waits for all nodes Ready.

set -euo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "${HERE}/../.." && pwd)"
cd "${HERE}"

KUBECONFIG_PATH="${KUBECONFIG_PATH:-${ROOT}/.kube/k0s.config}"

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "missing required tool: $1" >&2; exit 1; }
}
require k0sctl
require kubectl
require envsubst
require ssh

[[ -f hosts.env ]]              || { echo "missing hosts.env (copy from hosts.example.env)" >&2; exit 1; }
[[ -f k0sctl.yaml.example ]]    || { echo "missing k0sctl.yaml.example" >&2; exit 1; }
[[ -f k0s-config.yaml ]]        || { echo "missing k0s-config.yaml (copy from k0s-config.yaml.example)" >&2; exit 1; }

# shellcheck disable=SC1091
source hosts.env

# Render: inline k0s-config.yaml under spec.k0s.config, then envsubst host vars.
INDENTED_CONFIG=$(sed 's/^/      /' k0s-config.yaml)
TMP_RENDER=$(mktemp)
trap 'rm -f "${TMP_RENDER}"' EXIT

envsubst < k0sctl.yaml.example \
  | awk -v cfg="${INDENTED_CONFIG}" '
      /__INLINE_K0S_CONFIG__/ { print cfg; next }
      { print }
    ' > "${TMP_RENDER}"

# Save the rendered output for debugging (gitignored).
cp "${TMP_RENDER}" k0sctl.yaml

echo "==> k0sctl apply"
k0sctl apply --config k0sctl.yaml --no-wait=false

mkdir -p "$(dirname "${KUBECONFIG_PATH}")"
echo "==> fetch kubeconfig -> ${KUBECONFIG_PATH}"
k0sctl kubeconfig --config k0sctl.yaml > "${KUBECONFIG_PATH}"
chmod 600 "${KUBECONFIG_PATH}"

# Apply multicast sysctls on every host. Idempotent.
#
# MLD_MAX_MSF defaults to 1024 (≥ 2× expected publisher fleet size).
# Operators targeting Posture B/C/D (SSM) at scale should override via
# the MLD_MAX_MSF env var; the Linux default of 64 is below production
# requirements and causes MCAST_JOIN_SOURCE_GROUP to return ENOBUFS.
apply_sysctls() {
  local host="$1" iface="$2"
  local mld_max_msf="${MLD_MAX_MSF:-1024}"
  ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=accept-new "${SSH_USER}@${host}" \
    "sudo sh -c '
      sysctl -w net.ipv6.conf.all.disable_ipv6=0 >/dev/null
      sysctl -w net.ipv6.conf.${iface}.disable_ipv6=0 >/dev/null
      sysctl -w net.ipv6.conf.all.force_mld_version=2 >/dev/null
      sysctl -w net.ipv6.mld_max_msf=${mld_max_msf} >/dev/null
      cat > /etc/sysctl.d/80-bsv-mcast.conf <<EOF
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.${iface}.disable_ipv6 = 0
net.ipv6.conf.all.force_mld_version = 2
net.ipv6.mld_max_msf = ${mld_max_msf}
EOF
    '"
}

echo "==> apply multicast sysctls"
apply_sysctls "${NODE0_ADDR}" "${NODE0_FABRIC_IFACE}"
[[ -n "${NODE1_ADDR:-}" ]] && apply_sysctls "${NODE1_ADDR}" "${NODE1_FABRIC_IFACE}"
[[ -n "${NODE2_ADDR:-}" ]] && apply_sysctls "${NODE2_ADDR}" "${NODE2_FABRIC_IFACE}"

echo "==> wait for nodes Ready"
KUBECONFIG="${KUBECONFIG_PATH}" kubectl wait --for=condition=Ready nodes --all --timeout=300s

echo "==> bootstrap complete"
KUBECONFIG="${KUBECONFIG_PATH}" kubectl get nodes -o wide
