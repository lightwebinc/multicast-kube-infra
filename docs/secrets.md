# Secrets

See also [`platform/secrets/README.md`](../platform/secrets/README.md).

## In-Git policy

Nothing secret is committed. The `.gitignore` covers:

- `hosts.env` (operator SSH config)
- `k0sctl.yaml`, `k0s-config.yaml` (rendered from `*.example.*`)
- `apps/environments/production.yaml` (rendered from `production.yaml.example`)
- `.kube/` (kubeconfigs)
- `secrets/` (any operator-local secret material)

Templates are committed with `.example` suffix.

## Runtime secrets — External Secrets Operator

The platform layer installs ESO. A `ClusterSecretStore` named
`bsv-mcast-secret-store` is shipped as a stub (no provider). Pick one:

| Backend | When | Provider stanza |
|---|---|---|
| HashiCorp Vault | Self-hosted / on-prem | `provider.vault` |
| AWS Secrets Manager | EKS | `provider.aws` |
| GCP Secret Manager | GKE | `provider.gcpsm` |
| Azure Key Vault | AKS | `provider.azurekv` |

Edit `platform/secrets/cluster-secret-store.example.yaml`, uncomment the
matching block, copy to a non-`.example` filename, and `kubectl apply`.

Charts that need a secret reference an `ExternalSecret` whose `target.name`
matches the chart's `existingSecret` value. Example for the retry endpoint
Redis password:

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: retry-redis
  namespace: bsv-mcast
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: bsv-mcast-secret-store
    kind: ClusterSecretStore
  target:
    name: retry-redis-password
  data:
    - secretKey: password
      remoteRef:
        key: bsv-mcast/redis
        property: password
```

## Bootstrap secrets

Items needed *before* the cluster exists (k0s join tokens, registry pull
credentials, fabric IPv6 assignments) live in `hosts.env` and are loaded into
the operator shell. They are **not** in Git.

If the bootstrap secret list grows, factor it into a separate `secrets/`
directory (gitignored) and source from the Makefile.

## Recommendations for enterprise adoption

1. Rotate kubeconfigs on a schedule; never share long-lived admin tokens.
2. Use Vault or a managed secret store from day one — even if you start with a
   single static secret.
3. Add audit logging to the secret backend before going to production.
4. Once image publishing is gated behind environment approvals
   (already true for the chart repos), require ESO-sourced pull secrets here
   too. The same `ExternalSecret` pattern works.
