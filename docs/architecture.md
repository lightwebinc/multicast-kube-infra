# Architecture

This repo deploys the four bitcoin multicast components onto a Kubernetes
cluster while staying **distribution-agnostic**. The first concrete distribution
is k0s; AWS EKS and others can be added without touching the platform or app
layers.

## Three layers

```
distributions/<dist>/    bring up a healthy cluster, write KUBECONFIG
        |
        v
platform/                CNI + Multus + ESO + namespace + NADs
        |
        v
apps/                    bitcoin charts via Helmfile
```

Each layer depends only on the previous one's output (a healthy cluster, a
healthy platform). No layer is coupled to a specific distribution.

## Distribution contract

See [`../distributions/common.md`](../distributions/common.md). Summary:

- `bootstrap.sh` is idempotent and writes a kubeconfig to `KUBECONFIG_PATH`.
- `teardown.sh` is idempotent and reverses the bootstrap.
- `*.example.*` templates are committed; operator copies are `.gitignored`.
- The distribution is responsible for kernel sysctls (multicast prerequisites).

## Platform layer

`platform/helmfile.yaml` composes the cluster-level addons:

- **CNI** — Calico (default), Cilium, or k0s-bundled kube-router. Selected by
  the `CNI` environment variable.
- **Multus** — installs the multi-network DaemonSet that lets pods request a
  secondary macvlan interface on the dedicated multicast NIC.
- **External Secrets Operator** — installed but un-configured. The
  `ClusterSecretStore` stub is shipped without a provider; operators choose
  Vault, AWS Secrets Manager, etc.
- **NADs** — `mcast-fabric` is applied by default. `bgp-transit` and
  `bgp-ibgp` are available for BGP scenarios but not applied by default.

## Application layer

`apps/helmfile.yaml` installs the data-plane bitcoin charts (`shard-proxy`,
`shard-listener`, `retry-endpoint`, `subtx-generator`) from OCI. Per-node
retry-endpoint releases are generated from the values list, matching
`composition-spec.md` Option A in the upstream docs.

The `shard-manifest` daemon (BRC-137 announcer) has its own chart at
[`shard-manifest-helm`](https://github.com/lightwebinc/shard-manifest-helm)
and is intentionally **not** wired into the default `apps/helmfile.yaml` —
it runs alongside each data-plane participant rather than as a shared
service. Operators wire it in per their topology, or deploy it to VMs via
[`manifest-infra`](https://github.com/lightwebinc/manifest-infra).

Chart source repositories:

- [`shard-proxy-helm`](https://github.com/lightwebinc/shard-proxy-helm)
- [`shard-listener-helm`](https://github.com/lightwebinc/shard-listener-helm)
- [`retry-endpoint-helm`](https://github.com/lightwebinc/retry-endpoint-helm)
- [`subtx-generator-helm`](https://github.com/lightwebinc/subtx-generator-helm)
- [`shard-manifest-helm`](https://github.com/lightwebinc/shard-manifest-helm)

## Reference topology

The default reference is **1 controller with worker role enabled**. To grow to
**1 controller + 2 workers (one integrated)**, add two `role: worker` entries
to `distributions/k0s/k0sctl.yaml` and re-run `make bootstrap`. The platform
and app layers do not change — Helmfile re-renders against the new node count
and the listener DaemonSet automatically schedules onto the new nodes.

## Cross-references

- [`bsv-multicast/containerization/`](https://github.com/lightwebinc/bsv-multicast/tree/main/containerization) — design rationale.
- [`bsv-multicast/containerization/k0s-deployment.md`](https://github.com/lightwebinc/bsv-multicast/blob/main/containerization/k0s-deployment.md) — the reference architecture this repo implements.
- [`bsv-multicast/containerization/composition-spec.md`](https://github.com/lightwebinc/bsv-multicast/blob/main/containerization/composition-spec.md) — operator wiring patterns.
