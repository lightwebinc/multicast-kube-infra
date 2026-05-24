# Secrets

External Secrets Operator (ESO) is installed by the platform layer. A
non-functional `ClusterSecretStore` stub is provided for operators to fill in.

## Posture

| Item | Status |
|---|---|
| ESO installed | yes (chart `external-secrets/external-secrets`) |
| `ClusterSecretStore` provider configured | no — stub only |
| In-Git secret material | none |
| Bootstrap secrets in Git | none — `*.example.env`, `.gitignore` covers operator copies |
| SOPS / sealed-secrets | not used |

## Recommended providers

- **Self-hosted on-prem**: HashiCorp Vault. Uncomment the `vault:` block in
  `cluster-secret-store.example.yaml` and apply.
- **AWS EKS**: AWS Secrets Manager via IRSA.
- **GCP GKE**: GCP Secret Manager via Workload Identity.

## Bootstrap secret handling

Secrets that must exist *before* a cluster comes up (registry pull credentials,
external Prometheus bearer token, k0s join tokens) are kept out of Git via
`*.example.env` templates and the repository `.gitignore`. Operators source the
non-example variant locally before invoking `make`.

## Workload reference (forward-looking)

When a chart needs a secret (e.g. retry-endpoint Redis password), the
preferred pattern is:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: retry-redis
  namespace: bitcoin-mcast
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: bitcoin-mcast-secret-store
    kind: ClusterSecretStore
  target:
    name: retry-redis-password
  data:
    - secretKey: password
      remoteRef:
        key: bitcoin-mcast/redis
        property: password
```

The chart values reference `existingSecret: retry-redis-password`. No password
material lives in Git or in Helm values.
