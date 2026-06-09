# ArgoCD path (stub)

This directory is a placeholder for a future GitOps-driven deployment using
ArgoCD. The current `apps/helmfile.yaml` flow remains the maintained path until
the four bitcoin charts are stable on OCI and operators are ready for pull-based
deployment.

## Adoption recipe (when this is wired up)

1. Install ArgoCD into its own namespace (separate Helmfile under `platform/`).
2. Apply `appset-platform.yaml` (CNI + Multus + ESO + NADs).
3. Apply `appset-apps.yaml` — an `ApplicationSet` that fans out per retry
   endpoint via the list generator, mirroring `apps/helmfile.yaml`.
4. Enable `automated.selfHeal: true` once values stabilize.

## Files

- `appset-platform.yaml.example` — placeholder.
- `appset-apps.yaml.example` — placeholder, modeled after the ApplicationSet
  composition pattern described in [`../docs/architecture.md`](../docs/architecture.md).
