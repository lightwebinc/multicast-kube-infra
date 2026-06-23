#!/usr/bin/env bash
# Apply the platform layer: namespace -> CNI -> Multus -> ESO -> NADs.
# Idempotent.
set -euo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "${HERE}/.." && pwd)"
DIST="${DIST:-k0s}"
CNI="${CNI:-calico}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${ROOT}/.kube/${DIST}.config}"
export KUBECONFIG="${KUBECONFIG_PATH}"

echo "==> namespace"
kubectl apply -f "${ROOT}/platform/namespaces.yaml"

echo "==> CNI: ${CNI}"
case "${CNI}" in
  calico|cilium)
    helmfile -f "${ROOT}/platform/helmfile.yaml" --selector "cni=${CNI}" apply
    ;;
  kube-router)
    echo "    kube-router is enabled in k0s-config.yaml; nothing to install."
    ;;
  *)
    echo "unknown CNI=${CNI}" >&2; exit 1
    ;;
esac

echo "==> Multus"
helmfile -f "${ROOT}/platform/helmfile.yaml" --selector layer=multus apply

echo "==> External Secrets Operator"
helmfile -f "${ROOT}/platform/helmfile.yaml" --selector layer=secrets apply

# Apply the ClusterSecretStore stub (provider unconfigured -> created but inert).
kubectl apply -f "${ROOT}/platform/secrets/cluster-secret-store.example.yaml" || true

echo "==> NetworkAttachmentDefinitions"
# Source fabric values for envsubst.
FABRIC_IFACE="${FABRIC_IFACE:-enp5s0}"
BGP_TRANSIT_IFACE="${BGP_TRANSIT_IFACE:-enp6s0}"
BGP_IBGP_IFACE="${BGP_IBGP_IFACE:-enp7s0}"
export FABRIC_IFACE BGP_TRANSIT_IFACE BGP_IBGP_IFACE

# Default NAD set: only mcast-fabric. Add bgp-transit / bgp-ibgp via NADS env var.
NADS="${NADS:-mcast-fabric}"
for nad in ${NADS//,/ }; do
  src="${ROOT}/platform/nads/${nad}.yaml.gotmpl"
  if [[ ! -f "${src}" ]]; then
    echo "  skip: ${nad} (no template at ${src})"
    continue
  fi
  envsubst < "${src}" | kubectl apply -f -
done

# SR-IOV stack for the data-plane perf pool (doc 04 W2). Opt-in and HARDWARE-GATED:
# it advertises 0 VFs until run on nodes with real SR-IOV PFs matching
# platform/sriov/configmap.yaml — it cannot be validated on virtio/LXD lab NICs.
if [[ "${ENABLE_SRIOV:-false}" == "true" ]]; then
  echo "==> SR-IOV device plugin + sriov-cni (data-plane pool)"
  kubectl apply -k "${ROOT}/platform/sriov"
  echo "==> SR-IOV VF NAD"
  envsubst < "${ROOT}/platform/nads/mcast-vf.yaml.gotmpl" | kubectl apply -f -
fi

echo "==> platform layer ready"
kubectl get pods -A | grep -E 'multus|calico|cilium|external-secrets|sriov' || true
