# k0s distribution

Reference k0s deployment driven by [`k0sctl`](https://github.com/k0sproject/k0sctl).

## Topology

The repo defaults to **1 controller with the worker role enabled** (`role: controller+worker`)
so the smallest viable lab is a single host. The expansion path to **1 controller + 2
workers (one integrated)** is a values diff in `k0sctl.yaml.example`: add two `role: worker`
host entries, no other change.

## Files

| File | In Git | Purpose |
|---|---|---|
| `k0sctl.yaml.example`     | yes | Template host list + role assignment; edit it to add hosts or bump the k0s version. |
| `k0sctl.yaml`             | no  | Rendered by `bootstrap.sh` on every run; edits are overwritten. |
| `k0s-config.yaml.example` | yes | Template `spec.k0s.config` (`ClusterConfig`). |
| `k0s-config.yaml`         | no  | Operator-edited copy. |
| `hosts.example.env`       | yes | Shell environment template (SSH user, key, host map). |
| `hosts.env`               | no  | Operator-edited copy. |
| `bootstrap.sh`            | yes | `k0sctl apply` wrapper. Idempotent. |
| `teardown.sh`             | yes | `k0sctl reset` wrapper. |

## Prerequisites

- `k0sctl` in `$PATH` (https://github.com/k0sproject/k0sctl/releases).
- `kubectl` in `$PATH`.
- SSH access to all target hosts as a user with passwordless sudo.
- Each target host running a recent Linux kernel (Ubuntu 24.04 validated;
  k0s supports Linux only).
- The dedicated multicast NIC is configured and reachable on every node before
  bootstrap (k0s does not provision it).

## Bootstrap

```bash
cp hosts.example.env       hosts.env
cp k0s-config.yaml.example k0s-config.yaml
# edit the copies …
./bootstrap.sh
```

`bootstrap.sh` will:

1. Source `hosts.env`.
2. Render `k0sctl.yaml` from `k0sctl.yaml.example` (host variables substituted,
   `k0s-config.yaml` inlined under `spec.k0s.config`) and run `k0sctl apply`.
3. Fetch the kubeconfig to `${KUBECONFIG_PATH:-../../.kube/k0s.config}`.
4. Apply the multicast sysctls on every node and persist them in
   `/etc/sysctl.d/80-bsv-mcast.conf`.
5. Write the perf-tuning sysctls to `/etc/sysctl.d/81-bsv-perf.conf`, stop and
   mask `irqbalance`, and disable deep CPU idle states until the next boot.
6. Wait for all nodes to reach `Ready`.

## CNI

The `k0s-config.yaml.example` sets `spec.network.provider: custom` so that the
platform layer (`platform/cni/`) can install Calico (default), Cilium, or a
non-built-in CNI. To use the k0s-bundled `kuberouter`, set `provider: kuberouter`
in `k0s-config.yaml` and run `make platform CNI=kube-router`.
