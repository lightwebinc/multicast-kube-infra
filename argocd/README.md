# ArgoCD path (stub)

This directory is a placeholder for a future GitOps-driven deployment using
ArgoCD. The current `apps/helmfile.yaml.gotmpl` flow remains the maintained path
until the four bitcoin charts are stable on OCI and operators are ready for
pull-based deployment.

## Adoption recipe (when this is wired up)

1. Install ArgoCD into its own namespace (separate Helmfile under `platform/`).
2. Apply `appset-platform.yaml` (CNI + Multus + ESO + NADs).
3. Apply `appset-apps.yaml` — an `ApplicationSet` that fans out per retry
   endpoint via the list generator, mirroring `apps/helmfile.yaml.gotmpl`.
4. Enable `automated.selfHeal: true` once values stabilize.

## Files

- `appset-platform.yaml.example` — placeholder.
- `appset-apps.yaml.example` — placeholder, mirroring the per-node
  retry-endpoint fan-out that `apps/helmfile.yaml.gotmpl` renders (one release
  per node from the values list).
