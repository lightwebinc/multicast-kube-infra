# SR-IOV stack — data-plane perf pool (W2)

Exposes NIC **Virtual Functions** as allocatable, NUMA-topology-hinted Kubernetes
resources so an AF_XDP `shard-proxy`/`shard-listener` pod gets **zero-copy** ingress —
which the macvlan secondary (`mcast-fabric`) cannot give. Part of
[1bsv-ops production doc 04 (W2)](https://github.com/lightwebinc/1bsv-ops/blob/main/docs/production/04-edge-ingress-orchestration.md).

## Components

| File | What |
| ---- | ---- |
| `vendor/sriovdp-daemonset.yaml` | upstream SR-IOV **Network Device Plugin** `v3.11.0` (image **pinned** off upstream `:latest`) |
| `vendor/sriov-cni-daemonset.yaml` | upstream **sriov-cni** `v2.10.0` (image pinned) |
| `vendor/configMap.example.yaml` | upstream pool examples (reference only) |
| `configmap.yaml` | **our** pool — advertises `1bsv.net/mcast_vf` (Mellanox mlx5 example; tune to the real PF) |
| `patch-dp-dataplane.yaml` / `patch-cni-dataplane.yaml` | overlay: pin scheduling to `node-role/dataplane` + tolerate `dataplane:NoSchedule`; set `--resource-prefix=1bsv.net` |
| `kustomization.yaml` | composes vendor + overlays |

The matching `mcast-vf` NAD lives in [`../nads/mcast-vf.yaml.gotmpl`](../nads/mcast-vf.yaml.gotmpl)
(`type: sriov`, bound to `1bsv.net/mcast_vf`).

## Apply

```sh
ENABLE_SRIOV=true scripts/platform-apply.sh      # opt-in; or:
kubectl apply -k platform/sriov
```

## ⚠ Hardware-gated — NOT lab-provable

The device plugin advertises **`1bsv.net/mcast_vf: 0`** until it runs on a node with
**real SR-IOV PFs** whose vendor/driver/`pfNames` match `configmap.yaml`. On
virtio/LXD lab NICs there are no VFs, so VF allocation and zero-copy **cannot** be
validated here — they are validated on a real perf node (`xhost-perf-rig`), not in the
functional lab. What *is* validated in the lab (no special hardware): the kustomize
build, the DaemonSets scheduling onto the tainted pool, and the Guaranteed-QoS exclusive
-core + hugepages + memlock scheduling (doc 04 W2 proof).

## Tuning to the real NIC

Edit `configmap.yaml` `selectors` — `vendors` (e.g. `15b3` Mellanox, `8086` Intel),
`drivers` (`mlx5_core`, `iavf`, `vfio-pci` for DPDK), and `pfNames` (the PF, e.g.
`ens4f0np0#0-7` to scope a VF range). VFs must be pre-created on the host
(`echo N > /sys/class/net/<pf>/device/sriov_numvfs`, persisted by the perf-tuning role).
