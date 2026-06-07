# multicast-kube-infra

> Part of the [**BSV Layered Multicast**](https://github.com/lightwebinc/bsv-multicast) open-source project — see the main repository for the full architecture, design docs, and BRC specifications.

Kubernetes deployment infrastructure for the Bitcoin multicast transaction-distribution stack
(`shard-proxy`, `shard-listener`, `retry-endpoint`, `subtx-generator`). The
BRC-137 announcer (`shard-manifest`) ships as its own chart and is deployed
alongside participants — see [`docs/architecture.md`](docs/architecture.md).

This repo is **distribution-agnostic**: the cluster bring-up lives under
`distributions/<dist>/`, while the platform addons (`platform/`) and the application
layer (`apps/`) consume only a `KUBECONFIG`. The first concrete distribution shipped
here is **k0s**; an `eks/` stub is in place for AWS EKS to come later.

## Quickstart (k0s reference)

```bash
# 1. Copy and edit examples — these files are .gitignored.
cp distributions/k0s/hosts.example.env       distributions/k0s/hosts.env
cp distributions/k0s/k0sctl.yaml.example     distributions/k0s/k0sctl.yaml
cp distributions/k0s/k0s-config.yaml.example distributions/k0s/k0s-config.yaml
cp apps/environments/production.yaml.example apps/environments/production.yaml

# 2. Bring everything up.
make all

# 3. Verify.
make verify
```

`make all` runs `preflight → bootstrap → platform → apps → verify`. All targets are
idempotent — re-running converges to desired state.

## Layout

| Path | Contents |
|---|---|
| `distributions/k0s/`     | k0sctl-driven cluster bootstrap. SSH host list. |
| `distributions/eks/`     | Stub for AWS EKS. |
| `platform/cni/`          | Calico (default), Cilium, kube-router options. |
| `platform/multus/`       | Multus CNI install. |
| `platform/nads/`          | `NetworkAttachmentDefinition` templates (`mcast-fabric`, `bgp-transit`, `bgp-ibgp`). |
| `platform/secrets/`      | External Secrets Operator + `ClusterSecretStore` stub. |
| `apps/`                   | Helmfile composing the data-plane bitcoin charts (proxy/listener/retry/subtx-gen). |
| `argocd/`                 | Stub for future ApplicationSet adoption. |
| `scripts/`                | Operator entry points (called from the Makefile). |
| `docs/`                   | Architecture, quickstart, networking, secrets, ops, troubleshooting. |

## Defaults

- **Distribution**: `DIST=k0s`
- **CNI**: `CNI=calico` (alternatives: `cilium`, `kube-router`)
- **Networking mode** (per app chart): `multus` with macvlan over the dedicated fabric NIC

Override on the command line:

```bash
make platform CNI=cilium
make apps     ENV=production
```

## Secrets posture

External Secrets Operator (ESO) is installed as a platform addon. A
`ClusterSecretStore` stub is shipped at `platform/secrets/cluster-secret-store.example.yaml`
with no provider wired — operators choose Vault, AWS Secrets Manager, GCP Secret Manager,
etc. See `docs/secrets.md` for guidance. Bootstrap secrets (k0s join tokens, registry
credentials) are kept out of Git via `*.example` templates and `.gitignore`.

## See also

- [`docs/architecture.md`](docs/architecture.md) — repo philosophy and contracts
- [`docs/quickstart-k0s.md`](docs/quickstart-k0s.md) — 10-minute walkthrough
- [`docs/networking.md`](docs/networking.md) — Multus, CNI choices, BGP-ready notes
- [`docs/operations.md`](docs/operations.md) — day-2 (upgrade, scale-out, drain)
- Upstream architecture: [`bsv-multicast/containerization/`](https://github.com/lightwebinc/bsv-multicast/tree/main/containerization)
