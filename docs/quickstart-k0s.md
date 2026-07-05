# Quickstart — k0s

End-to-end k0s deployment in roughly 10 minutes against a single host (single
controller with the worker role enabled). Multi-host expansion is documented at
the bottom.

## Prerequisites

- One Linux host (Ubuntu 24.04 validated) reachable over SSH with passwordless
  sudo. The host has a dedicated NIC for multicast (e.g. `enp5s0`).
- Local workstation with `k0sctl`, `kubectl`, `helm`, `helmfile`, `envsubst`
  in `$PATH`.

## 1. Configure

```bash
cd multicast-kube-infra

cp distributions/k0s/hosts.example.env       distributions/k0s/hosts.env
cp distributions/k0s/k0sctl.yaml.example     distributions/k0s/k0sctl.yaml
cp distributions/k0s/k0s-config.yaml.example distributions/k0s/k0s-config.yaml

vim distributions/k0s/hosts.env       # SSH user/key + NODE0_*
```

The `*.example.*` files are templates checked into Git. Their non-example
counterparts are operator-specific and `.gitignored`.

## 2. Deploy

```bash
make all
```

This runs preflight → bootstrap → platform → apps → verify. It is
**idempotent**: re-running converges to desired state.

If you only want to run one stage:

```bash
make preflight                # SSH + tools sanity
make bootstrap                # k0sctl apply
make platform CNI=calico      # default
make apps     ENV=reference-k0s
make verify
```

## 3. Use

```bash
export KUBECONFIG="$(pwd)/.kube/k0s.config"
kubectl -n bsv-mcast get pods
```

Metrics endpoints are reachable on the primary CNI port (default `9200` on
listeners, `9100` on proxy). External Prometheus scrape examples live in
[`operations.md`](operations.md).

## 4. Scale to 1 controller + 2 workers

1. Add the new hosts to `distributions/k0s/hosts.env`:
   ```bash
   export NODE1_HOST="…" NODE1_ADDR="…" NODE1_FABRIC_IFACE="…" NODE1_FABRIC_ADDR="…"
   export NODE2_HOST="…" NODE2_ADDR="…" NODE2_FABRIC_IFACE="…" NODE2_FABRIC_ADDR="…"
   ```
2. Uncomment the matching `- role: worker` blocks in
   `distributions/k0s/k0sctl.yaml`.
3. `make bootstrap` (idempotent).
4. `make label-nodes apps verify`.

The listener DaemonSet automatically lands a pod on each new node; per-node
retry-endpoint releases activate as those node labels appear.

## 5. Tear down

```bash
make teardown                 # apps -> platform -> cluster
```
